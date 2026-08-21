import 'package:shared_preferences/shared_preferences.dart';

class UserPrefs {
  UserPrefs._();

  static const _languageKey = 'app_language';
  static const _nameKey = 'user_name';
  static const _emergencyKey = 'emergency_contact';
  static const _voiceSpeedKey = 'voice_speed';
  static const _setupDoneKey = 'setup_complete';

  static Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  static Future<bool> isSetupComplete() async {
    final prefs = await _prefs;
    return prefs.getBool(_setupDoneKey) ?? false;
  }

  static Future<void> setSetupComplete(bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(_setupDoneKey, value);
  }

  static Future<String> getLanguageCode() async {
    final prefs = await _prefs;
    return prefs.getString(_languageKey) ?? 'en';
  }

  static Future<void> setLanguageCode(String code) async {
    final prefs = await _prefs;
    await prefs.setString(_languageKey, code);
  }

  static Future<String> getName() async {
    final prefs = await _prefs;
    return prefs.getString(_nameKey) ?? '';
  }

  static Future<void> setName(String name) async {
    final prefs = await _prefs;
    await prefs.setString(_nameKey, name.trim());
  }

  static Future<String> getEmergencyContact() async {
    final prefs = await _prefs;
    return prefs.getString(_emergencyKey) ?? '';
  }

  static Future<void> setEmergencyContact(String phone) async {
    final prefs = await _prefs;
    await prefs.setString(_emergencyKey, phone.trim());
  }

  static Future<double> getVoiceSpeed() async {
    final prefs = await _prefs;
    return prefs.getDouble(_voiceSpeedKey) ?? 0.45;
  }

  static Future<void> setVoiceSpeed(double speed) async {
    final prefs = await _prefs;
    await prefs.setDouble(_voiceSpeedKey, speed);
  }
}

class AppLanguage {
  const AppLanguage({
    required this.code,
    required this.label,
    required this.ttsLocale,
  });

  final String code;
  final String label;
  final String ttsLocale;

  static const english = AppLanguage(
    code: 'en',
    label: 'English',
    ttsLocale: 'en-US',
  );

  static const hindi = AppLanguage(
    code: 'hi',
    label: 'Hindi',
    ttsLocale: 'hi-IN',
  );

  static const supported = <AppLanguage>[english, hindi];

  static AppLanguage fromCode(String code) {
    return supported.firstWhere(
      (lang) => lang.code == code,
      orElse: () => english,
    );
  }
}
