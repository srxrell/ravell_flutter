import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:readreels/models/story.dart';
import 'package:readreels/screens/story_detail.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import '../widgets/bottom_nav_bar_liquid.dart';

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

class SearchStory extends StatefulWidget {
  const SearchStory({super.key});

  @override
  State<SearchStory> createState() => _SearchStoryState();
}

class _SearchStoryState extends State<SearchStory> {
  final TextEditingController textController = TextEditingController();
  final String apiSearchUrl = "https://ravell-backend-1.onrender.com/stories/";

  final Debouncer _debouncer = Debouncer(milliseconds: 500);
  List<Story> searchResults = [];
  bool isLoading = false;
  List<String> searchHistory = [];
  static const String _historyKey = 'searchHistory';

  // Для отслеживания текущих запросов
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    _loadHistory();
    textController.addListener(_searchOnType);
  }

  @override
  void dispose() {
    textController.removeListener(_searchOnType);
    _debouncer.dispose();
    textController.dispose();
    super.dispose();
  }

  void _searchOnType() {
    final query = textController.text.trim();
    _currentQuery = query;

    if (query.isEmpty) {
      setState(() {
        searchResults = [];
        isLoading = false;
      });
      return;
    }

    _debouncer.run(() {
      _performSearch(query, isAutoSearch: true);
    });
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      searchHistory = prefs.getStringList(_historyKey) ?? [];
    });
  }

  // 🟢 ИЗМЕНЕНИЕ: Сохраняем запрос если есть результаты
  Future<void> _saveHistoryIfNeeded(String query, List<Story> results) async {
    query = query.trim();
    if (query.isEmpty || results.isEmpty) return;

    // Проверяем, есть ли уже такой запрос в истории
    if (searchHistory.contains(query)) {
      // Если есть, перемещаем его в начало
      searchHistory.remove(query);
      searchHistory.insert(0, query);
    } else {
      // Если нет, добавляем новый
      searchHistory.insert(0, query);
      if (searchHistory.length > 10) {
        searchHistory = searchHistory.sublist(0, 10);
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_historyKey, searchHistory);

    // Обновляем UI для показа обновленной истории
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _deleteHistoryItem(String item) async {
    setState(() {
      searchHistory.remove(item);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_historyKey, searchHistory);
  }

  void _selectSuggestion(String suggestion) {
    textController.text = suggestion;
    textController.selection = TextSelection.fromPosition(
      TextPosition(offset: textController.text.length),
    );
    _performSearch(suggestion, isAutoSearch: false);
  }

  // 🟢 ИЗМЕНЕНИЕ: Разделили логику выполнения поиска
  Future<void> _performSearch(String query, {bool isAutoSearch = false}) async {
    if (query.isEmpty) {
      setState(() {
        searchResults = [];
        isLoading = false;
      });
      return;
    }

    setState(() {
      isLoading = true;
      searchResults = [];
    });

    try {
      final response = await http.get(Uri.parse("$apiSearchUrl?search=$query"));

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        final List<dynamic> jsonList = jsonResponse['stories'] ?? [];
        final stories = jsonList.map((json) => Story.fromJson(json)).toList();

        // Проверяем, что запрос все еще актуален
        if (textController.text.trim() == query) {
          setState(() {
            searchResults = stories;
            isLoading = false;
          });

          // 🟢 КЛЮЧЕВОЕ ИЗМЕНЕНИЕ: Сохраняем в историю если есть результаты
          if (stories.isNotEmpty) {
            await _saveHistoryIfNeeded(query, stories);
          }
        }
      } else {
        print('Server error: ${response.statusCode}');
        if (textController.text.trim() == query) {
          setState(() {
            searchResults = [];
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Network error: $e');
      if (textController.text.trim() == query) {
        setState(() {
          searchResults = [];
          isLoading = false;
        });
      }
    }
  }

  // Явный поиск по нажатию Enter или кнопки
  void search() {
    final query = textController.text.trim();
    _performSearch(query, isAutoSearch: false);
  }

  String _getFirstSentence(String content) {
    final regex = RegExp(r'^([^.?!]*[.?!])');
    final cleanedContent = content.replaceAll(RegExp(r'[\r\n]'), ' ').trim();
    final match = regex.firstMatch(cleanedContent);

    if (match != null) {
      return match.group(0)!.trim();
    }
    return '${cleanedContent.substring(0, cleanedContent.length < 100 ? cleanedContent.length : 100)}...';
  }

  @override
  Widget build(BuildContext context) {
    final bool isSearchActive = textController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 130,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: TextField(
          controller: textController,
          autofocus: true, // Фокус на поле поиска при открытии
          decoration: InputDecoration(
            hintText: "Search stories",
            border: InputBorder.none,
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Кнопка очистки
                if (isSearchActive)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      textController.clear();
                      setState(() {
                        searchResults = [];
                      });
                    },
                  ),
                // Кнопка поиска
                IconButton(icon: const Icon(Icons.search), onPressed: search),
              ],
            ),
          ),
          // Вызываем поиск при нажатии Enter
          onSubmitted: (_) => search(),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: const PERSISTENT_BOTTOM_NAV_BAR_LIQUID_GLASS(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Ищем истории...'),
          ],
        ),
      );
    }

    if (textController.text.trim().isNotEmpty) {
      if (searchResults.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Ничего не найдено для "${textController.text}"',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              const Text(
                'Попробуйте другие ключевые слова',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: searchResults.length,
        itemBuilder: (context, index) {
          final story = searchResults[index];
          return Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
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
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    children:
                        story.hashtags.take(3).map((hashtag) {
                          return Chip(
                            label: Text(
                              '#${hashtag.name}',
                              style: const TextStyle(fontSize: 10),
                            ),
                            backgroundColor: Colors.grey[200],
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                  ),
                ],
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              // В SearchStory в методе поиска
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (context) => StoryDetailPage(
                          story: story,
                          fromProfile:
                              false, // 🟢 Не из профиля - онлайн данные
                        ),
                  ),
                );
              },
            ),
          );
        },
      );
    } else {
      // Показываем историю поиска
      if (searchHistory.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.history, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'История поиска пуста',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              const Text(
                'Начните вводить запрос для поиска историй',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'История поиска',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: searchHistory.length,
              itemBuilder: (context, index) {
                final suggestion = searchHistory[index];
                return ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(suggestion),
                  onTap: () => _selectSuggestion(suggestion),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => _deleteHistoryItem(suggestion),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }
  }
}
