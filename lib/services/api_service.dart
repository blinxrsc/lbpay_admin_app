import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/models.dart';
import 'app_config.dart';

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
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
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

  Future<void> login(String email, String password, {String deviceName = 'lb-admin-app'}) async {
    try {
      final response = await _dio.post('/technician/login', data: {
        'email': email,
        'password': password,
        'device_name': deviceName,
      });
      await _storage.write(key: _tokenKey, value: response.data['token'] as String);
    } on DioException catch (e) {
      throw _rethrow(e);
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post('/technician/logout');
    } on DioException {
      // fall through — clear the local token regardless
    } finally {
      await _storage.delete(key: _tokenKey);
    }
  }

  Future<Map<String, dynamic>> dashboard() async {
    try {
      final r = await _dio.get('/technician/dashboard');
      return r.data;
    } on DioException catch (e) {
      throw _rethrow(e);
    }
  }

  Future<Map<String, dynamic>> profile() async {
    try {
      final r = await _dio.get('/technician/profile');
      return r.data;
    } on DioException catch (e) {
      throw _rethrow(e);
    }
  }

  Future<List<OutletSummary>> outlets() async {
    try {
      final r = await _dio.get('/technician/outlets');
      return (r.data['outlets'] as List).map((e) => OutletSummary.fromJson(e)).toList();
    } on DioException catch (e) {
      throw _rethrow(e);
    }
  }

  Future<List<OutletDeviceSummary>> outletDevices(int outletId) async {
    try {
      final r = await _dio.get('/technician/outlets/$outletId/devices');
      return (r.data['devices'] as List).map((e) => OutletDeviceSummary.fromJson(e)).toList();
    } on DioException catch (e) {
      throw _rethrow(e);
    }
  }

  Future<DeviceDetail> fetchDevice(String serial) async {
    try {
      final r = await _dio.get('/technician/devices/$serial');
      return DeviceDetail.fromJson(r.data);
    } on DioException catch (e) {
      throw _rethrow(e);
    }
  }

  Future<DeviceParameters> updateParameters(String serial, DeviceParameters params) async {
    try {
      final r = await _dio.put('/technician/devices/$serial/parameters', data: params.toJson());
      return DeviceParameters.fromJson(r.data['parameters']);
    } on DioException catch (e) {
      throw _rethrow(e);
    }
  }

  Future<void> sendConfig(String serial) async {
    try {
      await _dio.post('/technician/devices/$serial/send-config');
    } on DioException catch (e) {
      throw _rethrow(e);
    }
  }

  /// Returns (pulses, opId) — opId is polled via [startAckStatus].
  Future<(int, String)> startMachine(String serial, {required String type, required double price}) async {
    try {
      final r = await _dio.post('/technician/devices/$serial/start', data: {'type': type, 'price': price});
      return (r.data['pulses'] as int, r.data['op_id'] as String);
    } on DioException catch (e) {
      throw _rethrow(e);
    }
  }

  Future<String> startAckStatus(String opId) async {
    try {
      final r = await _dio.get('/technician/start-ack/$opId');
      return r.data['status'] as String;
    } on DioException catch (e) {
      throw _rethrow(e);
    }
  }

  ApiException _rethrow(DioException e) {
    if (e.error is ApiException) return e.error as ApiException;
    return ApiException(e.response?.statusCode, e.message ?? 'Unknown error');
  }
}
