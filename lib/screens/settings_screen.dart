import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:readreels/managers/settings_manager.dart';
import 'package:readreels/widgets/neowidgets.dart';
import 'package:readreels/services/updateChecker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:readreels/theme.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _updateChecker = UpdateChecker();
  Future<void> _linkTelegram(int userId) async {
  const botUsername = "ravell_fcm_bot"; 
  // Попробуем сначала прямую схему приложения, если не выйдет - обычную ссылку
  final tgUrl = Uri.parse("tg://resolve?domain=$botUsername&start=bind_$userId");
  final httpsUrl = Uri.parse("https://t.me/$botUsername?start=bind_$userId");
  
  try {
    if (await canLaunchUrl(tgUrl)) {
      await launchUrl(tgUrl, mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(httpsUrl)) {
      await launchUrl(httpsUrl, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch URL';
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }
}

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsManager>(context);
    final userId = settings.userId;

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        title: Text(settings.translate('settings')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (userId != null) ...[ // Показываем только если залогинен
            Text(
              // Добавь 'notifications': 'Уведомления' в L10n
              settings.translate('notifications'), 
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildSettingsContainer(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.send, color: Colors.blue),
                title: Text(
                  // Добавь 'telegram_bot': 'Telegram Бот' в L10n
                  settings.translate('link_telegram'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  // Пока используем локальный флаг, в идеале брать из профиля
                  settings.isTelegramLinked 
                      ? settings.translate('connected') // 'Подключено'
                      : settings.translate('not_connected'), // 'Подключить'
                  style: TextStyle(
                    color: settings.isTelegramLinked ? Colors.green : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: const Icon(Icons.open_in_new, color: Colors.black),
                onTap: () => _linkTelegram(userId),
              ),
            ),],
            SizedBox(height: 10),
          Text(
            settings.translate('reading_settings'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          _buildSettingsContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSlider(
                  label: settings.translate('text_size'),
                  value: settings.fontScale,
                  min: 0.8,
                  max: 1.6,
                  divisions: 8,
                  onChanged: settings.setFontScale,
                ),
                _buildSlider(
                  label: settings.translate('title_size'),
                  value: settings.titleFontScale,
                  min: 0.8,
                  max: 1.6,
                  divisions: 8,
                  onChanged: settings.setTitleFontScale,
                ),
                _buildSlider(
                  label: settings.translate('line_height'),
                  value: settings.lineHeight,
                  min: 1.2,
                  max: 2.0,
                  divisions: 8,
                  onChanged: settings.setLineHeight,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
          Text(
            settings.translate('language'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
              value: settings.locale,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(20),
              ),
              icon: const Icon(Icons.language, color: Colors.black),
              isExpanded: true,
              dropdownColor: Colors.white,
              items: [
                DropdownMenuItem(
                  value: 'ru',
                  child: Text(settings.translate('russian'), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                DropdownMenuItem(
                  value: 'en',
                  child: Text(settings.translate('english'), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
              onChanged: (val) {
                if (val != null) settings.setLocale(val);
              },
            ),


            SizedBox(height: 10),

            Text(
            settings.translate('moderation_level'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          
          _buildSettingsContainer(
  child: ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(
      settings.translate('moderation_level'),
      style: const TextStyle(fontWeight: FontWeight.bold),
    ),
    trailing: DropdownButton<String>(
      value: settings.moderationLevel,
      underline: const SizedBox(),
      onChanged: (val) {
        if (val != null) settings.setModerationLevel(val);
      },
      items: [
        DropdownMenuItem(
          value: 'anarchy', 
          child: Text(settings.translate('anarchy'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
        ),
        DropdownMenuItem(
          value: 'moderate', 
          child: Text(settings.translate('moderate'))
        ),
        DropdownMenuItem(
          value: 'strict', 
          child: Text(settings.translate('strict'))
        ),
      ],
    ),
  ),
),

          const SizedBox(height: 32),
          Text(
            settings.translate('app'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          _buildSettingsContainer(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                settings.translate('check_updates'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.black),
              onTap: () => _updateChecker.checkUpdate(context),
            ),
          ),
          const SizedBox(height: 12),
          _buildSettingsContainer(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                settings.translate('about_app'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('${settings.translate('version')} 1.0'),
              trailing: const Icon(Icons.info_outline, color: Colors.black),
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'Ravell',
                  applicationVersion: '1.0',
                  applicationIcon: SvgPicture.asset('assets/icons/logo.svg', width: 50, height: 50),
                  children: [
                    Text(settings.translate('app_description')),
                    Text('${settings.translate('author')}: Serell Vorne'),
                    const Text('Email: serrelvorne@gmail.com'),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Language button removed as it's replaced by dropdown

  Widget _buildSettingsContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black,
            offset: Offset(4, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required Function(double) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: neoAccent,
            inactiveTrackColor: Colors.grey[200],
            thumbColor: Colors.black,
            overlayColor: neoAccent.withOpacity(0.2),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
