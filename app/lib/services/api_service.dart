import 'package:dio/dio.dart';

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

  Map<String, dynamic> toJson() {
    return {
      'whole_count': wholeCount,
      'broken_count': brokenCount,
      'broken_percent': brokenPercent,
      'avg_length_breadth_ratio': avgLengthBreadthRatio,
      'grade': grade,
      'annotated_image_base64': annotatedImageBase64,
    };
  }
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
  final Dio _dio;
  static const String _defaultBaseUrl = 'http://127.0.0.1:8000';

  ApiService({String? baseUrl})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl ?? _defaultBaseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
          headers: {'Content-Type': 'multipart/form-data'},
        )) {
    // Add logging interceptor in debug mode
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      error: true,
    ));
  }

  /// Analyze a rice grain image
  /// Returns [AnalysisResult] on success, throws [ApiException] on failure
  Future<AnalysisResult> analyzeImage(String imagePath) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(imagePath),
      });

      final response = await _dio.post('/analyze', data: formData);

      if (response.statusCode == 200) {
        return AnalysisResult.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw ApiException(
          'Server returned ${response.statusCode}: ${response.data}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw ApiException('Unexpected error: $e');
    }
  }

  /// Analyze image from bytes (useful for in-memory images)
  Future<AnalysisResult> analyzeImageBytes(
      List<int> bytes, String filename) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      });

      final response = await _dio.post('/analyze', data: formData);

      if (response.statusCode == 200) {
        return AnalysisResult.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw ApiException(
          'Server returned ${response.statusCode}: ${response.data}',
          statusCode: response.statusCode,
        );
      }
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
        final statusCode = e.response?.statusCode;
        String message = 'Request failed';
        if (e.response?.data != null) {
          final data = e.response!.data;
          if (data is Map && data.containsKey('detail')) {
            message = data['detail'].toString();
          } else {
            message = data.toString();
          }
        }
        return ApiException(message, statusCode: statusCode);
      case DioExceptionType.cancel:
        return ApiException('Request was cancelled');
      default:
        return ApiException('Network error: ${e.message}');
    }
  }

  /// Update the base URL (useful when deploying to Hugging Face Spaces)
  void setBaseUrl(String url) {
    _dio.options.baseUrl = url;
  }

  /// Close the Dio client
  void close() {
    _dio.close();
  }
}

/// Provider for the API service
// This will be added to a providers file or main.dart
// final apiServiceProvider = Provider<ApiService>((ref) => ApiService());
