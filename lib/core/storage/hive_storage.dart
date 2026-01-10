import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

/// Manages Hive storage initialization and box access
class HiveStorage {
  static const String _storiesBoxName = 'stories';
  static const String _usersBoxName = 'users';
  static const String _achievementsBoxName = 'achievements';
  static const String _hashtagsBoxName = 'hashtags';
  static const String _commentsBoxName = 'comments';
  static const String _authBoxName = 'auth';
  static const String _settingsBoxName = 'settings';

  /// Initialize Hive storage
  static Future<void> init() async {
    // Initialize Hive with Flutter
    await Hive.initFlutter();

    // Get application documents directory for storage
    final appDocDir = await getApplicationDocumentsDirectory();
    Hive.init(appDocDir.path);

    // Register type adapters here (will be added as we create them)
    // Example: Hive.registerAdapter(StoryAdapter());
    
    print('✅ Hive storage initialized at: ${appDocDir.path}');
  }

  /// Open all required boxes
  static Future<void> openBoxes() async {
    await Future.wait([
      Hive.openBox(_storiesBoxName),
      Hive.openBox(_usersBoxName),
      Hive.openBox(_achievementsBoxName),
      Hive.openBox(_hashtagsBoxName),
      Hive.openBox(_commentsBoxName),
      Hive.openBox(_authBoxName),
      Hive.openBox(_settingsBoxName),
    ]);
    print('✅ All Hive boxes opened');
  }

  /// Get stories box
  static Box getStoriesBox() => Hive.box(_storiesBoxName);

  /// Get users box
  static Box getUsersBox() => Hive.box(_usersBoxName);

  /// Get achievements box
  static Box getAchievementsBox() => Hive.box(_achievementsBoxName);

  /// Get hashtags box
  static Box getHashtagsBox() => Hive.box(_hashtagsBoxName);

  /// Get comments box
  static Box getCommentsBox() => Hive.box(_commentsBoxName);

  /// Get auth box
  static Box getAuthBox() => Hive.box(_authBoxName);

  /// Get settings box
  static Box getSettingsBox() => Hive.box(_settingsBoxName);

  /// Clear all cached data (useful for logout)
  static Future<void> clearAllCache() async {
    await Future.wait([
      getStoriesBox().clear(),
      getUsersBox().clear(),
      getAchievementsBox().clear(),
      getHashtagsBox().clear(),
      getCommentsBox().clear(),
    ]);
    print('🗑️ All cache cleared');
  }

  /// Clear auth data
  static Future<void> clearAuthData() async {
    await getAuthBox().clear();
    print('🗑️ Auth data cleared');
  }

  /// Close all boxes (call on app dispose if needed)
  static Future<void> closeAll() async {
    await Hive.close();
    print('📦 All Hive boxes closed');
  }
}
