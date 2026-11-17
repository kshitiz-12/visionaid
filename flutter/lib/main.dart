import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:url_launcher/url_launcher.dart';

import 'pages/settings_page.dart';
import 'services/api_client.dart';
import 'services/prefs.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VoiceWebApp());
}

class VoiceWebApp extends StatelessWidget {
  const VoiceWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VoiceWeb Agent',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F3D2E),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late ApiClient _api;
  final _tts = FlutterTts();
  final _stt = SpeechToText();

  String _status = 'Starting VoiceWeb Agent…';
  bool _busy = false;
  bool _listening = false;
  bool _backendOk = false;
  bool _pendingConfirm = false;
  int _mirrorTick = 0;
  String _lang = 'en';

  @override
  void initState() {
    super.initState();
    unawaited(_boot());
  }

  Future<void> _boot() async {
    final base = await UserPrefs.getApiBaseUrl();
    _lang = await UserPrefs.getLanguageCode();
    _api = ApiClient(base);
    await _tts.setSpeechRate(0.47);
    await _tts.setVolume(1);
    await _tts.setLanguage(_lang == 'hi' ? 'hi-IN' : 'en-US');
    await _refreshBackend(speak: true);
  }

  Future<void> _refreshBackend({bool speak = false}) async {
    try {
      final h = await _api.health();
      _backendOk = h['ok'] == true;
      if (_backendOk) {
        unawaited(_api.startBrowser());
      }
      final warn = h['geminiWarning'] as String?;
      final gemini = h['geminiConfigured'] == true;
      final msg = _backendOk
          ? (_lang == 'hi'
              ? 'बैकएंड जुड़ा। सुनने के लिए टैप करें।'
              : 'Backend connected${gemini ? '' : ' (Gemini offline summaries)'}. Tap Listen.')
          : (_lang == 'hi'
              ? 'बैकएंड बंद है। सेटिंग में API URL चेक करें।'
              : 'Backend offline. Check API URL in Settings.');
      if (mounted) {
        setState(() {
          _status = warn != null && warn.isNotEmpty ? '$msg $warn' : msg;
        });
      }
      if (speak) await _say(_status);
    } catch (_) {
      _backendOk = false;
      final msg = _lang == 'hi'
          ? 'बैकएंड बंद है। पीसी पर npm run dev चलाएँ।'
          : 'Backend offline. On PC run: npm run dev in voiceweb-agent/backend.';
      if (mounted) setState(() => _status = msg);
      if (speak) await _say(msg);
    }
  }

  Future<void> _say(String text) async {
    if (!mounted) return;
    setState(() => _status = text);
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> _listen() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _listening = true;
      _status = _lang == 'hi' ? 'सुन रहा हूँ…' : 'Listening…';
    });
    await _tts.stop();
    try {
      final mic = await Permission.microphone.request();
      if (!mic.isGranted) {
        await _say(
          _lang == 'hi'
              ? 'माइक अनुमति चाहिए।'
              : 'Microphone permission is required.',
        );
        return;
      }
      final ready = await _stt.initialize();
      if (!ready) {
        await _say(
          _lang == 'hi'
              ? 'स्पीच उपलब्ध नहीं।'
              : 'Speech recognition is not available.',
        );
        return;
      }
      final completer = Completer<String>();
      await _stt.listen(
        onResult: (r) {
          if (r.finalResult && !completer.isCompleted) {
            completer.complete(r.recognizedWords.trim());
          }
        },
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: true,
          listenFor: const Duration(seconds: 14),
          pauseFor: const Duration(seconds: 2),
          localeId: _lang == 'hi' ? 'hi_IN' : 'en_US',
        ),
      );
      final heard = await completer.future.timeout(
        const Duration(seconds: 16),
        onTimeout: () => '',
      );
      await _stt.stop();
      if (heard.isEmpty) {
        await _say(
          _lang == 'hi'
              ? 'सुनाई नहीं दिया। फिर से टैप करें।'
              : "I didn't catch that. Tap Listen again.",
        );
        return;
      }
      setState(() => _status = 'Heard: $heard');
      await _handle(heard);
    } catch (e) {
      await _say('Listening failed. $e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _listening = false;
        });
      }
    }
  }

  Future<void> _handle(String heard) async {
    final lower = heard.toLowerCase();
    if (RegExp(
      r'\b(emergency|sos|call (mom|mummy|help)|इमरजेंसी|आपातकाल)\b',
    ).hasMatch(lower)) {
      await _emergency();
      return;
    }
    if (!_backendOk) {
      await _refreshBackend();
    }
    if (!_backendOk) {
      await _say(
        _lang == 'hi'
            ? 'बैकएंड ऑफलाइन है।'
            : 'Backend is offline. Open Settings and fix the API URL.',
      );
      return;
    }
    await _say(_lang == 'hi' ? 'काम हो रहा है…' : 'Working…');
    try {
      final result = await _api.command(heard);
      setState(() {
        _mirrorTick++;
        _pendingConfirm = result.pending != null;
      });
      await _say(result.spoken);
      if (result.pending != null) {
        // Hands-free confirm turn for blind demo.
        await Future<void>.delayed(const Duration(milliseconds: 600));
        if (mounted && !_busy) unawaited(_listen());
      }
    } catch (e) {
      await _say(
        _lang == 'hi'
            ? 'कमांड फेल। पीसी ब्राउज़र एजेंट चेक करें।'
            : 'Command failed. Check the PC browser agent. $e',
      );
    }
  }

  Future<void> _emergency() async {
    await HapticFeedback.heavyImpact();
    final phone = await UserPrefs.getEmergencyPhone();
    final name = await UserPrefs.getEmergencyName();
    if (phone.trim().isEmpty) {
      await _say(
        _lang == 'hi'
            ? 'इमरजेंसी नंबर सेटिंग में डालें।'
            : 'Set an emergency phone number in Settings first.',
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone.trim());
    await _say(
      _lang == 'hi' ? '$name को कॉल कर रहा हूँ।' : 'Calling $name.',
    );
    await launchUrl(uri);
  }

  Future<void> _uploadPdf() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final pick = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'txt'],
        withData: true,
      );
      if (pick == null || pick.files.isEmpty) {
        await _say(_lang == 'hi' ? 'रद्द।' : 'Cancelled.');
        return;
      }
      final f = pick.files.first;
      final bytes = f.bytes;
      if (bytes == null) {
        await _say('Could not read file bytes.');
        return;
      }
      await _say(_lang == 'hi' ? 'PDF पढ़ रहा हूँ…' : 'Reading PDF…');
      if (!_backendOk) await _refreshBackend();
      final result = await _api.summarizePdfBytes(
        bytes: bytes,
        filename: f.name,
      );
      await _say(result.spoken);
    } catch (e) {
      await _say('PDF failed. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _quick(String spoken) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _handle(spoken);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openSettings() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
    if (changed == true) {
      final base = await UserPrefs.getApiBaseUrl();
      _lang = await UserPrefs.getLanguageCode();
      _api = ApiClient(base);
      await _tts.setLanguage(_lang == 'hi' ? 'hi-IN' : 'en-US');
      await _refreshBackend(speak: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mirror = _api.screenshotUri(_mirrorTick);

    return Scaffold(
      appBar: AppBar(
        title: const Text('VoiceWeb Agent'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    _backendOk ? Icons.cloud_done : Icons.cloud_off,
                    color: _backendOk ? Colors.tealAccent : Colors.orangeAccent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _backendOk
                          ? (_pendingConfirm
                              ? 'Pending confirm — say confirm or cancel'
                              : 'Browser agent online')
                          : 'Browser agent offline',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                flex: 3,
                child: Semantics(
                  label: 'Browser mirror screenshot',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: ColoredBox(
                      color: const Color(0xFF102018),
                      child: _backendOk
                          ? Image.network(
                              mirror.toString(),
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text(
                                    'Mirror appears after the first browser command',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            )
                          : const Center(
                              child: Text('Start backend to see live browser mirror'),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  _status,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip('Help', () => _quick('help')),
                  _chip('Screen', () => _quick("what's on my screen")),
                  _chip('Gmail', () => _quick('open gmail')),
                  _chip('Mail digest', () => _quick('any new mail')),
                  _chip('WhatsApp', () => _quick('open whatsapp')),
                  _chip('Swiggy', () => _quick('order maggi on swiggy')),
                  _chip('Flipkart', () => _quick('get milk on flipkart')),
                  _chip('Confirm', () => _quick('confirm')),
                  _chip('Cancel', () => _quick('cancel')),
                  _chip('PDF', _uploadPdf),
                  _chip('SOS', _emergency),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy ? null : _listen,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(68),
                ),
                child: Text(
                  _listening
                      ? (_lang == 'hi' ? 'सुन रहा हूँ…' : 'Listening…')
                      : (_lang == 'hi' ? 'सुनो' : 'Listen'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label),
      onPressed: _busy ? null : onTap,
    );
  }
}
