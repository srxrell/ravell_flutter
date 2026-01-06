import "dart:convert";
import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:dart_openai/dart_openai.dart"; // Основной пакет для OpenRouter
import "package:readreels/managers/achievement_manager.dart";
import "package:readreels/screens/achievement_screen.dart";

// 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

class AIService {
  BuildContext? context;
  AIService({this.context});

  // Переносим промпт в константу, чтобы он был доступен во всех методах
  final String _systemPrompt = '''Ты — строгий модератор контента для социальной сети "Ravell".
Твоя задача: анализировать хештеги, заголовок и текст истории.
Запрещено: шифровки (PAY GORN и т.п.), оскорбления, пропаганда наркотиков, спам, реклама.
Слишком короткий или текст (пропускай если > 2 и ==100, но если <2 или > 100 не пропускай)
Эротика и маты разрешены ТОЛЬКО если это оправдано сюжетом.
Отвечай СТРОГО в формате JSON:
{"is_safe": boolean, "reason": "причина на русском"} Но не используй ``` json ``` ''';

  Future<void> moderateContent(String title, String content, {BuildContext? context}) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt("user_id");

    try {
      final completion = await OpenAI.instance.chat.create(
        model: "gpt-4o-mini", // Оригинальная модель OpenAI
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            content: [OpenAIChatCompletionChoiceMessageContentItemModel.text(_systemPrompt)],
            role: OpenAIChatMessageRole.system,
          ),
          OpenAIChatCompletionChoiceMessageModel(
            content: [OpenAIChatCompletionChoiceMessageContentItemModel.text('Заголовок: "$title". Текст: "$content"')],
            role: OpenAIChatMessageRole.user,
          ),
        ],
        // ChatGPT идеально поддерживает json_object
        responseFormat: {"type": "json_object"}, 
      );

      String? responseText = completion.choices.first.message.content?.first.text?.trim();

      if (responseText == null || responseText.isEmpty) {
        throw Exception("AI вернул пустой ответ");
      }

      // Чистим JSON от возможных артефактов
      final cleanJson = responseText.replaceAll(RegExp(r'```json|```'), '').trim();
      final jsonResponse = jsonDecode(cleanJson);

      if (jsonResponse['is_safe'] == false) {
        // Разблокировка секретной ачивки
        await AchievementManager.unlock('the_intruder');

        final currentContext = context;
        if (currentContext != null && currentContext.mounted) {
          _showViolationBanner(currentContext, userId, jsonResponse['reason'] ?? "Нарушение правил");
        }

        throw Exception(jsonResponse['reason']);
      }
      print('✅ Модерация ChatGPT пройдена');
    } catch (e) {
      print('Ошибка модерации: $e');
      rethrow;
    }
  }

  // Обновляем и этот метод под OpenRouter, чтобы не держать два разных SDK
  Future<void> moderateTag(String name) async {
    final completion = await OpenAI.instance.chat.create(
      model: "meta-llama/llama-3.1-8b-instruct:free",
      messages: [
        OpenAIChatCompletionChoiceMessageModel(
          content: [OpenAIChatCompletionChoiceMessageContentItemModel.text(_systemPrompt)],
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
    if (jsonResponse['is_safe'] == false) {
      throw Exception(jsonResponse['reason']);
    }
  }

  // Вспомогательный метод для баннера
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