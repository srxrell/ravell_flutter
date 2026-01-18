import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:readreels/screens/authentication.dart';
import 'package:readreels/services/auth_service.dart';
import 'package:readreels/managers/settings_manager.dart';
import 'package:readreels/screens/premium_screen.dart';
import 'package:readreels/services/updateChecker.dart';

// Общая константа стиля для переиспользования
const Color neoBg = Color(0xFFFFFBF7);
const Color neoAccent = Colors.orange;

// Вспомогательный виджет для нео-карточки
Widget _buildNeoContainer({required Widget child, Color color = Colors.white, double padding = 16}) {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: color,
      border: Border.all(color: Colors.black, width: 2),
      boxShadow: const [
        BoxShadow(color: Colors.black, offset: Offset(4, 4)),
      ],
    ),
    child: child,
  );
}

// --- ГЛАВНЫЙ ЭКРАН НАСТРОЕК ---
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsManager>(context);

    return Scaffold(
      backgroundColor: neoBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: neoAccent,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 20),
              title: Row(
                children: [
                  const Icon(Icons.settings, color: Colors.black, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    settings.translate('settings'),
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 22),
                  ),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              _buildSectionTitle(settings.translate('language')),
              _buildNeoTile(context, Icons.language, settings.translate('choose_language'), 
                  () => _openSubScreen(context, const LanguageSettingsSubScreen()), trailing: settings.locale.toUpperCase()),
              
              _buildSectionTitle(settings.translate('personalize')),
              _buildNeoTile(context, Icons.format_size, settings.translate('reading_settings'), 
                  () => _openSubScreen(context, const ReadingSettingsSubScreen())),

              // account settings (logout)
              // on tap auth service logout
              _buildSectionTitle(settings.translate('account')),
              _buildNeoTile(context, Icons.logout, settings.translate('logout'), 
                  () {
                    AuthService().logout();
                    Navigator.push(context, MaterialPageRoute(builder: (context) => AuthenticationScreen()));
                  }),

              _buildSectionTitle(settings.translate('app')),
              _buildNeoTile(context, Icons.info_outline, settings.translate('information_updates'), 
                  () => _openSubScreen(context, const AppInfoSubScreen())),
              const SizedBox(height: 60),
            ]),
          ),
        ],
      ),
    );
  }

  void _openSubScreen(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, top: 24, bottom: 8),
      child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
    );
  }

  Widget _buildNeoTile(BuildContext context, IconData icon, String title, VoidCallback onTap, {String? trailing}) {
    return GestureDetector(
      onTap: onTap,
      child: _buildNeoContainer(
        padding: 0,
        child: ListTile(
          leading: Icon(icon, color: Colors.black),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (trailing != null) Text(trailing, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(width: 8),
              const Icon(Icons.north_east, color: Colors.black, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// --- ПОД-ЭКРАН: ТЕЛЕГРАМ ---
class TelegramSettingsSubScreen extends StatelessWidget {
  const TelegramSettingsSubScreen({super.key});

  @override
  Widget build(BuildContext context) {
 Future<void> _linkTelegram(BuildContext context) async {
    final settings = Provider.of<SettingsManager>(context, listen: false);
    
    // ВАЖНО: Получаем ID пользователя
    final userId = settings.userId;
    
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(settings.translate('auth_required'))),
      );
      return;
    }

    // Имя твоего бота (без @)
    const String botUsername = "ravell_fcm_bot"; // Убедись, что это правильное имя!
    
    // Формируем ссылку для диплинка
    // Это передаст команду /start bind_123 боту
    final Uri url = Uri.parse("https://t.me/$botUsername?start=bind_$userId");

    try {
      if (await canLaunchUrl(url)) {
        // Запускаем Telegram
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть Telegram')),
        );
      }
    }
  }
    final settings = Provider.of<SettingsManager>(context);
    return Scaffold(
      backgroundColor: neoBg,
      appBar: AppBar(backgroundColor: neoBg, elevation: 0, title: Text(settings.translate('link_telegram'), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
      body: Center(
        child: _buildNeoContainer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.telegram, size: 60, color: Colors.blue),
              const SizedBox(height: 16),
              Text(
                settings.isTelegramLinked ? settings.translate('connected') : settings.translate('not_connected'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  _linkTelegram(context);
                }, // Логика _linkTelegram
                child: _buildNeoContainer(
                  color: neoAccent,
                  child: Text(settings.translate('link_telegram'), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- ПОД-ЭКРАН: НАСТРОЙКИ ЧТЕНИЯ ---
// --- ПОД-ЭКРАН: НАСТРОЙКИ ЧТЕНИЯ ---
class ReadingSettingsSubScreen extends StatelessWidget {
  const ReadingSettingsSubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsManager>(context);
    
    return Scaffold(
      backgroundColor: neoBg,
      appBar: AppBar(
        backgroundColor: neoBg, 
        elevation: 0, 
        foregroundColor: Colors.black,
        title: Text(
          settings.translate('reading_settings'), 
          style: const TextStyle(fontWeight: FontWeight.bold)
        )
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 10),
        children: [
          // БЛОК ПРЕВЬЮ
          _buildSectionTitle(settings.translate('preview') ?? 'PREVIEW'),
          _buildNeoContainer(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  settings.translate('preview_title'),
                  style: TextStyle(
                    fontSize: 24 * settings.titleFontScale,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  settings.translate('preview_text'),
                  style: TextStyle(
                    fontSize: 16 * settings.fontScale,
                    height: settings.lineHeight,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 10),
          _buildSectionTitle(settings.translate('adjust') ?? 'ADJUST'),

          // ПОЛЗУНКИ
          _buildNeoSlider(
            settings.translate('title_size'), 
            settings.titleFontScale, 0.8, 1.6, 
            settings.setTitleFontScale
          ),
          _buildNeoSlider(
            settings.translate('text_size'), 
            settings.fontScale, 0.8, 1.6, 
            settings.setFontScale
          ),
          _buildNeoSlider(
            settings.translate('line_height'), 
            settings.lineHeight, 1.2, 2.0, 
            settings.setLineHeight
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, top: 10, bottom: 8),
      child: Text(
        title.toUpperCase(), 
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)
      ),
    );
  }

  Widget _buildNeoSlider(String label, double value, double min, double max, Function(double) onChanged) {
    return _buildNeoContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(value.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: Colors.black,
              inactiveTrackColor: Colors.grey[300],
              thumbColor: neoAccent,
              overlayColor: neoAccent.withOpacity(0.2),
              trackHeight: 8,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: value, 
              min: min, 
              max: max, 
              onChanged: onChanged
            ),
          ),
        ],
      ),
    );
  }
}

// --- ПОД-ЭКРАН: ЯЗЫК ---
class LanguageSettingsSubScreen extends StatelessWidget {
  const LanguageSettingsSubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsManager>(context);
    return Scaffold(
      backgroundColor: neoBg,
      appBar: AppBar(backgroundColor: neoBg, elevation: 0, title: Text(settings.translate('choose_language'), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
      body: ListView(
        padding: const EdgeInsets.only(top: 10),
        children: [
          _buildNeoRadioTile(settings, 'ru', 'Русский'),
          _buildNeoRadioTile(settings, 'en', 'English'),
        ],
      ),
    );
  }

  Widget _buildNeoRadioTile(SettingsManager settings, String code, String name) {
    bool isSelected = settings.locale == code;
    return GestureDetector(
      onTap: () => settings.setLocale(code),
      child: _buildNeoContainer(
        color: isSelected ? neoAccent : Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            if (isSelected) const Icon(Icons.check_circle, color: Colors.black),
          ],
        ),
      ),
    );
  }
}

// --- ПОД-ЭКРАН: МОДЕРАЦИЯ ---
class ModerationSettingsSubScreen extends StatelessWidget {
  const ModerationSettingsSubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsManager>(context);
    
    // Создаем карту: ключ — уровень, значение — ключ перевода для описания
    final Map<String, String> moderationOptions = {
      'anarchy': settings.translate('anarchy_desc'),
      'moderate': settings.translate('moderate_desc'),
      'strict': settings.translate('strict_desc'),
    };

    return Scaffold(
      backgroundColor: neoBg,
      appBar: AppBar(
        backgroundColor: neoBg, 
        elevation: 0, 
        foregroundColor: Colors.black,
        title: Text(
          settings.translate('moderation_settings'), 
          style: const TextStyle(fontWeight: FontWeight.bold)
        )
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 10, bottom: 20),
        // Перебираем записи карты (entries)
        children: moderationOptions.entries.map((entry) {
          final String level = entry.key;
          final String descKey = entry.value;
          bool isSelected = settings.moderationLevel == level;

          return GestureDetector(
            onTap: () => settings.setModerationLevel(level),
            child: _buildNeoContainer(
              // Если выбрано — подсвечиваем желтым (классика необрутализма)
              color: isSelected ? Colors.yellow : Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        settings.translate(level).toUpperCase(), 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
                      ),
                      if (isSelected) const Icon(Icons.check_circle, color: Colors.black),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    settings.translate(descKey), 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)
                  ),
                ],
              ),
            ),
          );
        }).toList(), // Теперь toList() вернет List<Widget> корректно
      ),
    );
  }
}

// --- ПОД-ЭКРАН: ИНФО ---
// --- ПОД-ЭКРАН: ИНФО И ОБНОВЛЕНИЯ ---
class AppInfoSubScreen extends StatelessWidget {
  const AppInfoSubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsManager>(context);
    final updateChecker = UpdateChecker();

    return Scaffold(
      backgroundColor: neoBg,
      appBar: AppBar(
        backgroundColor: neoBg,
        elevation: 0,
        foregroundColor: Colors.black,
        title: Text(
          settings.translate('information_updates'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        children: [
          // Кнопка обновления
          _buildNeoTileInfo(
            Icons.update,
            settings.translate('check_updates'),
            () => updateChecker.checkUpdate(context),
          ),
          
          // Кнопка "О приложении"
          _buildNeoTileInfo(
            Icons.info_outline,
            settings.translate('about_app'),
            () => _showNeoAboutDialog(context, settings),
          ),
        ],
      ),
    );
  }

  // Модалка "О приложении" в стиле необрутализма
  void _showNeoAboutDialog(BuildContext context, SettingsManager settings) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: neoBg,
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: Colors.black, width: 3),
          borderRadius: BorderRadius.zero, // Жесткие углы
        ),
        title: Row(
          children: [
            const Icon(Icons.bolt, color: neoAccent),
            const SizedBox(width: 10),
            Text(
              settings.translate('about_app').toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SvgPicture.asset("assets/icons/logo.svg"),
            const SizedBox(height: 10),
            Text(
              settings.translate('app_name'),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(height: 10),
             Text(
              settings.translate('app_info'),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: neoAccent,
                border: Border.all(color: Colors.black, width: 2),
                boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(3, 3))],
              ),
              child: const Text(
                "CLOSE",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNeoTileInfo(IconData icon, String title, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: _buildNeoContainer(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: Colors.black, size: 28),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          trailing: const Icon(Icons.arrow_forward_ios, color: Colors.black, size: 16),
        ),
      ),
    );
  }
}