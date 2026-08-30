import 'package:flutter_contacts/flutter_contacts.dart';

import '../../../core/services/user_prefs.dart';
import '../../../services/intent_service.dart';
import '../domain/contact_matcher.dart';

class ContactDirectory {
  Future<ContactLookup> lookup(String spokenName) async {
    final query = spokenName.trim();
    final emergency = await _emergencyContact();

    if (query.isEmpty) {
      return ContactLookup(matches: emergency == null ? [] : [emergency]);
    }

    final status = await FlutterContacts.permissions.request(PermissionType.read);
    if (status != PermissionStatus.granted && status != PermissionStatus.limited) {
      final emergencyHit = emergency != null &&
          ContactMatcher.score(emergency.displayName, query) >= 85;
      if (emergencyHit) {
        return ContactLookup(matches: [emergency]);
      }
      return const ContactLookup(matches: [], permissionDenied: true);
    }

    final all = await FlutterContacts.getAll(
      properties: {ContactProperty.phone, ContactProperty.name},
    );
    final mapped = <PhoneContact>[];
    for (final contact in all) {
      if (contact.phones.isEmpty) {
        continue;
      }
      final phone = _bestPhone(contact.phones);
      if (phone.isEmpty) {
        continue;
      }
      final display = (contact.displayName ?? '').trim();
      final searchNames = _searchNames(contact, display);
      mapped.add(
        PhoneContact(
          displayName: display.isEmpty ? phone : display,
          phone: phone,
          searchNames: searchNames,
        ),
      );
    }

    var matches = ContactMatcher.rank(mapped, query);
    if (emergency != null &&
        ContactMatcher.score(emergency.displayName, query) >= 85) {
      matches = [
        emergency,
        ...matches.where((m) => m.phone != emergency.phone),
      ];
    }
    return ContactLookup(matches: matches);
  }

  /// Compact catalog for Gemini contact resolution (display names + aliases only).
  Future<List<ContactRef>> loadPromptCatalog({int maxContacts = 150}) async {
    final status = await FlutterContacts.permissions.request(PermissionType.read);
    if (status != PermissionStatus.granted && status != PermissionStatus.limited) {
      return const [];
    }

    final all = await FlutterContacts.getAll(
      properties: {ContactProperty.phone, ContactProperty.name},
    );
    final out = <ContactRef>[];
    for (final contact in all) {
      if (contact.phones.isEmpty) {
        continue;
      }
      final phone = _bestPhone(contact.phones);
      if (phone.isEmpty) {
        continue;
      }
      final display = (contact.displayName ?? '').trim();
      if (display.isEmpty) {
        continue;
      }
      final searchNames = _searchNames(contact, display)
          .where((n) => n.trim().isNotEmpty && n.trim() != display)
          .toList();
      final last4 = phone.length >= 4 ? phone.substring(phone.length - 4) : phone;
      out.add(
        ContactRef(
          displayName: display,
          searchNames: searchNames,
          phoneLast4: last4,
        ),
      );
      if (out.length >= maxContacts) {
        break;
      }
    }
    return out;
  }

  List<String> _searchNames(Contact contact, String display) {
    final out = <String>{display};
    final name = contact.name;
    if (name == null) {
      return out.toList();
    }
    void add(String? value) {
      final t = (value ?? '').trim();
      if (t.isNotEmpty) {
        out.add(t);
      }
    }

    add(name.first);
    add(name.last);
    add(name.middle);
    add(name.nickname);
    add(name.prefix);
    add(name.suffix);
    final first = (name.first ?? '').trim();
    final last = (name.last ?? '').trim();
    if (first.isNotEmpty && last.isNotEmpty) {
      out.add('$first $last');
      out.add('$last $first');
    }
    return out.toList();
  }

  Future<PhoneContact?> _emergencyContact() async {
    final phone = await UserPrefs.getEmergencyContact();
    if (phone.isEmpty) {
      return null;
    }
    final name = await UserPrefs.getEmergencyContactName();
    return PhoneContact(
      displayName: name.isEmpty ? 'emergency contact' : name,
      phone: _digits(phone),
    );
  }

  String _bestPhone(List<Phone> phones) {
    Phone? primary;
    for (final p in phones) {
      if (p.isPrimary == true) {
        primary = p;
        break;
      }
    }
    final chosen = primary ?? phones.first;
    final raw = (chosen.normalizedNumber ?? chosen.number).trim();
    return _digits(raw);
  }

  String _digits(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^\d+]'), '');
    return cleaned.isEmpty ? raw.trim() : cleaned;
  }
}
