import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/models/food_model.dart';

class FavoriteFoodsNotifier extends Notifier<List<FoodModel>> {
  static const _key = 'favorite_foods';

  @override
  List<FoodModel> build() {
    _loadFavorites();
    return [];
  }

  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final strList = prefs.getStringList(_key);
      if (strList != null) {
        final List<FoodModel> loaded = [];
        for (final str in strList) {
          try {
            loaded.add(FoodModel.fromJson(str));
          } catch (e) {
            // Ignore parse errors for individual items
          }
        }
        state = loaded;
      }
    } catch (e) {
      // Handle error safely
    }
  }

  Future<void> _saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final strList = state.map((f) => f.toJson()).toList();
      await prefs.setStringList(_key, strList);
    } catch (e) {
      // Handle error safely
    }
  }

  bool isFavorite(String id) {
    return state.any((f) => f.id == id);
  }

  Future<void> toggleFavorite(FoodModel food) async {
    if (isFavorite(food.id)) {
      state = state.where((f) => f.id != food.id).toList();
    } else {
      state = [...state, food];
    }
    await _saveFavorites();
  }
}

final favoriteFoodsProvider = NotifierProvider<FavoriteFoodsNotifier, List<FoodModel>>(() {
  return FavoriteFoodsNotifier();
});
