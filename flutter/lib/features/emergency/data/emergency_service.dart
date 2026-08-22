import '../../../core/services/user_prefs.dart';
import '../../communication/data/contact_directory.dart';
import '../../communication/data/voice_comm_service.dart';
import '../../communication/domain/contact_matcher.dart';

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
    return _comm.call(lookup.matches.first);
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
