import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/services/user_prefs.dart';
import '../../communication/data/contact_directory.dart';
import '../../communication/data/voice_comm_service.dart';
import '../../communication/domain/contact_matcher.dart';
import 'emergency_message.dart';

/// Emergency still uses the same contact + call stack as everyday voice comms.
class EmergencyService {
  EmergencyService({VoiceCommService? comm, ContactDirectory? directory})
      : _comm = comm ?? VoiceCommService(directory: directory);

  final VoiceCommService _comm;

  Future<String> placeCall({String contactName = ''}) async {
    final lookup = await _comm.find(contactName);
    if (lookup.permissionDenied) {
      return 'I need contacts permission to find people on this phone.';
    }
    if (lookup.matches.isEmpty) {
      if (contactName.isNotEmpty) {
        return 'I could not find $contactName in your contacts.';
      }
      return 'No emergency contact saved. Add one in settings.';
    }
    final contact = lookup.matches.first;
    final started = await _comm.tryCall(contact);
    if (started) {
      return 'Calling ${contact.displayName} now.';
    }
    return _smsWithLocation(contact);
  }

  Future<String> _smsWithLocation(PhoneContact contact) async {
    final userName = await UserPrefs.getName();
    final fix = await _lastFix();
    final body = EmergencyMessage.body(
      userName: userName,
      latitude: fix.$1,
      longitude: fix.$2,
    );
    await Permission.sms.request();
    final opened = await _comm.sendSms(contact, body);
    if (opened.toLowerCase().contains('could not')) {
      return 'Call failed and I could not send SMS. $opened';
    }
    return 'Call did not start. $opened';
  }

  Future<(double?, double?)> _lastFix() async {
    final status = await Permission.locationWhenInUse.request();
    if (!status.isGranted) {
      return (null, null);
    }
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        return (last.latitude, last.longitude);
      }
      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 4),
        ),
      );
      return (current.latitude, current.longitude);
    } catch (_) {
      return (null, null);
    }
  }

  Future<String> sendSms({
    required String contactName,
    required String message,
  }) async {
    final lookup = await _comm.find(contactName);
    if (lookup.permissionDenied) {
      return 'I need contacts permission to send a message.';
    }
    if (lookup.matches.isEmpty) {
      return 'I could not find $contactName in your phone contacts.';
    }
    return _comm.sendSms(lookup.matches.first, message);
  }

  Future<String> sendWhatsApp({
    required String contactName,
    required String message,
  }) async {
    final lookup = await _comm.find(contactName);
    if (lookup.permissionDenied) {
      return 'I need contacts permission to open WhatsApp.';
    }
    if (lookup.matches.isEmpty) {
      return 'I could not find $contactName in your phone contacts.';
    }
    return _comm.sendWhatsApp(lookup.matches.first, message);
  }

  Future<String> sendMessage({
    String contactName = '',
    String message = 'I need help. Sent from VisionAid.',
  }) =>
      sendSms(contactName: contactName, message: message);

  Future<String> textEmergencyContact({
    String message = 'I need help. Sent from VisionAid.',
  }) async {
    final name = await UserPrefs.getEmergencyContactName();
    return sendSms(contactName: name, message: message);
  }

  Future<ContactLookup> lookup(String name) => _comm.find(name);

  Future<String> callContact(PhoneContact contact) => _comm.call(contact);

  Future<String> smsContact(PhoneContact contact, String message) =>
      _comm.sendSms(contact, message);

  Future<String> whatsappContact(PhoneContact contact, String message) =>
      _comm.sendWhatsApp(contact, message);
}
