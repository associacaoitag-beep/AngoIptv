import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:isolate';
import '../models/channel.dart';
import '../services/channel_service.dart';
import '../services/m3u_parser.dart';

enum LoadingState { idle, loading, success, error }

class ChannelProvider extends ChangeNotifier {
  List<Channel> _allChannels = [];
  List<Channel> _filteredChannels = [];
  Map<String, List<Channel>> _categorizedChannels = {};
  LoadingState _state = LoadingState.idle;
  String _errorMessage = '';
  String _searchQuery = '';
  Channel? _featuredChannel;
  
  // Lazy loading state
  int _loadedCategoriesCount = 0;
  final int _categoriesPerBatch = 5;
  Timer? _categoryLoadTimer;
  final Set<String> _loadingCategories = {};

  List<Channel> get allChannels => _allChannels;
  List<Channel> get filteredChannels =>
      _searchQuery.isEmpty ? _allChannels : _filteredChannels;
  Map<String, List<Channel>> get categorizedChannels => _categorizedChannels;
  LoadingState get state => _state;
  String get errorMessage => _errorMessage;
  Channel? get featuredChannel => _featuredChannel;
  bool get isLoading => _state == LoadingState.loading;
  bool get hasError => _state == LoadingState.error;
  bool get hasData => _allChannels.isNotEmpty;

  /// Load channels with isolate processing and lazy category loading
  Future<void> loadChannels({bool forceRefresh = false}) async {
    if (_state == LoadingState.loading) return;
    
    _state = LoadingState.loading;
    _errorMessage = '';
    _loadedCategoriesCount = 0;
    _categorizedChannels.clear();
    notifyListeners();

    try {
      if (kDebugMode) debugPrint('📥 Starting channel load (forceRefresh: $forceRefresh)');
      
      // Load channels in isolate to avoid blocking UI
      final channels = await _loadChannelsInIsolate(forceRefresh);
      
      if (channels.isEmpty) {
        _errorMessage = 'Nenhum canal foi carregado. Verifique a conexão e tente novamente.';
        _state = LoadingState.error;
        if (kDebugMode) debugPrint('❌ Nenhum canal carregado');
      } else {
        _allChannels = channels;
        _featuredChannel = channels.isNotEmpty ? channels.first : null;
        
        if (kDebugMode) debugPrint('✅ ${channels.length} channels loaded successfully');
        
        // Start lazy loading categories
        _startLazyCategoryLoading(channels);
        
        _state = LoadingState.success;
      }
    } catch (e) {
      _errorMessage = 'Erro ao carregar canais:\n$e\n\nVerifique sua conexão e tente novamente.';
      _state = LoadingState.error;
      if (kDebugMode) debugPrint('❌ Error loading channels: $e');
    }

    notifyListeners();
  }

  /// Load channels in a background isolate
Future<List<Channel>> _loadChannelsInIsolate(bool forceRefresh) async {
  try {
    final receivePort = ReceivePort();
    await Isolate.spawn(
      _channelLoaderEntry,
      [receivePort.sendPort, forceRefresh],
      debugName: 'ChannelLoader',
    );

    // Set a timeout for the isolate
    final channels = await receivePort.first.timeout(
      const Duration(minutes: 1),
      onTimeout: () => throw TimeoutException('Carregamento de canais expirou (timeout de 1 minuto)'),
    ) as List<Channel>;

    // Save to Hive in main isolate (safe)
    if (channels.isNotEmpty) {
      await ChannelService.saveChannelsToCache(channels);
    }

    return channels;
  } catch (e) {
    if (kDebugMode) debugPrint('⚠️ Isolate error: $e, falling back to main thread');
    // Fallback to main thread if isolate fails
    return await ChannelService.loadChannels(forceRefresh: forceRefresh);
  }
}

  /// Isolate entry point
  static Future<void> _channelLoaderEntry(List<dynamic> args) async {
    final SendPort sendPort = args[0];
    final bool forceRefresh = args[1];
    
    try {
      if (kDebugMode) debugPrint('🔄 Isolate: Loading channels...');
      final channels = await ChannelService.loadChannels(forceRefresh: forceRefresh);
      sendPort.send(channels);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Isolate error: $e');
      sendPort.send([]);
    }
  }

  /// Start lazy loading categories in batches
  void _startLazyCategoryLoading(List<Channel> channels) {
    _categoryLoadTimer?.cancel();
    
    // Get all unique categories
    final allCategories = channels
        .map((c) => c.groupTitle)
        .toSet()
        .toList()
        ..sort();

    if (kDebugMode) debugPrint('📂 Loading ${allCategories.length} categories lazily');
    _loadBatchOfCategories(channels, allCategories, 0);
  }

  /// Load a batch of categories
  void _loadBatchOfCategories(
    List<Channel> channels,
    List<String> allCategories,
    int startIndex,
  ) {
    final endIndex =
        (startIndex + _categoriesPerBatch).clamp(0, allCategories.length);

    for (int i = startIndex; i < endIndex; i++) {
      final category = allCategories[i];
      final categoryChannels = channels
          .where((c) => c.groupTitle == category)
          .toList();
      
      _categorizedChannels[category] = categoryChannels;
      _loadedCategoriesCount++;
    }

    if (kDebugMode) debugPrint('📂 Loaded $_loadedCategoriesCount/${allCategories.length} categories');
    notifyListeners();

    // Schedule next batch
    if (endIndex < allCategories.length) {
      _categoryLoadTimer = Timer(const Duration(milliseconds: 200), () {
        _loadBatchOfCategories(channels, allCategories, endIndex);
      });
    }
  }

  /// Optimized search with debouncing
  void search(String query) {
    _searchQuery = query.trim();
    if (_searchQuery.isEmpty) {
      _filteredChannels = [];
    } else {
      final q = _searchQuery.toLowerCase();
      _filteredChannels = _allChannels
          .where((c) =>
              c.name.toLowerCase().contains(q) ||
              c.groupTitle.toLowerCase().contains(q))
          .toList();
    }
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    _filteredChannels = [];
    notifyListeners();
  }

  Future<void> refreshChannels() async {
    await loadChannels(forceRefresh: true);
  }

  @override
  void dispose() {
    _categoryLoadTimer?.cancel();
    super.dispose();
  }
}
