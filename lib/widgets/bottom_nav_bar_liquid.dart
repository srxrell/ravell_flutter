import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:readreels/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

class PERSISTENT_BOTTOM_NAV_BAR_LIQUID_GLASS extends StatefulWidget {
  final GlobalKey? homeKey;
  final GlobalKey? addKey;
  final GlobalKey? profileKey;

  const PERSISTENT_BOTTOM_NAV_BAR_LIQUID_GLASS({
    super.key,
    this.homeKey,
    this.addKey,
    this.profileKey,
  });

  @override
  State<PERSISTENT_BOTTOM_NAV_BAR_LIQUID_GLASS> createState() =>
      _PERSISTENT_BOTTOM_NAV_BAR_LIQUID_GLASSState();
}

class _PERSISTENT_BOTTOM_NAV_BAR_LIQUID_GLASSState
    extends State<PERSISTENT_BOTTOM_NAV_BAR_LIQUID_GLASS> {
  // Новый асинхронный метод для безопасной навигации
  Future<void> _navigateToProfile(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Пытаемся получить ID текущего пользователя.
    // Если null, пытаемся получить ID гостя.
    // Если оба null, user_id будет null.
    final int? user_id = prefs.getInt('user_id');
    debugPrint(user_id.toString());
    // Дополнительная проверка на 0, хотя GoRouter должен его ловить
    if (user_id != null) {
      // Переход к профилю с корректным ID
      context.go('/profile/$user_id');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Для просмотра профиля требуется авторизация.'),
        ),
      );
      // Если ID не найден (не авторизован), перенаправляем на экран авторизации
      context.go('/');
    }
  }

  // Общий виджет для элемента навигации
  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      // Увеличиваем область нажатия и контейнер для кнопки
      child: Container(
        width: 60, // Уменьшаем ширину кнопки для предотвращения переполнения
        height: 83,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment
                  .center, // Центрируем по вертикали внутри контейнера
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 30), // Слегка уменьшаем размер иконки
            // const SizedBox(height: 4),
            //Text(label, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            height: 85, // Оставляем высоту, но можно ее увеличить
            decoration: BoxDecoration(
              color: neoAccent,
              border: Border(
                top: const BorderSide(width: 3, color: Colors.black),
                bottom: const BorderSide(width: 7, color: Colors.black),
                left: const BorderSide(width: 3, color: Colors.black),
                right: const BorderSide(width: 5, color: Colors.black),
              ),
              borderRadius: const BorderRadius.all(Radius.circular(4410)),
            ),
            // Используем Padding для горизонтальных отступов от краев
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment
                        .spaceEvenly, // Распределяем пространство равномерно
                crossAxisAlignment:
                    CrossAxisAlignment
                        .center, // Центрируем весь ряд по вертикали
                children: [
                  _wrapWithShowcase(
                    key: widget.homeKey,
                    description: 'Главная лента историй',
                    child: _buildNavItem(
                      context,
                      icon: Icons.home,
                      onTap: () => context.push('/home'),
                    ),
                  ),
                  _wrapWithShowcase(
                    key: widget.addKey,
                    description: 'Создать свою историю',
                    child: _buildNavItem(
                      context,
                      icon: Icons.add_box,
                      onTap: () => context.push('/addStory'),
                    ),
                  ),
                  _wrapWithShowcase(
                    key: widget.profileKey,
                    description: 'Ваш личный профиль',
                    child: _buildNavItem(
                      context,
                      icon: Icons.person,
                      onTap: () => _navigateToProfile(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _wrapWithShowcase({
    GlobalKey? key,
    required String description,
    required Widget child,
  }) {
    if (key == null) return child;
    return Showcase(
      key: key,
      description: description,
      child: child,
    );
  }
}
