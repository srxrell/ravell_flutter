import "dart:convert";
import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:dart_openai/dart_openai.dart";
import "package:readreels/managers/achievement_manager.dart";
import "package:readreels/screens/achievement_screen.dart";

class AIService {
  BuildContext? context;
  AIService({this.context});

  // Генерируем промпт на лету в зависимости от настроек
  Future<String> _buildSystemPrompt() async {
    // Если решишь потом вернуть уровни, prefs пригодятся
    // final prefs = await SharedPreferences.getInstance(); 

    const String moodPrompt = """
      Ты — либеральный модератор литературной платформы. 
      РАЗРЕШЕНО: Любые художественные произведения, включая эротику (18+), порнорассказы, мат и жесткие сюжеты. 
      ЗАПРЕЩЕНО: 
      1. Спам и реклама (ссылки, казино).
      2. Бессмысленный текст (абракадабра).
      3. Призывы к насилию в реальном мире.
      4. Пропаганда наркотиков.""";

        return '''$moodPrompt
      Задача: анализ заголовка и текста.
      Отвечай СТРОГО в формате JSON: {"is_safe": boolean, "reason": "причина на русском"}. 
      Без лишнего текста, только JSON.''';
  }

  Future<void> moderateContent(String title, String content, {BuildContext? context}) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt("user_id");
    final systemPrompt = await _buildSystemPrompt(); // Получаем нужный уровень строгости

    try {
      final words = content.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
      final wordCount = words.length;

      if (wordCount == 100) {
        print('🎯 Ровно 100 слов! Разблокировка 100_runner');
        await AchievementManager.unlock('100_runner');
        // Можно также показать уведомление об ачивке здесь, если нужно
      }
      final completion = await OpenAI.instance.chat.create(
        model: "gpt-4o-mini",
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            content: [OpenAIChatCompletionChoiceMessageContentItemModel.text(systemPrompt)],
            role: OpenAIChatMessageRole.system,
          ),
          OpenAIChatCompletionChoiceMessageModel(
            content: [OpenAIChatCompletionChoiceMessageContentItemModel.text('Заголовок: "$title". Текст: "$content"')],
            role: OpenAIChatMessageRole.user,
          ),
        ],
        responseFormat: {"type": "json_object"}, 
      );

      String? responseText = completion.choices.first.message.content?.first.text?.trim();
      if (responseText == null || responseText.isEmpty) throw Exception("AI вернул пустой ответ");

      final cleanJson = responseText.replaceAll(RegExp(r'```json|```'), '').trim();
      final jsonResponse = jsonDecode(cleanJson);

      if (jsonResponse['is_safe'] == false) {
        await AchievementManager.unlock('the_intruder');
        final currentContext = context;
        if (currentContext != null && currentContext.mounted) {
          _showViolationBanner(currentContext, userId, jsonResponse['reason'] ?? "Нарушение правил");
        }
        throw Exception(jsonResponse['reason']);
      }
      print('✅ Модерация [${prefs.getString('moderation_level')}] пройдена');
    } catch (e) {
      rethrow;
    }
  }

  // Метод для тегов (использует тот же динамический промпт)
  Future<void> moderateTag(String name) async {
    final systemPrompt = await _buildSystemPrompt();
    final completion = await OpenAI.instance.chat.create(
      model: "gpt-4o-mini",
      messages: [
        OpenAIChatCompletionChoiceMessageModel(
          content: [OpenAIChatCompletionChoiceMessageContentItemModel.text(systemPrompt)],
          role: OpenAIChatMessageRole.system,
        ),
        OpenAIChatCompletionChoiceMessageModel(
          content: [OpenAIChatCompletionChoiceMessageContentItemModel.text('Проверь хештег: "$name"')],
          role: OpenAIChatMessageRole.user,
        ),
      ],
      responseFormat: {"type": "json_object"},
    );

    final responseText = completion.choices.first.message.content?.first.text;
    if (responseText == null) return;
    final jsonResponse = jsonDecode(responseText);
    if (jsonResponse['is_safe'] == false) throw Exception(jsonResponse['reason']);
  }

  void _showViolationBanner(BuildContext context, int? userId, String reason) {
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        padding: const EdgeInsets.all(16),
        content: Text('Нарушение: $reason. Получена ачивка! 🙅‍♂️'),
        leading: const Icon(Icons.emoji_events, color: Colors.amber, size: 40),
        backgroundColor: Colors.yellow[50],
        actions: [
          TextButton(
            onPressed: () => ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
            child: const Text('ОК'),
          ),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (c) => AchievementScreen(userId: userId ?? 0)),
              );
            },
            child: const Text('ПРОСМОТР'),
          ),
        ],
      ),
    );
  }
}