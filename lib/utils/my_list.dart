// utils/my_list.dart

/// Singleton class to manage "My List" movies/TV shows across the app.
class MyList {
  // Private constructor
  MyList._internal();

  // Single instance
  static final MyList _instance = MyList._internal();

  // Factory constructor
  factory MyList() => _instance;

  // Set to store IDs of movies/TV shows in My List
  final Set<int> _ids = {};

  /// Adds an item to My List
  void add(int id) {
    _ids.add(id);
  }

  /// Removes an item from My List
  void remove(int id) {
    _ids.remove(id);
  }

  /// Toggles an item: adds if not exists, removes if exists
  void toggle(int id) {
    if (_ids.contains(id)) {
      _ids.remove(id);
    } else {
      _ids.add(id);
    }
  }

  /// Checks if an item is in My List
  bool contains(int id) => _ids.contains(id);

  /// Returns all IDs in My List
  Set<int> get all => _ids;

  /// Clears the entire My List
  void clear() => _ids.clear();
}
