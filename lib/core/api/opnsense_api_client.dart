import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../../features/profiles/firewall_profile.dart';
import 'opnsense_exception.dart';

class OpnSenseApiClient {
  OpnSenseApiClient({
    required FirewallProfile profile,
    required FirewallCredentials credentials,
  })  : _profile = profile,
        _dio = Dio(
          BaseOptions(
            baseUrl: normalizeBaseUrl(profile.baseUrl),
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 12),
            sendTimeout: const Duration(seconds: 12),
            headers: {
              HttpHeaders.authorizationHeader:
                  'Basic ${base64Encode(utf8.encode('${credentials.apiKey}:${credentials.apiSecret}'))}',
              HttpHeaders.acceptHeader: 'application/json',
            },
          ),
        ) {
    if (profile.allowSelfSignedCertificate) {
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
  final Dio _dio;

  FirewallProfile get profile => _profile;

  static String normalizeBaseUrl(String value) {
    var result = value.trim();
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
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
      );
      return response.data;
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final data = await getData(path, queryParameters: queryParameters);
    return _toMap(data);
  }

  Future<List<int>> getBytes(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get<List<int>>(
        path,
        queryParameters: queryParameters,
        options: Options(responseType: ResponseType.bytes),
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
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        path,
        data: data ?? {},
        queryParameters: queryParameters,
      );
      return response.data;
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await postData(
      path,
      data: data,
      queryParameters: queryParameters,
    );
    return _toMap(response);
  }

  Future<void> testConnection() async {
    await getJson('/api/diagnostics/system/system_information');
  }

  static Map<String, dynamic> _toMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const OpnSenseException('OPNsense returned an unexpected response.');
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
        'This API endpoint is not available on the connected OPNsense version.',
        statusCode: 404,
      );
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return const OpnSenseException(
        'Unable to reach the firewall. Check its address, VPN/LAN access and HTTPS configuration.',
      );
    }
    return OpnSenseException(
      error.message ?? 'Unexpected network error.',
      statusCode: status,
    );
  }
}
