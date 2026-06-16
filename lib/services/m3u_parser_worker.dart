// lib/services/m3u_parser_worker.dart
import 'package:flutter/foundation.dart';
import 'm3u_parser.dart';

List<Map<String, String>> _parseToMapWorker(String content) {
  return M3uParser.parseToMap(content);
}

/// Executa o parser em background usando compute().
Future<List<Map<String, String>>> parseM3uInIsolate(String content) async {
  final result = await compute(_parseToMapWorker, content);
  return List<Map<String, String>>.from(result);
}
