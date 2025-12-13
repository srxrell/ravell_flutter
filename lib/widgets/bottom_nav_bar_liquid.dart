import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:readreels/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PERSISTENT_BOTTOM_NAV_BAR_LIQUID_GLASS extends StatefulWidget {
  const PERSISTENT_BOTTOM_NAV_BAR_LIQUID_GLASS({super.key});

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
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      // Увеличиваем область нажатия и контейнер для кнопки
      child: Container(
        width: 80, // Увеличиваем ширину кнопки
        height: 83,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment
                  .center, // Центрируем по вертикали внутри контейнера
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 35), // Увеличиваем размер иконки
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width,
      // margin: EdgeInsets.all(10),
      // height: 85, // Оставляем высоту, но можно ее увеличить
      decoration: BoxDecoration(
        color: bottomBackground,
        // border: Border(
        //   top: BorderSide(width: 3, color: Colors.black),
        //   bottom: BorderSide(width: 3, color: Colors.black),
        //   left: BorderSide(width: 3, color: Colors.black),
        //   right: BorderSide(width: 3, color: Colors.black),
        // ),
        // borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      // Используем Padding для горизонтальных отступов от краев
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 21.0),
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment
                  .spaceBetween, // Распределяем пространство между элементами
          crossAxisAlignment:
              CrossAxisAlignment.center, // Центрируем весь ряд по вертикали
          children: [
            _buildNavItem(
              context,
              icon: Icons.home,
              label: "Feed",
              onTap: () => context.go('/home'),
            ),
            _buildNavItem(
              context,
              icon: Icons.add_box,
              label: "Add",
              onTap: () => context.go('/addStory'),
            ),
            _buildNavItem(
              context,
              icon: Icons.person,
              label: "Me",
              onTap: () => _navigateToProfile(context),
            ),
          ],
        ),
      ),
    );
  }
}
