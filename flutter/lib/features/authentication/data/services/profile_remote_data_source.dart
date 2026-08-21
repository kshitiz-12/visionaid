import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/network/api_client.dart';

class ProfileRemoteDataSource {
  ProfileRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> fetchProfile() async {
    final response = await _apiClient.get('/api/profile');
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const AppException('Invalid profile response', code: 'PROFILE_INVALID');
    }
    return data;
  }

  Future<Map<String, dynamic>> updateProfile({
    String? fullName,
    String? email,
  }) async {
    final body = <String, dynamic>{};
    if (fullName != null) {
      body['full_name'] = fullName;
    }
    if (email != null) {
      body['email'] = email;
    }

    final response = await _apiClient.patch('/api/profile', body: body);
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const AppException('Invalid profile response', code: 'PROFILE_INVALID');
    }
    return data;
  }
}
