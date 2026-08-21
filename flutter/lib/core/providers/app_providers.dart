import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';

/// App providers. No authentication — VisionAid is login-free.
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});
