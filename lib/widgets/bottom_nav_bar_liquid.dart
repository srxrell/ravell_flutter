import 'package:flutter/material.dart';
import 'package:readreels/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:go_router/go_router.dart';

import 'package:readreels/managers/settings_manager.dart';
import 'package:provider/provider.dart';

class PERSISTENT_BOTTOM_NAV_BAR_LIQUID_GLASS extends StatelessWidget {
  final String currentRoute;
  final GlobalKey? homeKey;
  final GlobalKey? addKey;
  final GlobalKey? profileKey;

  const PERSISTENT_BOTTOM_NAV_BAR_LIQUID_GLASS({
    super.key,
    required this.currentRoute,
    this.homeKey,
    this.addKey,
    this.profileKey,
  });

  Widget _buildNavItem({
    required String route,
    required IconData activeIcon,
    required IconData inactiveIcon,
    required VoidCallback onTap,
  }) {
    final isActive = currentRoute == route || currentRoute.startsWith('$route/');
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        height: 83,
        child: Icon(
          isActive ? activeIcon : inactiveIcon,
          size: 30,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _wrap(GlobalKey? key, String description, Widget child) {
    if (key == null) return child;
    return Showcase(key: key, description: description, child: child);
  }

  Future<void> _goToAddStory(BuildContext context) async {
    final settings = Provider.of<SettingsManager>(context, listen: false);
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getInt('guest_id') != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(settings.translate('only_for_registered')))); context.go('/auth-check'); 
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              dense: true,
              leading: const Icon(Icons.language),
              title: const Text("Global"),
              subtitle: const Text("Your story will be visible to everyone"),
              onTap: () => context.push('/addStory'),
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.edit),
              title: const Text("Draft"),
              subtitle: const Text(
                  "Create a draft from your story before publishing"),
              onTap: () => context.push('/addStoryDraft'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _goToProfile(BuildContext context) async {
    final settings = Provider.of<SettingsManager>(context, listen: false);
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getInt('guest_id') != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(settings.translate('only_for_registered')))); context.go('/auth-check'); 
      return;
    }
    final userId = prefs.getInt('user_id');
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(settings.translate('only_for_registered')))); context.go('/auth-check'); 
      return;
    }
    context.push('/profile/$userId');
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsManager>(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      height: 85,
      decoration: BoxDecoration(
        color: neoAccent,
        border: const Border(
          top: BorderSide(width: 3, color: Colors.black),
          bottom: BorderSide(width: 7, color: Colors.black),
          left: BorderSide(width: 3, color: Colors.black),
          right: BorderSide(width: 5, color: Colors.black),
        ),
        borderRadius: BorderRadius.circular(4410),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _wrap(
            homeKey,
            settings.translate('nav_home'),
            _buildNavItem(
              route: '/home',
              activeIcon: Icons.home,
              inactiveIcon: Icons.home_outlined,
              onTap: () => context.go('/home'),
            ),
          ),
          _wrap(
            addKey,
            settings.translate('nav_add'),
            _buildNavItem(
              route: '/addStory',
              activeIcon: Icons.add_box,
              inactiveIcon: Icons.add_box_outlined,
              onTap: () => _goToAddStory(context),
            ),
          ),
          _wrap(
            profileKey,
            settings.translate('nav_profile'),
            _buildNavItem(
              route: '/profile',
              activeIcon: Icons.person,
              inactiveIcon: Icons.person_outline,
              onTap: () => _goToProfile(context),
            ),
          ),
        ],
      ),
    );
  }
}
