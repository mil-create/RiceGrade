import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_service.dart';

/// Grades a rice photo, either on-device or via the backend.
abstract class AnalyzerService {
  Future<AnalysisResult> analyze(String path);

  void dispose() {}
}

/// On-device analysis through the native OpenCV port (RiceAnalyzer.kt).
class LocalAnalyzer extends AnalyzerService {
  static const _channel = MethodChannel('ricegrade/analyzer');

  @override
  Future<AnalysisResult> analyze(String path) async {
    try {
      final map = await _channel.invokeMapMethod<String, dynamic>(
        'analyze',
        {'path': path},
      );
      if (map == null) throw ApiException('Analyzer returned no result');
      return AnalysisResult.fromJson(map);
    } on PlatformException catch (e) {
      throw ApiException(e.message ?? e.code);
    } on MissingPluginException {
      throw ApiException(
          'On-device analysis is not available on this platform');
    }
  }
}

/// Backend analysis through [ApiService].
class RemoteAnalyzer extends AnalyzerService {
  RemoteAnalyzer([ApiService? api]) : _api = api ?? ApiService();

  final ApiService _api;

  @override
  Future<AnalysisResult> analyze(String path) => _api.analyzeImage(path);

  @override
  void dispose() => _api.close();
}

final analyzerProvider = Provider<AnalyzerService>((ref) {
  final analyzer = LocalAnalyzer();
  ref.onDispose(analyzer.dispose);
  return analyzer;
});
