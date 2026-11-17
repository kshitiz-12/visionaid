import 'package:shared_preferences/shared_preferences.dart';

class UserPrefs {
  static const _api = 'api_base_url';
  static const _phone = 'emergency_phone';
  static const _name = 'emergency_name';
  static const _lang = 'language_code';

  static Future<String> getApiBaseUrl() async {
    final p = await SharedPreferences.getInstance();
    // Emulator default. For live Render, set in Settings once deployed.
    return p.getString(_api) ?? 'http://10.0.2.2:8787';
  }

  static Future<void> setApiBaseUrl(String v) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_api, v.trim());
  }

  static Future<String> getEmergencyPhone() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_phone) ?? '';
  }

  static Future<void> setEmergencyPhone(String v) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_phone, v.trim());
  }

  static Future<String> getEmergencyName() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_name) ?? 'Emergency';
  }

  static Future<void> setEmergencyName(String v) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_name, v.trim().isEmpty ? 'Emergency' : v.trim());
  }

  static Future<String> getLanguageCode() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_lang) ?? 'en';
  }

  static Future<void> setLanguageCode(String v) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_lang, v);
  }
}
