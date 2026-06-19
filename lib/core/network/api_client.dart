import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../constants/app_constants.dart';
import '../utils/print_log.dart';

part 'api_client.g.dart';

// ── Provider ─────────────────────────────────────────────────────────────────

@riverpod
ApiClient apiClient(Ref ref) {
  return ApiClient(
    onLogout: () {
      // Trigger logout on the auth notifier from wherever you hold the ref.
    },
  );
}

// ── Pending-request queue entry ───────────────────────────────────────────────

class _PendingRequest {
  final DioException error;
  final ErrorInterceptorHandler handler;
  _PendingRequest(this.error, this.handler);
}

// ── Main client ───────────────────────────────────────────────────────────────

/// A self-contained Dio wrapper that handles:
/// * Auth token injection & 401 refresh with a queued-request pattern.
/// * 429 rate-limit back-off with `Retry-After` support.
/// * HTML-response detection and auto-retry (up to 5 attempts).
/// * Connection-timeout, receive-timeout, and no-internet errors.
/// * Debug logging via [printLog] / [printError].
class ApiClient {
  late final Dio _dio;
  final Connectivity _connectivity = Connectivity();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// Called when the session has expired and the user must be re-authenticated.
  final VoidCallback? onLogout;

  bool _isRefreshing = false;
  final List<_PendingRequest> _pendingRequests = [];

  static const String _noInternetMsg = 'No Internet Connection';
  static const String _infoTitle = 'Info';

  ApiClient({this.onLogout, String customBaseUrl = ''}) {
    _dio = Dio(
      BaseOptions(
        baseUrl:
            customBaseUrl.isNotEmpty ? customBaseUrl : AppConstants.baseUrl,
        connectTimeout:
            const Duration(milliseconds: AppConstants.connectTimeout),
        receiveTimeout:
            const Duration(milliseconds: AppConstants.receiveTimeout),
        responseType: ResponseType.plain,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Trust all certificates in debug – never in release builds.
    if (!kIsWeb) {
      (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        final client = HttpClient();
        if (kDebugMode) {
          client.badCertificateCallback = (cert, host, port) => true;
        }
        return client;
      };
    }

    _dio.interceptors.add(_buildInterceptor());
  }

  // ── Interceptor ────────────────────────────────────────────────────────────

  QueuedInterceptorsWrapper _buildInterceptor() {
    return QueuedInterceptorsWrapper(
      onRequest: (options, handler) => handler.next(options),
      onResponse: (response, handler) => handler.next(response),
      onError: (err, handler) => _handleError(err, handler),
    );
  }

  Future<void> _handleError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    try {
      // ── Timeout errors ──────────────────────────────────────────────────
      if (err.type == DioExceptionType.connectionTimeout) {
        return _reject(
          'Connection timeout. Please check your internet and try again.',
          err,
          handler,
        );
      }
      if (err.type == DioExceptionType.receiveTimeout) {
        return _reject('Request timeout. Please try again.', err, handler);
      }

      // ── Network / connection errors ─────────────────────────────────────
      if (err.type == DioExceptionType.connectionError) {
        final connected = await _hasActiveConnection();
        if (!connected) {
          _showSnackBar(title: _infoTitle, message: _noInternetMsg);
        } else {
          printLog(
            'Connection error while internet appears active: \${err.message}',
            level: 'w',
          );
        }
        return handler.reject(err);
      }

      final statusCode = err.response?.statusCode;
      final response = err.response;

      if (statusCode == null || response == null) {
        return handler.reject(err);
      }

      // ── 429 Too Many Requests ───────────────────────────────────────────
      if (statusCode == 429) {
        return _handle429(err, handler, response);
      }

      // ── HTML response (misconfigured proxy / CDN error page) ────────────
      if (_isHtmlResponse(response)) {
        return _handleHtmlError(err, handler);
      }

      // ── Status-code routing ─────────────────────────────────────────────
      switch (statusCode) {
        case 204:
          return handler.resolve(response);

        case 400:
          _maybeSnackBar(_extractMessage(response));
          return handler.reject(err);

        case 401:
          return _handleUnauthorized(err, handler);

        case 403:
          _showSnackBar(
            title: _infoTitle,
            message: 'You are not authorized to perform this action.',
          );
          return handler.reject(err);

        case 500:
          return _reject(
            _extractMessage(response) ??
                'Server error (500). Please try again later.',
            err,
            handler,
          );

        case 502:
        case 503:
        case 504:
          return _reject(
            _extractMessage(response) ??
                'Server temporarily unavailable. Please try again.',
            err,
            handler,
          );

        default:
          _maybeSnackBar(_extractMessage(response));
          return handler.resolve(response);
      }
    } catch (e, s) {
      printError('Unexpected error in _handleError', error: e, stackTrace: s);
      return handler.reject(err);
    }
  }

  // ── 429 handler ────────────────────────────────────────────────────────────

  Future<void> _handle429(
    DioException err,
    ErrorInterceptorHandler handler,
    Response<dynamic> response,
  ) async {
    const maxRetries = 8;
    final retryCount =
        err.requestOptions.extra['retry_count_429'] as int? ?? 0;

    if (retryCount >= maxRetries) {
      return _reject(
        'Too many requests. Please try again later.',
        err,
        handler,
      );
    }

    int delaySeconds = 2 * (retryCount + 1);
    final retryAfter = response.headers.value('retry-after');
    if (retryAfter != null) {
      final parsed = int.tryParse(retryAfter);
      if (parsed != null && parsed > 0) delaySeconds = parsed;
    }

    printLog(
      '429 – retrying in \${delaySeconds}s (attempt \${retryCount + 1}/\$maxRetries)',
      level: 'w',
    );

    err.requestOptions.extra['retry_count_429'] = retryCount + 1;
    await Future.delayed(Duration(seconds: delaySeconds));

    try {
      return handler.resolve(await _dio.fetch(err.requestOptions));
    } catch (e) {
      printLog('429 retry failed: \$e', level: 'e');
      return handler.reject(err);
    }
  }

  // ── HTML response handler ──────────────────────────────────────────────────

  Future<void> _handleHtmlError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    const maxRetries = 5;
    final retryCount =
        err.requestOptions.extra['retry_count_html'] as int? ?? 0;

    if (retryCount >= maxRetries) {
      return _reject('Server error. Please try again later.', err, handler);
    }

    final attempt = retryCount + 1;
    printLog('HTML response – retrying (\$attempt/\$maxRetries)', level: 'w');
    err.requestOptions.extra['retry_count_html'] = attempt;
    await Future.delayed(Duration(milliseconds: 500 * attempt));

    try {
      return handler.resolve(await _dio.fetch(err.requestOptions));
    } catch (e) {
      printLog('HTML retry failed: \$e', level: 'e');
      return handler.reject(err);
    }
  }

  // ── 401 / token refresh handler ────────────────────────────────────────────

  Future<void> _handleUnauthorized(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final isAuthRequired =
        err.requestOptions.extra['is_header_required'] == true;

    if (!isAuthRequired) {
      printLog('401 on unauthenticated request – skipping refresh');
      return handler.reject(err);
    }

    final refreshAttempts =
        err.requestOptions.extra['refresh_attempts'] as int? ?? 0;

    if (refreshAttempts > 0) {
      printLog('Already attempted refresh for this request – logging out');
      await _doLogout('Your session has expired. Please login again.');
      return handler.reject(err);
    }

    err.requestOptions.extra['refresh_attempts'] = refreshAttempts + 1;

    if (_isRefreshing) {
      printLog('Refresh in progress – queueing request');
      _pendingRequests.add(_PendingRequest(err, handler));
      return;
    }

    _isRefreshing = true;

    try {
      final refreshed = await _refreshAccessToken();

      if (refreshed) {
        printLog(
          'Token refreshed – retrying \${_pendingRequests.length + 1} request(s)',
        );

        try {
          handler.resolve(await _dio.fetch(err.requestOptions));
        } catch (e) {
          printLog('Original request retry failed: \$e', level: 'e');
          handler.reject(err);
        }

        for (final pending in _pendingRequests) {
          try {
            pending.handler.resolve(
              await _dio.fetch(pending.error.requestOptions),
            );
          } catch (e) {
            printLog('Pending request retry failed: \$e', level: 'e');
            pending.handler.reject(pending.error);
          }
        }
      } else {
        printLog('Token refresh failed – rejecting all queued requests');
        handler.reject(err);
        for (final pending in _pendingRequests) {
          pending.handler.reject(pending.error);
        }
      }
    } finally {
      _pendingRequests.clear();
      _isRefreshing = false;
    }
  }

  Future<bool> _refreshAccessToken() async {
    try {
      final token = await _storage.read(key: AppConstants.tokenKey);

      if (token == null || token.trim().isEmpty) {
        printLog('No stored token – cannot refresh');
        await _doLogout('Your session has expired. Please login again.');
        return false;
      }

      final bearer = token.startsWith('Bearer ') ? token : 'Bearer \$token';

      printLog('Attempting token refresh…');
      final res = await _dio.post(
        'auth/refresh', // TODO: update with your refresh endpoint
        options: Options(
          headers: {
            'Authorization': bearer,
            'Content-Type': 'application/json',
          },
          validateStatus: (s) => s != null && s < 500,
        ),
      );

      printLog('Refresh status: \${res.statusCode}');

      if (res.statusCode == 200 || res.statusCode == 201) {
        final decoded = jsonDecode(res.data.toString());

        if (decoded is Map<String, dynamic> &&
            decoded['access_token'] != null) {
          final newToken = decoded['access_token'].toString();
          final withBearer =
              newToken.startsWith('Bearer ') ? newToken : 'Bearer \$newToken';

          await _storage.write(
            key: AppConstants.tokenKey,
            value: withBearer,
          );
          _dio.options.headers['Authorization'] = withBearer;

          printLog('Token refreshed successfully');
          return true;
        }

        printLog('Refresh response missing access_token field', level: 'w');
      } else if (res.statusCode == 401) {
        printLog('Refresh token also invalid (401)', level: 'w');
      }
    } on DioException catch (e) {
      printError('DioException during token refresh', error: e);
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return false; // network issue – don't logout
      }
    } catch (e, s) {
      printError(
        'Unexpected error during token refresh',
        error: e,
        stackTrace: s,
      );
    }

    await _doLogout('Your session has expired. Please login again.');
    return false;
  }

  // ── Header configuration ───────────────────────────────────────────────────

  Future<void> _attachAuthHeader() async {
    final token = await _storage.read(key: AppConstants.tokenKey);
    if (token != null && token.isNotEmpty) {
      final bearer = token.startsWith('Bearer ') ? token : 'Bearer \$token';
      _dio.options.headers['Authorization'] = bearer;
    }
  }

  void _applyCustomHeaders(Map<String, dynamic>? headers) {
    headers?.forEach((key, value) => _dio.options.headers[key] = value);
  }

  // ── Public HTTP methods ────────────────────────────────────────────────────

  /// GET request. Returns the raw [Response], or `null` on unrecoverable error.
  Future<Response?> get(
    String url, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    bool requiresAuth = false,
  }) async {
    try {
      if (requiresAuth) await _attachAuthHeader();
      _applyCustomHeaders(headers);

      final response = await _dio.get(
        url,
        queryParameters: queryParameters,
        options: Options(
          extra: {
            'is_header_required': requiresAuth,
            'retry_count_html': 0,
          },
        ),
      );

      if (kDebugMode) {
        printLog('GET \$url ← \${response.statusCode}');
      }

      return response;
    } on DioException catch (e) {
      printError('GET \$url', error: e);
      return e.response;
    } catch (e, s) {
      printError('GET \$url – unexpected', error: e, stackTrace: s);
      return null;
    }
  }

  /// POST request. Returns the raw [Response], or `null` on unrecoverable error.
  Future<Response?> post(
    String url, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    bool requiresAuth = false,
    bool isFormData = false,
    bool isMultipart = false,
    bool isMultipleFiles = false,
  }) async {
    try {
      if (requiresAuth) await _attachAuthHeader();

      if (requiresAuth) {
        _dio.options.headers['Content-Type'] =
            isMultipart ? 'multipart/form-data' : 'application/json';
      }

      _applyCustomHeaders(headers);

      final payload = await _buildPayload(
        data: data,
        isFormData: isFormData,
        isMultipleFiles: isMultipleFiles,
      );

      if (kDebugMode) printLog('POST \$url\ndata: \$data');

      final response = await _dio.post(
        url,
        data: payload,
        queryParameters: queryParameters,
        options: Options(
          extra: {
            'is_header_required': requiresAuth,
            'retry_count_html': 0,
          },
        ),
      );

      if (kDebugMode) printLog('POST \$url ← \${response.statusCode}');

      return response;
    } on DioException catch (e) {
      printError('POST \$url', error: e);
      if (const {400, 401, 403}.contains(e.response?.statusCode)) {
        return e.response;
      }
      return null;
    } catch (e, s) {
      printError('POST \$url – unexpected', error: e, stackTrace: s);
      return null;
    }
  }

  /// PUT request. Returns the raw [Response], or `null` on unrecoverable error.
  Future<Response?> put(
    String url, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    bool requiresAuth = true,
  }) async {
    try {
      if (requiresAuth) await _attachAuthHeader();
      _dio.options.headers['Content-Type'] = 'application/json';
      _applyCustomHeaders(headers);

      final response = await _dio.put(
        url,
        data: data,
        queryParameters: queryParameters,
        options: Options(
          extra: {
            'is_header_required': requiresAuth,
            'retry_count_html': 0,
          },
        ),
      );

      if (kDebugMode) printLog('PUT \$url ← \${response.statusCode}');
      return response;
    } on DioException catch (e) {
      printError('PUT \$url', error: e);
      return e.response;
    } catch (e, s) {
      printError('PUT \$url – unexpected', error: e, stackTrace: s);
      return null;
    }
  }

  /// PATCH request. Returns the raw [Response], or `null` on unrecoverable error.
  Future<Response?> patch(
    String url, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    bool requiresAuth = true,
  }) async {
    try {
      if (requiresAuth) await _attachAuthHeader();
      _dio.options.headers['Content-Type'] = 'application/json';
      _applyCustomHeaders(headers);

      final response = await _dio.patch(
        url,
        data: data,
        queryParameters: queryParameters,
        options: Options(
          extra: {
            'is_header_required': requiresAuth,
            'retry_count_html': 0,
          },
        ),
      );

      if (kDebugMode) printLog('PATCH \$url ← \${response.statusCode}');
      return response;
    } on DioException catch (e) {
      printError('PATCH \$url', error: e);
      return e.response;
    } catch (e, s) {
      printError('PATCH \$url – unexpected', error: e, stackTrace: s);
      return null;
    }
  }

  /// DELETE request. Returns the raw [Response], or `null` on unrecoverable error.
  Future<Response?> delete(
    String url, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    bool requiresAuth = true,
  }) async {
    try {
      if (requiresAuth) await _attachAuthHeader();
      _dio.options.headers['Content-Type'] = 'application/json';
      _applyCustomHeaders(headers);

      final response = await _dio.delete(
        url,
        data: data,
        queryParameters: queryParameters,
        options: Options(
          extra: {
            'is_header_required': requiresAuth,
            'retry_count_html': 0,
          },
        ),
      );

      if (kDebugMode) printLog('DELETE \$url ← \${response.statusCode}');
      return response;
    } on DioException catch (e) {
      printError('DELETE \$url', error: e);
      return e.response;
    } catch (e, s) {
      printError('DELETE \$url – unexpected', error: e, stackTrace: s);
      return null;
    }
  }

  // ── Convenience body helpers ───────────────────────────────────────────────

  /// Returns the decoded JSON body of a GET, or an empty map on failure.
  Future<Map<String, dynamic>> getJson(
    String url, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    bool requiresAuth = false,
  }) async {
    final res = await get(
      url,
      queryParameters: queryParameters,
      headers: headers,
      requiresAuth: requiresAuth,
    );
    return _toJsonMap(res);
  }

  /// Returns the decoded JSON body of a POST, or an empty map on failure.
  Future<Map<String, dynamic>> postJson(
    String url, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    bool requiresAuth = false,
    bool isFormData = false,
  }) async {
    final res = await post(
      url,
      data: data,
      queryParameters: queryParameters,
      headers: headers,
      requiresAuth: requiresAuth,
      isFormData: isFormData,
    );
    return _toJsonMap(res);
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<dynamic> _buildPayload({
    required dynamic data,
    required bool isFormData,
    required bool isMultipleFiles,
  }) async {
    if (isMultipleFiles && data is List) {
      final form = FormData();
      for (final file in data) {
        form.files.add(
          MapEntry(
            'images',
            await MultipartFile.fromFile(file.path as String),
          ),
        );
      }
      return form;
    }
    if (isFormData && data is Map<String, dynamic>) {
      return FormData.fromMap(data);
    }
    if (data == null) return null;
    return jsonEncode(data);
  }

  Map<String, dynamic> _toJsonMap(Response? response) {
    if (response == null) return {};
    try {
      final body = response.data?.toString() ?? '';
      if (body.isEmpty || body == 'null') return {};
      if (_isHtmlResponse(body)) return {};
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {};
    } catch (e) {
      printError('_toJsonMap parse error', error: e);
      return {};
    }
  }

  bool _isHtmlResponse(dynamic value) {
    final text = value?.toString().toLowerCase() ?? '';
    return text.contains('<html') || text.contains('<!doctype');
  }

  String? _extractMessage(Response? response) {
    if (response == null) return null;
    try {
      final body = response.data?.toString() ?? '';
      if (body.isEmpty || body == 'null' || _isHtmlResponse(body)) {
        return 'Server error. Please try again later.';
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;
      final msg = decoded['message'];
      if (msg is List && msg.isNotEmpty) return msg.first?.toString();
      if (msg is String && msg.isNotEmpty) return msg;
      return null;
    } catch (_) {
      return null;
    }
  }

  void _maybeSnackBar(String? message) {
    if (message == null || message.isEmpty) return;
    final lower = message.toLowerCase();
    if (lower.contains('no data found') || lower.contains('no data')) return;
    _showSnackBar(title: _infoTitle, message: message);
  }

  void _showSnackBar({required String title, required String message}) {
    // TODO: Implement global snackbar via a navigator key / overlay.
    printLog('[\$title] \$message', level: 'w');
  }

  void _reject(
    String message,
    DioException err,
    ErrorInterceptorHandler handler,
  ) {
    _showSnackBar(title: _infoTitle, message: message);
    handler.reject(err);
  }

  Future<bool> _hasActiveConnection() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  Future<void> _doLogout(String message) async {
    try {
      await _storage.delete(key: AppConstants.tokenKey);
      await _storage.delete(key: AppConstants.refreshTokenKey);
      _showSnackBar(title: 'Session Expired', message: message);
      onLogout?.call();
      printLog('User logged out: \$message');
    } catch (e) {
      printError('Error during logout', error: e);
    }
  }
}
