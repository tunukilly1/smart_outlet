import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
    static final ApiService _instance = ApiService._internal();
    factory ApiService() => _instance;
    ApiService._internal() {
        _setupInterceptors();
    }

    static const String baseUrl =
        'https://smart-outlet-backend.onrender.com';

    final FlutterSecureStorage _storage = const FlutterSecureStorage();
    final Dio _dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
        headers: {'Content-Type': 'application/json'},
    ));

    // ── AUTO REFRESH INTERCEPTOR ──────────────────────────
    void _setupInterceptors() {
        _dio.interceptors.add(InterceptorsWrapper(
            onError: (error, handler) async {
                if (error.response?.statusCode == 401) {
                    final refreshed = await _refreshToken();
                    if (refreshed) {
                        final token = await getAccessToken();
                        error.requestOptions.headers['Authorization'] =
                        'Bearer $token';
                        final response = await _dio.fetch(error.requestOptions);
                        return handler.resolve(response);
                    }
                }
                return handler.next(error);
            },
        ));
    }

    // ── TOKEN MANAGEMENT ──────────────────────────────────
    Future<void> saveTokens(String access, String refresh) async {
        await _storage.write(key: 'access_token', value: access);
        await _storage.write(key: 'refresh_token', value: refresh);
    }

    Future<void> saveUsername(String username) async {
        await _storage.write(key: 'saved_username', value: username);
    }

    Future<String?> getSavedUsername() async {
        return await _storage.read(key: 'saved_username');
    }

    Future<String?> getAccessToken() async {
        return await _storage.read(key: 'access_token');
    }

    Future<String?> getRefreshToken() async {
        return await _storage.read(key: 'refresh_token');
    }

    Future<void> clearTokens() async {
        await _storage.deleteAll();
    }

    Future<bool> isLoggedIn() async {
        final token = await getAccessToken();
        return token != null && token.isNotEmpty;
    }

    Future<bool> _refreshToken() async {
        try {
            final refresh = await getRefreshToken();
            if (refresh == null || refresh.isEmpty) {
                await clearTokens();
                return false;
            }
            // Use fresh Dio to avoid interceptor loop
            final dio = Dio(BaseOptions(baseUrl: baseUrl));
            final response = await dio.post('/api/token/refresh/',
                data: {'refresh': refresh});
            if (response.data['access'] != null) {
                await _storage.write(
                    key: 'access_token', value: response.data['access']);
                return true;
            }
            return false;
        } catch (_) {
            await clearTokens();
            return false;
        }
    }

    Future<Options> _authOptions() async {
        final token = await getAccessToken();
        debugPrint('Token exists: ${token != null && token.isNotEmpty}');
        return Options(headers: {'Authorization': 'Bearer $token'});
    }

    // ── AUTH ENDPOINTS ────────────────────────────────────

    // POST /api/auth/register/
    // Now requires first_name and last_name
    Future<Map<String, dynamic>> register({
        required String username,
        required String firstName,
        required String lastName,
        required String email,
        required String password,
        required String phone,
    }) async {
        final response = await _dio.post('/api/auth/register/', data: {
            'username': username,
            'first_name': firstName,
            'last_name': lastName,
            'email': email,
            'password': password,
            'phone': phone,
        });
        return response.data;
    }

    // POST /api/auth/login/
    Future<Map<String, dynamic>> login({
        required String username,
        required String password,
    }) async {
        final response = await _dio.post('/api/auth/login/', data: {
            'username': username,
            'password': password,
        });
        return response.data;
    }
    //----FETCH USER PROFILE----------------------
    Future<Map<String, dynamic>> getUserProfile() async {
        final response = await _dio.get('/api/users/profile/',
            options: await _authOptions());
        return response.data;
    }
    //---------UPDATE PROFILE-------------------------------
    Future<Map<String, dynamic>> updateUserProfile({
        required String username,
        required String email,
        required String phone,
        required String location,
    }) async {
        final response = await _dio.patch('/api/users/profile/', data: {
            'username': username,
            'email': email,
            'phone': phone,
            'location': location,
        }, options: await _authOptions());
        return response.data;
    }

    // ── DEVICE ENDPOINTS ──────────────────────────────────

    // GET /api/devices/
    // IMPORTANT: Response format changed — now returns {total_devices, devices:[]}
    Future<List<dynamic>> getDevices() async {
        final response = await _dio.get('/api/devices/',
            options: await _authOptions());

        // Handle NEW response format
        if (response.data is Map && response.data['devices'] != null) {
            return response.data['devices'] as List<dynamic>;
        }
        // Fallback for old format (plain list)
        if (response.data is List) {
            return response.data as List<dynamic>;
        }
        return [];
    }

    // POST /api/devices/
    Future<Map<String, dynamic>> registerDevice({
        required String deviceName,
        required String location,
        String firmwareVersion = '1.0',
    }) async {
        final response = await _dio.post('/api/devices/', data: {
            'device_name': deviceName,
             'location': location,
            'firmware_version': firmwareVersion,
        }, options: await _authOptions());
        debugPrint('REGISTER RESPONSE: ${response.data}');
        return response.data;
    }
    //CLAIM regeneration
    Future<Map<String, dynamic>> regenerateClaimCode(int deviceId) async {
        final response = await _dio.post(
            '/api/devices/$deviceId/regenerate-claim/',
            options: await _authOptions(),
        );
        return response.data as Map<String, dynamic>;
    }

    // POST /api/devices/{id}/control/
    Future<Map<String, dynamic>> controlDevice({
        required int deviceId,
        required bool turnOn,
    }) async {
        final response = await _dio.post(
            '/api/devices/$deviceId/control/',
            data: {'action': turnOn ? 'ON' : 'OFF'},
            options: await _authOptions(),
        );
        return response.data;
    }
    // --------DELETE /api/device/{id}/------------
    Future<void> deleteDevice(int deviceId) async {
        await _dio.delete('/api/devices/$deviceId/',
            options: await _authOptions());
    }
    //--------------RENAME DEVICE----------------------------
    Future<dynamic> renameDevice({
        required int deviceId,
        required String newName,
    }) async {
        final response = await _dio.patch(
            '/api/devices/$deviceId/',
            data: {'device_name': newName},
            options: await _authOptions(),
        );
        return response.data;
    }

    // ── ENERGY ENDPOINTS ──────────────────────────────────

    // GET /api/energy/{id}/
    Future<List<dynamic>> getEnergyHistory(int deviceId) async {
        final response = await _dio.get('/api/energy/$deviceId/',
            options: await _authOptions());
        if (response.data is List) return response.data;
        return [];
    }

    // GET /api/energy/history/ — NEW: All devices energy history
    Future<Map<String, dynamic>> getAllEnergyHistory() async {
        final response = await _dio.get('/api/energy/history/',
            options: await _authOptions());
        return response.data;
    }

    // ── ALERTS ENDPOINT ───────────────────────────────────

    // GET /api/alerts/
    Future<List<dynamic>> getAlerts() async {
        final response = await _dio.get('/api/alerts/',
            options: await _authOptions());
        if (response.data is List) return response.data;
        return [];
    }

    // ── SCHEDULE ENDPOINTS ────────────────────────────────
    Future<void> saveSchedule({
        required int deviceId,
        String? startTime,
        String? endTime,
        String repeatPattern = 'daily',
    }) async {
        await _dio.post(
            '/api/schedules/',
            data: {
                'device': deviceId,
                if (startTime != null) 'start_time': startTime,
                if (endTime != null) 'end_time': endTime,
                'repeat_pattern': repeatPattern,
                'status': 'active',
            },
            options: await _authOptions(),
        );
    }

    // GET /api/schedules/
    Future<List<dynamic>> getSchedules() async {
        final response = await _dio.get('/api/schedules/',
            options: await _authOptions());
        if (response.data is List) return response.data;
        return [];
    }

    // POST /api/schedules/
    Future<Map<String, dynamic>> createSchedule({
        required int deviceId,
        required String startTime,
        String? endTime,
        String repeatPattern = 'daily',
    }) async {
        final data = {
            'device': deviceId,
            'start_time': startTime,
            'repeat_pattern': repeatPattern,
            'status': 'active',
        };
        if (endTime != null) data['end_time'] = endTime;

        final response = await _dio.post('/api/schedules/',
            data: data, options: await _authOptions());
        return response.data;
    }

    // DELETE /api/schedules/{id}/
    Future<void> deleteSchedule(int scheduleId) async {
        await _dio.delete('/api/schedules/$scheduleId/',
            options: await _authOptions());
    }

    // ── CONTROL LOGS — NEW ────────────────────────────────

    // GET /api/control-logs/
    Future<Map<String, dynamic>> getControlLogs() async {
        final response = await _dio.get('/api/control-logs/',
            options: await _authOptions());
        return response.data;
    }
}
