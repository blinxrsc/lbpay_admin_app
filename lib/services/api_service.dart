import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/device.dart';
import 'app_config.dart';

/// Thrown for any non-2xx response, carrying the backend's message so the
/// UI can show something more useful than "DioException".
class ApiException implements Exception {
  final int? statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class ApiService {
  static const _tokenKey = 'sanctum_token';
  final _storage = const FlutterSecureStorage();
  late final Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Accept': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: _tokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        final data = error.response?.data;
        final message = (data is Map && data['message'] != null)
            ? data['message'].toString()
            : (error.message ?? 'Network error');
        handler.reject(DioException(
          requestOptions: error.requestOptions,
          error: ApiException(error.response?.statusCode, message),
          response: error.response,
          type: error.type,
        ));
      },
    ));
  }

  Future<bool> get isLoggedIn async => (await _storage.read(key: _tokenKey)) != null;

  Future<void> login(String email, String password, {String deviceName = 'technician-app'}) async {
    try {
      final response = await _dio.post('/technician/login', data: {
        'email': email,
        'password': password,
        'device_name': deviceName,
      });
      final token = response.data['token'] as String;
      await _storage.write(key: _tokenKey, value: token);
    } on DioException catch (e) {
      throw _rethrow(e);
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post('/technician/logout');
    } on DioException {
      // Even if the server call fails (e.g. already offline), still clear
      // the local token so the app doesn't get stuck "logged in".
    } finally {
      await _storage.delete(key: _tokenKey);
    }
  }

  Future<DeviceDetail> fetchDevice(String serial) async {
    try {
      final response = await _dio.get('/technician/devices/$serial');
      return DeviceDetail.fromJson(response.data);
    } on DioException catch (e) {
      throw _rethrow(e);
    }
  }

  Future<DeviceParameters> updateParameters(String serial, DeviceParameters params) async {
    try {
      final response = await _dio.put(
        '/technician/devices/$serial/parameters',
        data: params.toJson(),
      );
      return DeviceParameters.fromJson(response.data['parameters']);
    } on DioException catch (e) {
      throw _rethrow(e);
    }
  }

  /// Returns the number of pulses the backend actually queued, computed
  /// server-side from the device's own pulse_price — never trust a client
  /// pulse count for a financial action.
  Future<int> startMachine(String serial, {required String type, required double price}) async {
    try {
      final response = await _dio.post('/technician/devices/$serial/start', data: {
        'type': type,
        'price': price,
      });
      return response.data['pulses'] as int;
    } on DioException catch (e) {
      throw _rethrow(e);
    }
  }

  ApiException _rethrow(DioException e) {
    if (e.error is ApiException) return e.error as ApiException;
    return ApiException(e.response?.statusCode, e.message ?? 'Unknown error');
  }
}
