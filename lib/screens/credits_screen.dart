import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:readreels/models/story.dart';
import 'package:readreels/screens/story_detail.dart';
import 'package:readreels/widgets/heart_animation.dart';
import 'package:readreels/services/story_service.dart' as st;
import 'package:readreels/widgets/bottom_nav_bar_liquid.dart';
import 'package:readreels/widgets/neowidgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:readreels/theme.dart';
import 'package:readreels/widgets/comments_bottom_sheet.dart';
import 'package:readreels/widgets/expandable_story_content.dart';
import 'package:url_launcher/url_launcher.dart';

class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NeoButton(
                onPressed: () {
                  launchUrl(Uri.parse("https://t.me/vorneblablabla"));
                },
                text: 'Телеграм канал',
              ),
              const SizedBox(height: 10),
              NeoButton(
                onPressed: () {
                  launchUrl(Uri.parse("https://t.me/caelis1784"));
                },
                text: 'Связаться',
              ),
            ],
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            SvgPicture.asset("assets/icons/creditlogo.svg"),
            const SizedBox(height: 20),
            // Заголовок
            const Text(
              'Ravell — от создателей для создателей',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            // Описание
            const Text(
              'Ravell — приложение для обмена короткими историями в 100 слов.\n\n'
              'Здесь каждый может написать историю из своей жизни, придумать историю, '
              'а также ответить похожей ситуацией на уже существующей ветке.',
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 20),
            // Разработчик с акцентом
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: Colors.black,
                ),
                children: [
                  const TextSpan(text: 'Разработчик: '),
                  TextSpan(
                    text: 'Serell Vorne (@caelis1784)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: neoAccent, // импорт из theme.dart
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
