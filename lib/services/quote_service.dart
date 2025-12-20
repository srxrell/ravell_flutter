import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class QuoteService {
  static final _quotes = [
    "Every story you read leaves a little mark on your mind.",
    "A single drabble can spark an entire universe of thought.",
    "Reading is the brain’s way of traveling without moving.",
    "Responding with a drabble is thinking in miniature.",
    "Small stories, big ideas.",
    "Each drabble is a conversation with imagination.",
    "Your mind grows with every sentence you read.",
    "A short reply can hold a long reflection.",
    "Every page you turn is a step in a personal journey.",
    "The tiniest stories sometimes leave the deepest impressions.",
    "One drabble can change how you see an entire narrative.",
    "Reading daily keeps the imagination awake.",
    "Stories are tiny windows into infinite minds.",
    "The brain remembers what it reads and feels.",
    "Even a few lines can carry a world of meaning.",
    "Replying with a drabble is a miniature art.",
    "Every story adds a brushstroke to your inner canvas.",
    "A single paragraph can linger in thought for days.",
    "Short stories are like whispered secrets to your mind.",
    "A drabble is a universe in 100 words or less.",
    "Reading is the mind’s way of collecting treasures.",
    "Every reply is a new thread in the web of imagination.",
    "Tiny stories teach big lessons.",
    "Your imagination grows with each drabble you read.",
    "Even a short story can leave a lasting impression.",
    "Stories are conversations across time and minds.",
    "A well-crafted drabble is sharper than a long essay.",
    "Reading daily is mental stretching.",
    "Drabbles are like sparks that ignite bigger ideas.",
    "Your mind becomes a library of tiny wonders.",
    "Every word you read adds weight to your thought.",
    "The smallest story can carry the largest feeling.",
    "Drabbles are mini-bridges between readers and writers.",
    "Short stories whisper truths that essays shout.",
    "Every reading streak is a streak of growth.",
    "A tiny story can open doors in your mind.",
    "Even brief words can shape lasting impressions.",
    "Stories are fuel for creative engines.",
    "Replying concisely is thinking with precision.",
    "A daily drabble is a daily meditation.",
    "Tiny tales can leave huge marks on the heart.",
    "Reading is like walking through countless minds.",
    "Each drabble is a seed of imagination.",
    "Your brain blooms with every story read.",
    "Even a single paragraph can inspire reflection.",
    "Short replies hold the weight of full conversations.",
    "Daily stories are a workout for the mind.",
    "The best ideas often come from tiny sparks.",
    "A drabble is a microcosm of thought.",
    "Reading and replying is a dance of minds.",
    "Short tales, long impact.",
    "Every drabble adds a drop to the ocean of imagination.",
  ];

  static Future<String> getQuoteOfTheDay() async {
    final prefs = await SharedPreferences.getInstance();

    final today = DateTime.now();
    final todayKey = "${today.year}-${today.month}-${today.day}";

    final storedKey = prefs.getString('quote_date');
    final storedQuote = prefs.getString('quote_text');

    if (storedKey == todayKey && storedQuote != null) {
      // Уже есть цитата на сегодня
      return storedQuote;
    }

    // Выбираем новую цитату
    final random = Random();
    final newQuote = _quotes[random.nextInt(_quotes.length)];

    await prefs.setString('quote_date', todayKey);
    await prefs.setString('quote_text', newQuote);

    return newQuote;
  }
}
