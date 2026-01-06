import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:readreels/managers/settings_manager.dart';
import 'package:readreels/widgets/neowidgets.dart';
import 'package:readreels/services/updateChecker.dart';
import 'package:readreels/theme.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _updateChecker = UpdateChecker();

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsManager>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.translate('settings')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
