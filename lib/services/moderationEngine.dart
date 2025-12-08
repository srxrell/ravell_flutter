// moderation_engine.dart
class ModerationEngine {
  // === ЖЁСТКИЕ СТОП-СЛОВА (автобан) ===
  static final _hardRegex = RegExp(
    r'\b(?:детс[кх]|педо|инцест|суицид|убийство|террор|наркот[иа]|героин|кокаин|оружие|взрывчатк)\w*\b',
    caseSensitive: false,
  );

  // === МЯГКИЕ СТОП-СЛОВА (требуют контекста) ===
  static final _softRegex = RegExp(
    r'\b(?:развели|обманули|купить|продать|заработок|деньги|переведи|отправь|крипта|биткоин|казино|ставк[иа])\w*\b',
    caseSensitive: false,
  );

  // === КОНТЕКСТ РАЗРЕШЕНИЯ (образование/предупреждение) ===
  static final _contextRegex = RegExp(
    r'(?:не\s+(?:делай|повторяй|верь|попадайся)|осторожно|предупреждаю|будьте\s+бдительны|мошенничеств[оа]|афер[аы]|обман)',
    caseSensitive: false,
  );

  // === URL/ССЫЛКИ ===
  static final _urlRegex = RegExp(
    r'(?:https?://|www\.|t\.me/|bit\.ly/|vk\.cc/)\S+',
    caseSensitive: false,
  );

  // === ОСНОВНОЙ МЕТОД ===
  static ({bool allowed, String? reason}) moderate(String text) {
    final lowerText = text.toLowerCase();

    // 1. ЖЁСТКИЕ СТОП-СЛОВА → мгновенный бан
    if (_hardRegex.hasMatch(lowerText)) {
      return (allowed: false, reason: 'Запрещённый контент');
    }

    // 2. ССЫЛКИ → бан (кроме образовательных контекстов)
    if (_urlRegex.hasMatch(text) && !_contextRegex.hasMatch(lowerText)) {
      return (allowed: false, reason: 'Ссылки запрещены');
    }

    // 3. МЯГКИЕ СТОП-СЛОВА → проверяем контекст
    if (_softRegex.hasMatch(lowerText)) {
      final hasSoftWords = _softRegex.allMatches(lowerText);
      final hasContext = _contextRegex.hasMatch(lowerText);

      // Если есть стоп-слова, но нет образовательного контекста → блок
      if (hasSoftWords.isNotEmpty && !hasContext) {
        return (allowed: false, reason: 'Возможный спам/реклама');
      }
    }

    return (allowed: true, reason: null);
  }

  // === ДЛЯ ИНТЕГРАЦИИ В ТВОЙ КОД ===
  static void integrate() {
    // Замени в isStoryValid():
    // if (!isStoryValid(content)) { ... }
    // на:
    // final moderation = ModerationEngine.moderate(content);
    // if (!moderation.allowed) {
    //   showError(moderation.reason ?? 'Текст не прошёл модерацию');
    //   return;
    // }
  }
}

// === БЫСТРАЯ ИНТЕГРАЦИЯ В ТВОЙ КОД ===
// В EditStoryScreen и CreateStoryScreen замени:
/*
if (!isStoryValid(content)) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(
        'История должна быть осмысленной и содержать ровно 100 слов',
      ),
    ),
  );
  return;
}
*/

// На:
/*
// 1. Проверка модерации
final moderation = ModerationEngine.moderate(content);
if (!moderation.allowed) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(moderation.reason ?? 'Текст не прошёл модерацию'),
    ),
  );
  return;
}

// 2. Существующая проверка на 100 слов и качество
if (!isStoryValid(content)) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(
        'История должна быть осмысленной и содержать ровно 100 слов',
      ),
    ),
  );
  return;
}
*/
