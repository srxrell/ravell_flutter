class ModerationEngine {
  // === УНИВЕРСАЛЬНАЯ ПРОВЕРКА ВСЕГО ТЕКСТА (заголовок + контент) ===
  static ({bool allowed, String? reason}) moderate(
    String title,
    String content,
  ) {
    final fullText = '$title $content'.toLowerCase();

    print('🔍 МОДЕРАЦИЯ: $title...');

    // 1. ЖЁСТКИЙ БАН (нельзя ни в каком контексте)
    final hardPatterns = [
      r'нарко[тик]',
      r'героин',
      r'кокаин',
      r'суицид',
      r'убийств',
      r'террор',
      r'взрывчат',
      r'детс[кх]',
      r'педо',
      r'инцест',
      r'ор[уy]жие',
    ];

    for (final pattern in hardPatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(fullText)) {
        print('❌ Жёсткий бан по паттерну: $pattern');
        return (allowed: false, reason: 'Запрещённый контент');
      }
    }

    // 2. ССЫЛКИ (даже в заголовке)
    final urlPatterns = [
      r'https?://',
      r'www\.',
      r'\.(ru|com|net|org|info)',
      r't\.me/',
      r'@[\w_]+',
      r'bit\.ly/',
      r'vk\.cc/',
    ];

    for (final pattern in urlPatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(fullText)) {
        // Но если это образовательный контекст (предупреждение о мошенниках)
        if (!_hasEducationalContext(fullText)) {
          print('❌ Ссылки без контекста: $pattern');
          return (allowed: false, reason: 'Ссылки запрещены');
        }
      }
    }

    // 3. МЯГКИЕ СЛОВА (требуют контекста)
    final softWords = [
      'развели',
      'обманули',
      'купить',
      'продать',
      'заработок',
      'деньги',
      'переведи',
      'отправь',
      'крипт',
      'биткоин',
      'казино',
      'ставк',
      'лотере',
      'выигр',
    ];

    final hasSoftWords = softWords.any((word) => fullText.contains(word));
    final hasContext = _hasEducationalContext(fullText);

    if (hasSoftWords && !hasContext) {
      print('❌ Мягкие слова без контекста');
      return (allowed: false, reason: 'Возможный спам/реклама');
    }

    print('✅ Пропущено');
    return (allowed: true, reason: null);
  }

  // === КОНТЕКСТ ПРЕДУПРЕЖДЕНИЯ (чтобы пропустить истории про мошенников) ===
  static bool _hasEducationalContext(String text) {
    final contextPatterns = [
      r'не\s+(делай|повторяй|верь|попадайся|доверяй)',
      r'осторожно',
      r'предупреждаю',
      r'будьте\s+бдительны',
      r'мошенничеств',
      r'афер',
      r'обман',
      r'развод',
      r'как\s+не\s+попасть',
      r'как\s+защитить',
    ];

    return contextPatterns.any(
      (pattern) => RegExp(pattern, caseSensitive: false).hasMatch(text),
    );
  }
}
