import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:readreels/models/story.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import '../widgets/bottom_nav_bar_liquid.dart';
import 'package:readreels/screens/search_feed.dart';

// ------------------------------------------------------------------
// 1. DEBOUNCER CLASS
// Используется для задержки API-запросов во время печати.
// ------------------------------------------------------------------
class Debouncer {
  final int milliseconds;
  VoidCallback? action;
  Timer? _timer;

  Debouncer({this.milliseconds = 500});

  void run(VoidCallback action) {
    if (_timer != null) {
      _timer!.cancel();
    }
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  void dispose() {
    _timer?.cancel();
  }
}
// ------------------------------------------------------------------

class SearchStory extends StatefulWidget {
  const SearchStory({super.key});

  @override
  State<SearchStory> createState() => _SearchStoryState();
}

class _SearchStoryState extends State<SearchStory> {
  final TextEditingController textController = TextEditingController();
  final String apiSearchUrl = "http://192.168.1.104:8080/stories/";

  // --- Состояние и Debouncer ---
  final Debouncer _debouncer = Debouncer(milliseconds: 500);
  List<Story> searchResults = [];
  bool isLoading = false;
  List<String> searchHistory = [];
  static const String _historyKey = 'searchHistory';
  // -----------------------------

  @override
  void initState() {
    super.initState();
    _loadHistory();
    // Начинаем слушать ввод для автоматического поиска с задержкой
    textController.addListener(_searchOnType);
  }

  @override
  void dispose() {
    textController.removeListener(_searchOnType);
    _debouncer.dispose(); // Обязательно очищаем Debouncer
    textController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // 2. ЛОГИКА ПОИСКА ПРИ ПЕЧАТИ (DEBOUNCE)
  // ------------------------------------------------------------------
  void _searchOnType() {
    // Немедленно очищаем результаты, если поле ввода пустое
    if (textController.text.trim().isEmpty) {
      setState(() {
        searchResults = [];
        isLoading = false;
      });
      return;
    }

    // Запускаем Debouncer. Он вызовет search() через 500мс, если не будет нового ввода.
    _debouncer.run(() {
      // isAutoSearch = true, чтобы не сохранять историю поиска при каждой букве.
      search(isAutoSearch: true);
    });
  }

  // ------------------------------------------------------------------
  // 3. ЛОГИКА ИСТОРИИ И ВЫБОР ПОДСКАЗКИ
  // ------------------------------------------------------------------

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      searchHistory = prefs.getStringList(_historyKey) ?? [];
    });
  }

  // Сохраняем историю только при явном нажатии (Enter/кнопка)
  Future<void> _saveHistory(String query) async {
    query = query.trim();
    if (query.isEmpty) return;
    searchHistory.remove(query);
    searchHistory.insert(0, query);
    if (searchHistory.length > 10) {
      searchHistory = searchHistory.sublist(0, 10);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_historyKey, searchHistory);
    // Обновляем UI, чтобы показать новую историю, если поле ввода пустое
    setState(() {});
  }

  Future<void> _deleteHistoryItem(String item) async {
    setState(() {
      searchHistory.remove(item);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_historyKey, searchHistory);
  }

  void _selectSuggestion(String suggestion) {
    // 1. Устанавливаем текст и ставим курсор в конец
    textController.text = suggestion;
    textController.selection = TextSelection.fromPosition(
      TextPosition(offset: textController.text.length),
    );
    // 2. Запускаем поиск (явный поиск, сохраняем в историю)
    search(isAutoSearch: false);
  }

  // ------------------------------------------------------------------
  // 4. ОСНОВНАЯ ФУНКЦИЯ ПОИСКА (API)
  // ------------------------------------------------------------------
  void search({bool isAutoSearch = false}) async {
    final query = textController.text.trim();
    if (query.isEmpty) {
      setState(() {
        searchResults = [];
        isLoading = false;
      });
      return;
    }

    // Сохраняем запрос в историю только при явном поиске
    if (!isAutoSearch) {
      await _saveHistory(query);
    }

    setState(() {
      isLoading = true;
      searchResults = [];
    });

    try {
      final response = await http.get(
        Uri.parse("$apiSearchUrl?searchTerm=$query"),
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        final stories = jsonList.map((json) => Story.fromJson(json)).toList();

        // Проверяем, что пользователь не успел очистить поле ввода, пока мы ждали ответа
        if (textController.text.trim() == query) {
          setState(() {
            searchResults = stories;
          });
        }
      } else {
        print('Server error: ${response.statusCode}');
        if (textController.text.trim() == query) {
          setState(() {
            searchResults = [];
          });
        }
      }
    } catch (e) {
      print('Network error: $e');
      if (textController.text.trim() == query) {
        setState(() {
          searchResults = [];
        });
      }
    } finally {
      if (textController.text.trim() == query) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ------------------------------------------------------------------
  // 5. ВСПОМОГАТЕЛЬНЫЙ МЕТОД
  // ------------------------------------------------------------------
  String _getFirstSentence(String content) {
    final regex = RegExp(r'^([^.?!]*[.?!])');
    final cleanedContent = content.replaceAll(RegExp(r'[\r\n]'), ' ').trim();
    final match = regex.firstMatch(cleanedContent);

    if (match != null) {
      return match.group(0)!.trim();
    }
    return '${cleanedContent.substring(0, cleanedContent.length < 100 ? cleanedContent.length : 100)}...';
  }

  // ------------------------------------------------------------------
  // 6. UI И ОТОБРАЖЕНИЕ
  // ------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final bool isSearchActive = textController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 130,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: TextField(
          controller: textController,
          // Явный поиск (isAutoSearch: false)
          onSubmitted: (_) => search(isAutoSearch: false),
          decoration: InputDecoration(
            hintText: "Search stories",
            border: InputBorder.none,
            suffixIcon: IconButton(
              icon: const Icon(Icons.search),
              // Явный поиск (isAutoSearch: false)
              onPressed: () => search(isAutoSearch: false),
            ),
          ),
        ),
      ),
      body: Builder(
        builder: (context) {
          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (isSearchActive) {
            // Если текст введен, показываем результаты API или сообщение об ошибке
            if (searchResults.isEmpty) {
              return const Center(child: Text("Истории не найдены."));
            }

            // --- РЕЗУЛЬТАТЫ ПОИСКА (из API) ---
            return ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: searchResults.length,
              itemBuilder: (context, index) {
                final story = searchResults[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(
                      story.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          _getFirstSentence(story.content),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (context) => SearchFeed(
                                stories: searchResults,
                                initialIndex: index,
                              ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          } else {
            // --- ИСТОРИЯ ПОИСКА (когда поле ввода пустое) ---
            return ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: searchHistory.length,
              itemBuilder: (context, index) {
                final suggestion = searchHistory[index];

                return ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(suggestion),
                  onTap: () => _selectSuggestion(suggestion),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => _deleteHistoryItem(suggestion),
                  ),
                );
              },
            );
          }
        },
      ),
      bottomNavigationBar: const PERSISTENT_BOTTOM_NAV_BAR_LIQUID_GLASS(),
    );
  }
}
