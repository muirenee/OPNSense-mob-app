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
            headers: {
              HttpHeaders.authorizationHeader:
                  'Basic ${base64Encode(utf8.encode('${credentials.apiKey}:${credentials.apiSecret}'))}',
              HttpHeaders.acceptHeader: 'application/json',
              HttpHeaders.contentTypeHeader: 'application/json',
            },
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
        data: data ?? {},
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
      error.message ?? 'Unexpected network error.',
      statusCode: status,
    );
  }
}
