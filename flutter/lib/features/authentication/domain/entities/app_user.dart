class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.phoneNumber,
    this.isEmergencyContact = false,
  });

  final String id;
  final String email;
  final String displayName;
  final String? phoneNumber;
  final bool isEmergencyContact;

  bool get hasValidProfile => id.isNotEmpty && email.isNotEmpty;
}
