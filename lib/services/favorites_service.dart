import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService {
  FavoritesService._();
  static final FavoritesService instance = FavoritesService._();
  factory FavoritesService() => instance;

  static const _key = 'smart_home_favorites';
  
  // Local cache to provide a synchronous stream
  List<String> _favorites = [];
  final _controller = StreamController<List<String>>.broadcast();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    final prefs = await SharedPreferences.getInstance();
    _favorites = prefs.getStringList(_key) ?? [];
    _controller.add(_favorites);
    _isInitialized = true;
  }

  Stream<List<String>> get favoritesStream {
    if (!_isInitialized) {
      initialize();
    }
    return _controller.stream;
  }

  bool isFavorite(String deviceId) {
    return _favorites.contains(deviceId);
  }

  Future<void> toggleFavorite(String deviceId) async {
    if (!_isInitialized) await initialize();
    
    if (_favorites.contains(deviceId)) {
      _favorites.remove(deviceId);
    } else {
      _favorites.add(deviceId);
    }
    
    _controller.add(_favorites);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _favorites);
  }
}
