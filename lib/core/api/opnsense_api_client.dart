import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../../features/profiles/firewall_profile.dart';
import 'demo_api_backend.dart';
import 'opnsense_exception.dart';

class OpnSenseApiClient {
  OpnSenseApiClient({
    required FirewallProfile profile,
    required FirewallCredentials credentials,
  })  : _profile = profile,
        _demo = profile.isDemo ? const DemoApiBackend() : null,
        _dio = Dio(
          BaseOptions(
            baseUrl: profile.isDemo
                ? 'https://demo.invalid'
                : normalizeBaseUrl(profile.baseUrl),
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 20),
            sendTimeout: const Duration(seconds: 20),
            headers: baseHeaders(credentials),
          ),
        ) {
    if (!profile.isDemo && profile.allowSelfSignedCertificate) {
      _dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.badCertificateCallback = (_, __, ___) => true;
          return client;
        },
      );
    }
  }

  final FirewallProfile _profile;
  final DemoApiBackend? _demo;
  final Dio _dio;

  FirewallProfile get profile => _profile;

  /// Headers that are safe for every OPNsense API request.
  ///
  /// Do not set Content-Type globally. OPNsense parses an authenticated request
  /// as JSON whenever that header is present, even for GET requests. A GET has
  /// no body, so advertising application/json there makes OPNsense reject the
  /// request as "Invalid JSON syntax" before the controller can run.
  static Map<String, String> baseHeaders(FirewallCredentials credentials) {
    return {
      HttpHeaders.authorizationHeader:
          'Basic ${base64Encode(utf8.encode('${credentials.apiKey}:${credentials.apiSecret}'))}',
      HttpHeaders.acceptHeader: 'application/json',
    };
  }

  static String normalizeBaseUrl(String value) {
    var result = value.trim();
    if (result.startsWith('demo://')) return result;
    if (!result.startsWith('http://') && !result.startsWith('https://')) {
      result = 'https://$result';
    }
    while (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }

  /// OPNsense's external API parser rejects an application/json POST when the
  /// raw request body is empty. Explicitly serialize every POST payload so
  /// no-argument actions such as firewall /apply still send the valid JSON
  /// document `{}` instead of a zero-length body.
  static String encodePostBody(Map<String, dynamic>? data) {
    return jsonEncode(data ?? const <String, dynamic>{});
  }

  Future<dynamic> getData(
    String path, {
    Map<String, dynamic>? queryParameters,
    Duration? receiveTimeout,
  }) async {
    if (_demo != null) {
      return _demo.getData(path, queryParameters: queryParameters);
    }
    try {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
        options: receiveTimeout == null
            ? null
            : Options(receiveTimeout: receiveTimeout),
      );
      return normalizeResponseData(response.data);
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? queryParameters,
    Duration? receiveTimeout,
  }) async {
    final data = await getData(
      path,
      queryParameters: queryParameters,
      receiveTimeout: receiveTimeout,
    );
    return _toMap(data);
  }

  Future<List<int>> getBytes(
    String path, {
    Map<String, dynamic>? queryParameters,
    Duration? receiveTimeout,
  }) async {
    if (_demo != null) {
      return _demo.getBytes(path, queryParameters: queryParameters);
    }
    try {
      final response = await _dio.get<List<int>>(
        path,
        queryParameters: queryParameters,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: receiveTimeout,
        ),
      );
      return response.data ?? <int>[];
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }

  Future<dynamic> postData(
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
    Duration? receiveTimeout,
  }) async {
    if (_demo != null) {
      return _demo.postData(
        path,
        data: data,
        queryParameters: queryParameters,
      );
    }
    try {
      final response = await _dio.post<dynamic>(
        path,
        data: encodePostBody(data),
        queryParameters: queryParameters,
        options: receiveTimeout == null
            ? Options(contentType: Headers.jsonContentType)
            : Options(
                contentType: Headers.jsonContentType,
                receiveTimeout: receiveTimeout,
              ),
      );
      return normalizeResponseData(response.data);
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
    Duration? receiveTimeout,
  }) async {
    final response = await postData(
      path,
      data: data,
      queryParameters: queryParameters,
      receiveTimeout: receiveTimeout,
    );
    return _toMap(response);
  }

  Future<void> testConnection() async {
    if (_demo != null) return;
    await getJson('/api/diagnostics/system/system_information');
  }

  /// OPNsense normally sends JSON with the correct response content type, but
  /// reverse proxies and some web-server customizations can expose a JSON body
  /// as text. Decode JSON-looking strings so callers receive the same shape in
  /// either case.
  static dynamic normalizeResponseData(dynamic data) {
    if (data is! String) return data;
    final text = data.trim();
    if (text.isEmpty) return data;
    final looksJson =
        (text.startsWith('{') && text.endsWith('}')) ||
            (text.startsWith('[') && text.endsWith(']'));
    if (!looksJson) return data;
    try {
      return jsonDecode(text);
    } on FormatException {
      return data;
    }
  }

  static Map<String, dynamic> _toMap(dynamic data) {
    final normalized = normalizeResponseData(data);
    if (normalized is Map<String, dynamic>) return normalized;
    if (normalized is Map) return Map<String, dynamic>.from(normalized);
    throw const OpnSenseException('The firewall returned an unexpected response.');
  }

  static OpnSenseException _mapDioError(DioException error) {
    final status = error.response?.statusCode;
    if (status == 401) {
      return const OpnSenseException(
        'Authentication failed. Check the API key and secret.',
        statusCode: 401,
      );
    }
    if (status == 403) {
      return const OpnSenseException(
        'The API user does not have permission for this resource.',
        statusCode: 403,
      );
    }
    if (status == 404) {
      return const OpnSenseException(
        'This API endpoint is not available on the connected firewall version.',
        statusCode: 404,
      );
    }
    if (status == 400 || status == 422) {
      final detail = _responseErrorDetail(error.response?.data);
      return OpnSenseException(
        detail.isEmpty
            ? 'The firewall rejected this request (HTTP $status).'
            : 'The firewall rejected this request: $detail',
        statusCode: status,
      );
    }
    if (error.type == DioExceptionType.receiveTimeout) {
      return const OpnSenseException(
        'The firewall did not finish this operation before the response timeout. Try again or use a nearer source/interface.',
      );
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.connectionError) {
      return const OpnSenseException(
        'Unable to reach the firewall. Check its address, VPN/LAN access and HTTPS configuration.',
      );
    }
    if (error.type == DioExceptionType.sendTimeout) {
      return const OpnSenseException(
        'The request could not be sent to the firewall before the timeout.',
      );
    }
    return OpnSenseException(
      _responseErrorDetail(error.response?.data).isNotEmpty
          ? _responseErrorDetail(error.response?.data)
          : (error.message ?? 'Unexpected network error.'),
      statusCode: status,
    );
  }

  static String _responseErrorDetail(dynamic raw) {
    final normalized = normalizeResponseData(raw);
    if (normalized is Map) {
      final map = Map<String, dynamic>.from(normalized);
      final validations = map['validations'] ?? map['validation'];
      if (validations is Map) {
        final parts = <String>[];
        for (final entry in validations.entries) {
          final value = entry.value;
          if (value is List) {
            for (final item in value) {
              final text = item.toString().trim();
              if (text.isNotEmpty) parts.add('${entry.key}: $text');
            }
          } else {
            final text = value?.toString().trim() ?? '';
            if (text.isNotEmpty) parts.add('${entry.key}: $text');
          }
        }
        if (parts.isNotEmpty) return parts.join(' · ');
      }
      for (final key in const ['message', 'error', 'detail', 'result']) {
        final value = map[key];
        if (value is String) {
          final text = value.trim();
          if (text.isNotEmpty && text.toLowerCase() != 'failed') return text;
        }
      }
    }
    if (normalized is String) {
      final text = normalized.trim();
      if (text.isNotEmpty && text.length <= 500) return text;
    }
    return '';
  }
}
