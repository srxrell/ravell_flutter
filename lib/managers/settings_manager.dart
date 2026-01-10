import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:readreels/l10n/l10n.dart';

class SettingsManager extends ChangeNotifier {
  double _fontScale = 1.0;
  double _titleFontScale = 1.0;
  double _lineHeight = 1.5;
  String _locale = 'ru';
  int readerBackground = 0xFFF5F5F5;

  double get fontScale => _fontScale;
  double get titleFontScale => _titleFontScale;
  double get lineHeight => _lineHeight;
  String get locale => _locale;
  int get backgroundColor => readerBackground;
  String _moderationLevel = 'moderate';
String get moderationLevel => _moderationLevel;

  String translate(String key) => L10n.get(key, _locale);

  SettingsManager() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _fontScale = prefs.getDouble('story_font_scale') ?? 1.0;
    _titleFontScale = prefs.getDouble('title_font_scale') ?? 1.0;
    _lineHeight = prefs.getDouble('story_line_height') ?? 1.5;
    _locale = prefs.getString('app_locale') ?? 'ru';
    readerBackground = prefs.getInt('reader_bg_color') ?? 0xFFF5F5F5;
    _moderationLevel = prefs.getString('moderation_level') ?? 'moderate';
    notifyListeners();
  }

  void setModerationLevel(String level) async {
    _moderationLevel = level;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('moderation_level', level);
    notifyListeners();
  }

  Future<void> setReaderBackground(Color color) async {
    readerBackground = color.value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('reader_bg_color', color.value);
    notifyListeners();
  }

  Future<void> setFontScale(double value) async {
    _fontScale = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('story_font_scale', value);
    notifyListeners();
  }

  Future<void> setTitleFontScale(double value) async {
    _titleFontScale = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('title_font_scale', value);
    notifyListeners();
  }

  Future<void> setLineHeight(double value) async {
    _lineHeight = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('story_line_height', value);
    notifyListeners();
  }

  Future<void> setLocale(String locale) async {
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_locale', locale);
    notifyListeners();
  }
}
