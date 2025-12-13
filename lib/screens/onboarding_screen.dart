import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:readreels/theme.dart';
import 'package:readreels/widgets/neowidgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnBoardingScreen extends StatefulWidget {
  const OnBoardingScreen({super.key});

  @override
  State<OnBoardingScreen> createState() => _OnBoardingScreenState();
}

class _OnBoardingScreenState extends State<OnBoardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _controller,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              children: const [
                _OnboardingPage(
                  title: 'Делитесь короткими историями',
                  subtitle: 'Ровно 100 слов. Ни больше, ни меньше.',
                  icon: Icons.view_agenda,
                ),
                _OnboardingPage(
                  title: 'Создавайте эмоции',
                  subtitle:
                      'Похожая ситуация? Есть что добавить? Отвечайте историей на историю',
                  icon: Icons.forum_outlined,
                ),
                _OnboardingPage(
                  title: 'Находите друзей',
                  subtitle:
                      'Твой текст — чъе-то вдохновение. Подписывайтесь и будьте тем, на кого подпиываются.',
                  icon: Icons.edit,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child:
                    _currentPage == 2
                        ? Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          child: NeoButton(
                            key: const ValueKey('neo'),
                            text: 'Начать',
                            type: NeoButtonType.general,
                            onPressed: () async {
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setBool('seenOnboarding', true);
                              context.go(
                                '/auth-check',
                              ); // Тут можешь заменить на AuthCheckerScreen
                            },
                          ),
                        )
                        : GestureDetector(
                          key: const ValueKey('gucha'),
                          onTap: () {
                            if (_currentPage < 2) {
                              _controller.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              );
                            }
                          },
                          child: SvgPicture.asset(
                            "assets/icons/guchaMiu.svg",
                            width: 60,
                            height: 60,
                          ),
                        ),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: MediaQuery.of(context).size.width,
            height: 500,
            decoration: const BoxDecoration(color: Color(0xFFFD9C00)),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Image.asset("assets/icons/bigbig.png"),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 9),
                Text(subtitle, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
