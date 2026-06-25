import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/channel.dart';
import 'm3u_parser.dart';

class ChannelService {
  // URLs de backup para maior confiabilidade
  static const List<String> _m3uUrls = [
    'http://nitidez.pro:80/get.php?username=Marcio&password=123456&type=m3u_plus',
    // Adicione mais URLs de backup aqui se tiver acesso
  ];

  static const String _lastFetchKey = 'last_fetch_time';
  static const int _maxRetries = 3;
  static const Duration _baseTimeout = Duration(seconds: 30);

  static Box<Channel>? _channelBox;

  static Future<void> initHive() async {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ChannelAdapter());
    }
    _channelBox = await Hive.openBox<Channel>('channels');
    if (kDebugMode) debugPrint('✅ Hive box initialized for channels');
  }

  /// Load channels from local cache or fetch from remote
  static Future<List<Channel>> loadChannels({bool forceRefresh = false}) async {
    // Check if we have cached data
    final box = _channelBox ?? await Hive.openBox<Channel>('channels');
    assert(() { _lastFetchKey; return true; }());

    if (!forceRefresh && box.isNotEmpty) {
      if (kDebugMode) debugPrint('✅ Loading ${box.length} channels from cache');
      return box.values.toList();
    }

    // Fetch from remote with retries
    if (kDebugMode) debugPrint('🔄 Fetching channels from remote (${_m3uUrls.length} URL(s) available)...');
    final channels = await _fetchFromRemoteWithRetries();
    if (channels.isNotEmpty) {
      await _saveToCache(channels);
    }
    return channels;
  }

  /// Fetch with exponential backoff retry strategy
  static Future<List<Channel>> _fetchFromRemoteWithRetries() async {
    for (int urlIndex = 0; urlIndex < _m3uUrls.length; urlIndex++) {
      final url = _m3uUrls[urlIndex];
      if (kDebugMode) debugPrint('🔗 Trying URL ${urlIndex + 1}/${_m3uUrls.length}: ${url.split('?')[0]}...');

      for (int attempt = 1; attempt <= _maxRetries; attempt++) {
        try {
          if (kDebugMode) debugPrint('   Attempt $attempt/$_maxRetries...');

          final response = await http.get(
            Uri.parse(url),
            headers: {
              'User-Agent': 'AngoMovie/1.2.0 Android',
              'Accept': '*/*',
              'Connection': 'keep-alive',
            },
          ).timeout(_baseTimeout);

          if (response.statusCode == 200) {
            if (kDebugMode) debugPrint('✅ Successfully fetched from URL ${urlIndex + 1}');
            final channels = M3uParser.parse(response.body);
            if (channels.isNotEmpty) {
              await _saveToCache(channels);
              return channels;
            }
          } else {
            if (kDebugMode) debugPrint('⚠️ HTTP ${response.statusCode} from URL ${urlIndex + 1}');
          }
        } catch (e) {
          if (kDebugMode) debugPrint('❌ Attempt $attempt failed: $e');

          // Exponential backoff before retry
          if (attempt < _maxRetries) {
            final delaySeconds = 2 * attempt; // 2s, 4s, 6s
            if (kDebugMode) debugPrint('⏳ Waiting ${delaySeconds}s before retry...');
            await Future.delayed(Duration(seconds: delaySeconds));
          }
        }
      }
    }

    // All URLs and retries failed - return cached data if available
    if (kDebugMode) debugPrint('❌ All URLs exhausted. Checking cache...');
    final box = _channelBox ?? await Hive.openBox<Channel>('channels');
    if (box.isNotEmpty) {
      if (kDebugMode) debugPrint('✅ Returning ${box.length} channels from stale cache');
      return box.values.toList();
    }

    // No data available at all
    if (kDebugMode) debugPrint('❌ No channels available - cache empty and all URLs failed');
    throw Exception(
      'Não foi possível carregar os canais.\n\n'
      'Verifique:\n'
      '• Sua conexão de internet\n'
      '• Se o domínio nitidez.pro está acessível\n'
      '• Se as credenciais estão corretas\n\n'
      'A app tentou 3 vezes em cada URL.'
    );
  }

  /// Fetch remote channels without touching Hive (safe to call from isolates).
  static Future<List<Channel>> fetchRemoteChannelsWithoutCache() async {
    for (int urlIndex = 0; urlIndex < _m3uUrls.length; urlIndex++) {
      final url = _m3uUrls[urlIndex];
      if (kDebugMode) debugPrint('🔗 (isolate-safe) Trying URL ${urlIndex + 1}/${_m3uUrls.length}: ${url.split('?')[0]}...');
      for (int attempt = 1; attempt <= _maxRetries; attempt++) {
        try {
          if (kDebugMode) debugPrint('   Attempt $attempt/$_maxRetries (isolate-safe)...');
          final response = await http.get(
            Uri.parse(url),
            headers: {
              'User-Agent': 'AngoMovie/1.2.0 Android',
              'Accept': '*/*',
              'Connection': 'keep-alive',
            },
          ).timeout(_baseTimeout);
          if (response.statusCode == 200) {
            if (kDebugMode) debugPrint('✅ (isolate-safe) Successfully fetched from URL ${urlIndex + 1}');
            final channels = M3uParser.parse(response.body);
            if (channels.isNotEmpty) {
              return channels;
            }
          } else {
            if (kDebugMode) debugPrint('⚠️ (isolate-safe) HTTP ${response.statusCode} from URL ${urlIndex + 1}');
          }
        } catch (e) {
          if (kDebugMode) debugPrint('❌ (isolate-safe) Attempt $attempt failed: $e');
          if (attempt < _maxRetries) {
            final delaySeconds = 2 * attempt;
            if (kDebugMode) debugPrint('⏳ (isolate-safe) Waiting ${delaySeconds}s before retry...');
            await Future.delayed(Duration(seconds: delaySeconds));
          }
        }
      }
    }
    // nothing found
    return <Channel>[];
  }

  /// Public wrapper to save channels to cache (safe to call from main isolate)
  static Future<void> saveChannelsToCache(List<Channel> channels) async {
    await _saveToCache(channels);
  }

  static Future<void> _saveToCache(List<Channel> channels) async {
    try {
      final box = _channelBox ?? await Hive.openBox<Channel>('channels');
      await box.clear();

      for (int i = 0; i < channels.length; i++) {
        await box.put(i, channels[i]);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastFetchKey, DateTime.now().millisecondsSinceEpoch);

      if (kDebugMode) debugPrint('💾 Saved ${channels.length} channels to cache successfully');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error saving to cache: $e');
    }
  }

  static Future<void> clearCache() async {
    try {
      final box = _channelBox ?? await Hive.openBox<Channel>('channels');
      await box.clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastFetchKey);
      if (kDebugMode) debugPrint('🗑️ Cache cleared successfully');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error clearing cache: $e');
    }
  }

  /// Get cache info for debugging
  static Future<String> getCacheInfo() async {
    try {
      final box = _channelBox ?? await Hive.openBox<Channel>('channels');
      final prefs = await SharedPreferences.getInstance();
      final lastFetch = prefs.getInt(_lastFetchKey);

      String lastFetchStr = 'Nunca';
      if (lastFetch != null) {
        final date = DateTime.fromMillisecondsSinceEpoch(lastFetch);
        lastFetchStr = date.toString();
      }

      return 'Canais em cache: ${box.length}\nÚltimo carregamento: $lastFetchStr';
    } catch (e) {
      return 'Erro ao obter info do cache: $e';
    }
  }
}
