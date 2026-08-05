class AppException implements Exception {
  const AppException(this.message, {this.code = 'APP_EXCEPTION'});

  final String message;
  final String code;

  @override
  String toString() => 'AppException($code): $message';
}
