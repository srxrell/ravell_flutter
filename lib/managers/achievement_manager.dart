import "package:shared_preferences/shared_preferences.dart";

class AchievementManager {
  static const _storageKey = 'unlocked_achievements';
  static const _readStoriesKey = 'read_stories_count';

  static Future<int> getReadStoriesCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_readStoriesKey) ?? 0;
  }

  static Future<void> incrementReadStories() async {
    final prefs = await SharedPreferences.getInstance();
    int current = prefs.getInt(_readStoriesKey) ?? 0;
    current++;
    await prefs.setInt(_readStoriesKey, current);

    // Проверка на ачивку "Успел прочитать 5 историй"
    if (current >= 5) {
      await unlock('read_5_stories');
    }
  }

  static Future<Set<String>> _getUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_storageKey)?.toSet() ?? {};
  }

  static Future<void> unlock(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final unlocked = await _getUnlocked();

    if (unlocked.contains(key)) return;

    unlocked.add(key);
    await prefs.setStringList(_storageKey, unlocked.toList());
  }

  static Future<bool> isUnlocked(String key) async {
    final unlocked = await _getUnlocked();
    return unlocked.contains(key);
  }
}
