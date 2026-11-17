import 'package:flutter/material.dart';

import '../services/prefs.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _api = TextEditingController();
  final _phone = TextEditingController();
  final _name = TextEditingController();
  String _lang = 'en';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _api.text = await UserPrefs.getApiBaseUrl();
    _phone.text = await UserPrefs.getEmergencyPhone();
    _name.text = await UserPrefs.getEmergencyName();
    _lang = await UserPrefs.getLanguageCode();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    await UserPrefs.setApiBaseUrl(_api.text);
    await UserPrefs.setEmergencyPhone(_phone.text);
    await UserPrefs.setEmergencyName(_name.text);
    await UserPrefs.setLanguageCode(_lang);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved')),
    );
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _api.dispose();
    _phone.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _api,
            decoration: const InputDecoration(
              labelText: 'Backend API URL',
              helperText: 'Emulator: http://10.0.2.2:8787  Phone: http://PC_LAN_IP:8787',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Emergency contact name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phone,
            decoration: const InputDecoration(
              labelText: 'Emergency phone number',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          const Text('Voice language'),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'en', label: Text('English')),
              ButtonSegment(value: 'hi', label: Text('Hindi')),
            ],
            selected: {_lang},
            onSelectionChanged: (s) => setState(() => _lang = s.first),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
    );
  }
}
