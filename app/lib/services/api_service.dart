import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Response model for the rice analysis API
class AnalysisResult {
  final int wholeCount;
  final int brokenCount;
  final double brokenPercent;
  final double avgLengthBreadthRatio;
  final String grade;
  final String annotatedImageBase64;

  AnalysisResult({
    required this.wholeCount,
    required this.brokenCount,
    required this.brokenPercent,
    required this.avgLengthBreadthRatio,
    required this.grade,
    required this.annotatedImageBase64,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    return AnalysisResult(
      wholeCount: json['whole_count'] as int,
      brokenCount: json['broken_count'] as int,
      brokenPercent: (json['broken_percent'] as num).toDouble(),
      avgLengthBreadthRatio:
          (json['avg_length_breadth_ratio'] as num).toDouble(),
      grade: json['grade'] as String,
      annotatedImageBase64: json['annotated_image_base64'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'whole_count': wholeCount,
        'broken_count': brokenCount,
        'broken_percent': brokenPercent,
        'avg_length_breadth_ratio': avgLengthBreadthRatio,
        'grade': grade,
        'annotated_image_base64': annotatedImageBase64,
      };
}

/// Custom exception for API errors
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() =>
      'ApiException: $message${statusCode != null ? ' (status: $statusCode)' : ''}';
}

/// API service for communicating with the RiceGrade backend
class ApiService {
  // With `adb reverse tcp:8000 tcp:8000` this reaches the laptop from the tablet.
  // Replace with the Hugging Face Space URL when deployed.
  static const String _defaultBaseUrl = 'http://127.0.0.1:8000';

  final Dio _dio;

  ApiService({String? baseUrl})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl ?? _defaultBaseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
        )) {
    // Never log bodies: the response contains a large base64 image.
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: false,
        responseBody: false,
        error: true,
      ));
    }
  }

  /// Analyze a rice grain image from a file path.
  Future<AnalysisResult> analyzeImage(String imagePath) async {
    return _post(FormData.fromMap({
      'file': await MultipartFile.fromFile(imagePath),
    }));
  }

  /// Analyze an in-memory image.
  Future<AnalysisResult> analyzeImageBytes(
      List<int> bytes, String filename) async {
    return _post(FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    }));
  }

  Future<AnalysisResult> _post(FormData formData) async {
    try {
      final response = await _dio.post('/analyze', data: formData);
      return AnalysisResult.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw ApiException('Unexpected error: $e');
    }
  }

  ApiException _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
            'Connection timed out. The server may be sleeping (free tier). Please try again in a moment.');
      case DioExceptionType.connectionError:
        return ApiException(
            'Could not connect to the server. Please check if the backend is running at ${_dio.options.baseUrl}.');
      case DioExceptionType.badResponse:
        final data = e.response?.data;
        final message = (data is Map && data.containsKey('detail'))
            ? data['detail'].toString()
            : (data?.toString() ?? 'Request failed');
        return ApiException(message, statusCode: e.response?.statusCode);
      case DioExceptionType.cancel:
        return ApiException('Request was cancelled');
      default:
        return ApiException('Network error: ${e.message}');
    }
  }

  /// Update the base URL (e.g. for the Hugging Face Space)
  void setBaseUrl(String url) {
    _dio.options.baseUrl = url;
  }

  void close() => _dio.close();
}
