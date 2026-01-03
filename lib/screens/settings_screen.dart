import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:readreels/widgets/neowidgets.dart';
import 'package:readreels/services/updateChecker.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _fontScale = 1.0;
  double _titleFontScale = 1.0;
  bool _isLoading = true;

  final _updateChecker = UpdateChecker();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _fontScale = prefs.getDouble('story_font_scale') ?? 1.0;
      _titleFontScale = prefs.getDouble('title_font_scale') ?? 1.0;
      _isLoading = false;
    });
  }

  Future<void> _saveFontScale(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('story_font_scale', value);
    setState(() => _fontScale = value);
  }

  Future<void> _saveTitleFontScale(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('title_font_scale', value);
    setState(() => _titleFontScale = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Внешний вид',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                /// ---- UI BLOCK ----
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Размер шрифта в историях',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 16)),
                      Slider(
                        value: _fontScale,
                        min: 0.8,
                        max: 1.5,
                        divisions: 7,
                        onChanged: _saveFontScale,
                      ),
                      const SizedBox(height: 16),
                      const Text('Размер шрифта заголовков',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 16)),
                      Slider(
                        value: _titleFontScale,
                        min: 0.8,
                        max: 1.5,
                        divisions: 7,
                        onChanged: _saveTitleFontScale,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                const Text('Приложение',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    title: const Text('Проверить обновления'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      _updateChecker.checkUpdate(context);
                    },
                  )
                ),
              ],
            ),
    );
  }
}
