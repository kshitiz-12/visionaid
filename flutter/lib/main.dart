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
  // Sync default so first build never hits LateInitializationError.
  ApiClient _api = ApiClient('http://10.192.17.6:8787');
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
    if (mounted) setState(() {});
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
              ? 'जुड़ गया। सुनो पर टैप करके कुछ भी पूछो — समय, जोक, क्रिकेट स्कोर।'
              : 'Connected${gemini ? '' : ' (Gemini off)'}. Tap Listen — ask time, jokes, cricket score, open Gmail…')
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

  String _forSpeech(String text) {
    return text
        .replaceAll('**', ' ')
        .replaceAll('*', ' ')
        .replaceAll(RegExp(r'[_`#]+'), ' ')
        .replaceAll(RegExp(r'\b(sender|subject|body summary)\s*:\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Android TTS often cuts long strings — speak sentence chunks and wait.
  List<String> _speechChunks(String text) {
    final parts = text
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return [text];
    final chunks = <String>[];
    final buf = StringBuffer();
    for (final p in parts) {
      if (buf.length + p.length > 160 && buf.isNotEmpty) {
        chunks.add(buf.toString().trim());
        buf.clear();
      }
      buf.write('$p ');
    }
    if (buf.isNotEmpty) chunks.add(buf.toString().trim());
    return chunks;
  }

  Future<void> _say(String text) async {
    if (!mounted) return;
    final clean = _forSpeech(text);
    if (clean.isEmpty) return;
    setState(() => _status = clean);
    await _tts.stop();
    await _tts.setSpeechRate(0.47);
    await _tts.setVolume(1.0);
    for (final chunk in _speechChunks(clean)) {
      final done = Completer<void>();
      _tts.setCompletionHandler(() {
        if (!done.isCompleted) done.complete();
      });
      final ok = await _tts.speak(chunk);
      if (ok != 1) {
        // Engine rejected speak — fall through delay so UX still moves.
        await Future<void>.delayed(Duration(milliseconds: 400 + chunk.length * 40));
        continue;
      }
      await done.future.timeout(
        Duration(seconds: 8 + (chunk.length ~/ 8).clamp(4, 40)),
        onTimeout: () {},
      );
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }

  bool _sttReady = false;
  String _partialHeard = '';

  Future<void> _listen() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _listening = true;
      _partialHeard = '';
      _status = _lang == 'hi' ? 'सुन रहा हूँ… साफ़ बोलो' : 'Listening… speak clearly';
    });
    await _tts.stop();
    // Let speaker settle so TTS echo does not steal the mic.
    await Future<void>.delayed(const Duration(milliseconds: 450));
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
      if (!_sttReady) {
        _sttReady = await _stt.initialize(
          onError: (e) => debugPrint('STT error: $e'),
          onStatus: (s) => debugPrint('STT status: $s'),
        );
      }
      if (!_sttReady) {
        await _say(
          _lang == 'hi'
              ? 'स्पीच उपलब्ध नहीं।'
              : 'Speech recognition is not available.',
        );
        return;
      }

      final completer = Completer<String>();
      _partialHeard = '';
      await _stt.listen(
        onResult: (r) {
          final words = r.recognizedWords.trim();
          if (words.isEmpty) return;
          _partialHeard = words;
          if (mounted) {
            setState(() => _status = 'Heard: $words');
          }
          if (r.finalResult && !completer.isCompleted) {
            completer.complete(words);
          }
        },
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: false,
          // Longer window + pause so "what is the last mail" is not cut off.
          listenFor: const Duration(seconds: 25),
          pauseFor: const Duration(seconds: 4),
          // en_IN hears Indian English phrases better than en_US for this app.
          localeId: _lang == 'hi' ? 'hi_IN' : 'en_IN',
        ),
      );
      final heard = await completer.future.timeout(
        const Duration(seconds: 28),
        onTimeout: () => _partialHeard,
      );
      await _stt.stop();
      final finalHeard = heard.trim().isNotEmpty ? heard.trim() : _partialHeard.trim();
      if (finalHeard.isEmpty) {
        await _say(
          _lang == 'hi'
              ? 'सुनाई नहीं दिया। फिर से Listen दबाओ और धीरे बोलो।'
              : "I didn't catch that. Tap Listen again and speak a bit slower.",
        );
        return;
      }
      setState(() => _status = 'Heard: $finalHeard');
      await _handle(finalHeard);
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
    // Don't speak "Working…" — it eats time and feels weak. Show status only.
    if (mounted) {
      setState(() => _status = _lang == 'hi' ? 'सोच रहा हूँ…' : 'On it…');
    }
    try {
      final result = await _api.command(heard);
      setState(() {
        _mirrorTick++;
        _pendingConfirm = result.pending != null;
      });
      await _say(result.spoken);
      // Keep listening like a phone assistant — confirm, follow-ups, next command.
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (mounted && !_busy) unawaited(_listen());
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
              Semantics(
                label: 'Main listen button. Double tap and speak.',
                button: true,
                child: FilledButton(
                  onPressed: _busy ? null : _listen,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(96),
                  ),
                  child: Text(
                    _listening
                        ? (_lang == 'hi' ? 'सुन रहा हूँ… बोलो' : 'Listening… speak now')
                        : (_lang == 'hi'
                            ? 'सुनो — कुछ भी पूछो'
                            : 'Listen — ask me anything'),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => _quick('confirm'),
                      child: Text(_lang == 'hi' ? 'कन्फर्म' : 'Confirm'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => _quick('cancel'),
                      child: Text(_lang == 'hi' ? 'कैंसल' : 'Cancel'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : _uploadPdf,
                      child: const Text('PDF'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: _busy ? null : _emergency,
                      child: const Text('SOS'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
