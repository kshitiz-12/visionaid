import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/contact_matcher.dart';
import 'contact_directory.dart';

class VoiceCommService {
  VoiceCommService({ContactDirectory? directory})
      : _directory = directory ?? ContactDirectory();

  final ContactDirectory _directory;

  Future<ContactLookup> find(String name) => _directory.lookup(name);

  /// Returns true if the dialer/native call UI started.
  Future<bool> tryCall(PhoneContact contact) async {
    try {
      final phoneStatus = await Permission.phone.request();
      if (phoneStatus.isGranted) {
        final started = await FlutterPhoneDirectCaller.callNumber(contact.phone);
        if (started == true) {
          return true;
        }
      }
      final tel = Uri(scheme: 'tel', path: contact.phone);
      return launchUrl(tel, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  Future<String> call(PhoneContact contact) async {
    final started = await tryCall(contact);
    if (started) {
      return 'Calling ${contact.displayName} now.';
    }
    return 'I could not start the call to ${contact.displayName}.';
  }

  Future<String> sendSms(PhoneContact contact, String message) async {
    if (message.trim().isEmpty) {
      return 'The message is empty. Please say it again.';
    }
    final encoded = Uri.encodeComponent(message.trim());
    final uri = Uri.parse('sms:${contact.phone}?body=$encoded');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      return 'I could not open SMS for ${contact.displayName}.';
    }
    return 'Opening SMS to ${contact.displayName}. Review and send if needed.';
  }

  Future<String> sendWhatsApp(PhoneContact contact, String message) async {
    if (message.trim().isEmpty) {
      return 'The message is empty. Please say it again.';
    }
    final phone = _whatsAppDigits(contact.phone);
    final text = Uri.encodeComponent(message.trim());
    final uris = [
      Uri.parse('whatsapp://send?phone=$phone&text=$text'),
      Uri.parse('https://api.whatsapp.com/send?phone=$phone&text=$text'),
      Uri.parse('https://wa.me/$phone?text=$text'),
    ];

    for (final uri in uris) {
      try {
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (ok) {
          return 'Opening WhatsApp for ${contact.displayName}. Tap send in WhatsApp if it is not sent automatically.';
        }
      } catch (_) {
        continue;
      }
    }
    return 'I could not open WhatsApp for ${contact.displayName}. Check that WhatsApp is installed.';
  }

  String _whatsAppDigits(String phone) {
    var digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length == 10) {
      digits = '91$digits';
    }
    return digits;
  }
}
