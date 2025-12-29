import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:readreels/models/story.dart';
import 'package:readreels/models/hashtag.dart';
import 'package:readreels/screens/story_detail.dart';
import 'package:readreels/services/story_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:go_router/go_router.dart'; // Added this line

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
  final StoryService _storyService = StoryService();

  final Debouncer _debouncer = Debouncer(milliseconds: 500);
  List<Story> searchResults = [];
  List<Hashtag> categories = [];
  List<Hashtag> _visibleCategories = [];
  bool isLoading = false;
  bool isLoadingCategories = false;
  List<String> searchHistory = [];
  static const String _historyKey = 'searchHistory';
  bool _showAdvancedSearch = false;
  Set<int> _selectedCategoryIds = {};
  String _dateFilter = 'any'; // any, day, week, month

  // Для отслеживания текущих запросов
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadCategories();
    textController.addListener(_searchOnType);
  }

  Future<void> _loadCategories() async {
    setState(() {
      isLoadingCategories = true;
    });
    try {
      final hashtags = await _storyService.getHashtags();
      if (mounted) {
        setState(() {
          categories = hashtags;
          // По умолчанию показываем максимум 30 категорий (сетка 3x10)
          _visibleCategories =
              categories.length > 30 ? categories.take(30).toList() : categories;
          isLoadingCategories = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingCategories = false;
        });
      }
    }
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
    if (query.isEmpty && _selectedCategoryIds.isEmpty) {
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
      // Строим URL с учетом категорий
      String url = "$apiSearchUrl?";
      if (query.isNotEmpty) {
        url += "search=$query";
      }
      
      // Если выбраны категории, ищем по ним
      if (_selectedCategoryIds.isNotEmpty) {
        if (query.isNotEmpty) url += "&";
        for (int i = 0; i < _selectedCategoryIds.length; i++) {
          if (i > 0) url += "&";
          url += "hashtag_id=${_selectedCategoryIds.elementAt(i)}";
        }
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        final List<dynamic> jsonList = jsonResponse['stories'] ?? [];
        List<Story> stories =
            jsonList.map((json) => Story.fromJson(json)).toList();

        // Дополнительный фильтр по дате создания (клиентский, без изменения API)
        if (_dateFilter != 'any') {
          final now = DateTime.now();
          DateTime threshold;
          switch (_dateFilter) {
            case 'day':
              threshold = now.subtract(const Duration(days: 1));
              break;
            case 'week':
              threshold = now.subtract(const Duration(days: 7));
              break;
            case 'month':
              threshold = now.subtract(const Duration(days: 30));
              break;
            default:
              threshold = DateTime.fromMillisecondsSinceEpoch(0);
          }
          stories = stories
              .where((s) => s.createdAt.isAfter(threshold))
              .toList();
        }

        // Проверяем, что запрос все еще актуален
        if (textController.text.trim() == query) {
          setState(() {
            searchResults = stories;
            isLoading = false;
          });

          // 🟢 КЛЮЧЕВОЕ ИЗМЕНЕНИЕ: Сохраняем в историю если есть результаты
          if (stories.isNotEmpty && query.isNotEmpty) {
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
        automaticallyImplyLeading: false,

        toolbarHeight: 130,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: TextField(
          controller: textController,
          autofocus: true, // Фокус на поле поиска при открытии
          decoration: InputDecoration(
            hintText: "Search stories, categories",
            border: InputBorder.none,
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Кнопка расширенного поиска
                IconButton(
                  icon: Icon(_showAdvancedSearch ? Icons.filter_list : Icons.tune),
                  onPressed: () {
                    setState(() {
                      _showAdvancedSearch = !_showAdvancedSearch;
                    });
                  },
                ),
                // Кнопка очистки
                if (isSearchActive)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      textController.clear();
                      setState(() {
                        searchResults = [];
                        _selectedCategoryIds.clear();
                        _visibleCategories =
                            categories.length > 10
                                ? categories.take(10).toList()
                                : categories;
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
      body: Column(
        children: [
          if (_showAdvancedSearch) _buildAdvancedFilters(),
          Expanded(child: _buildBody()),
        ],
      ),
      bottomNavigationBar: PERSISTENT_BOTTOM_NAV_BAR_LIQUID_GLASS(
        currentRoute: GoRouterState.of(context).uri.toString(),
      ),
    );
  }

  Widget _buildAdvancedFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок и кнопка "Все категории"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Категории',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              if (categories.length > 10)
                TextButton(
                  onPressed: _openAllCategoriesScreen,
                  child: const Text('Все категории'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (isLoadingCategories)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (categories.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Категории не найдены',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            Builder(
              builder: (context) {
                // Формируем "уменьшающуюся" колонку: 4, 3, 2 чипа в строке
                final List<int> rowPattern = [4, 3, 2];
                final List<Widget> rows = [];
                int index = 0;

                for (final count in rowPattern) {
                  if (index >= _visibleCategories.length) break;
                  final int end =
                      (index + count) > _visibleCategories.length
                          ? _visibleCategories.length
                          : index + count;

                  rows.add(
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: _visibleCategories
                            .sublist(index, end)
                            .map((cat) {
                          final isSelected =
                              _selectedCategoryIds.contains(cat.id);
                          return FilterChip(
                            visualDensity: VisualDensity.compact,
                            label: Text(
                              cat.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedCategoryIds.add(cat.id);
                                } else {
                                  _selectedCategoryIds.remove(cat.id);
                                }
                                // Автоматически выполняем поиск при изменении категорий
                                _performSearch(
                                  textController.text.trim(),
                                );
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  );

                  index = end;
                }

                // Если остались ещё категории за пределами видимых,
                // показываем строку "Ещё (+N категорий)"
                final int remaining = categories.length - _visibleCategories.length;
                if (remaining > 0) {
                  rows.add(
                    TextButton(
                      onPressed: _openAllCategoriesScreen,
                      child: Text('Ещё (+$remaining категорий)'),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: rows,
                );
              },
            ),
          if (_selectedCategoryIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Text('Выбрано категорий: '),
                  Text(
                    _selectedCategoryIds.length.toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedCategoryIds.clear();
                        _performSearch(textController.text.trim());
                      });
                    },
                    child: const Text('Очистить'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          // Фильтр по дате создания
          const Text(
            'Дата создания',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('За всё время'),
                selected: _dateFilter == 'any',
                onSelected: (_) {
                  setState(() {
                    _dateFilter = 'any';
                    _performSearch(textController.text.trim());
                  });
                },
              ),
              ChoiceChip(
                label: const Text('Сегодня'),
                selected: _dateFilter == 'day',
                onSelected: (_) {
                  setState(() {
                    _dateFilter = 'day';
                    _performSearch(textController.text.trim());
                  });
                },
              ),
              ChoiceChip(
                label: const Text('За неделю'),
                selected: _dateFilter == 'week',
                onSelected: (_) {
                  setState(() {
                    _dateFilter = 'week';
                    _performSearch(textController.text.trim());
                  });
                },
              ),
              ChoiceChip(
                label: const Text('За месяц'),
                selected: _dateFilter == 'month',
                onSelected: (_) {
                  setState(() {
                    _dateFilter = 'month';
                    _performSearch(textController.text.trim());
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openAllCategoriesScreen() async {
    final updatedSelected = await Navigator.of(context).push<Set<int>>(
      MaterialPageRoute(
        builder: (context) => _AllCategoriesScreen(
          categories: categories,
          initiallySelected: _selectedCategoryIds,
        ),
      ),
    );

    if (updatedSelected != null) {
      setState(() {
        _selectedCategoryIds = updatedSelected;
      });
      _performSearch(textController.text.trim());
    }
  }

  Widget _buildStoriesResults() {
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
                  children: story.hashtags.take(3).map((hashtag) {
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
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => StoryDetailPage(
                    story: story,
                    fromProfile: false,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPeopleResults() {
    // Собираем уникальных авторов из найденных историй
    final Map<int, _SearchPerson> people = {};
    for (final story in searchResults) {
      final userId = story.userId;
      if (userId == 0) continue;

      if (!people.containsKey(userId)) {
        people[userId] = _SearchPerson(
          id: userId,
          name: story.resolvedUsername,
          avatarUrl: story.resolvedAvatarUrl,
        );
      }
    }

    final peopleList = people.values.toList();

    if (peopleList.isEmpty) {
      return const Center(
        child: Text(
          'Авторы не найдены',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: peopleList.length,
      itemBuilder: (context, index) {
        final person = peopleList[index];
        return ListTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[200],
              border: Border.all(color: Colors.black, width: 1),
            ),
            child: person.avatarUrl != null
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: person.avatarUrl!,
                      fit: BoxFit.cover,
                      httpHeaders: const {
                        'User-Agent': 'FlutterApp/1.0',
                      },
                      placeholder: (context, url) => const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) => Center(
                        child: Text(
                          person.name.isNotEmpty
                              ? person.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      person.name.isNotEmpty
                          ? person.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
          title: Text(person.name),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            context.push('/profile/${person.id}');
          },
        );
      },
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

    final hasQuery = textController.text.trim().isNotEmpty;

    if (hasQuery) {
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

      // Экран результатов с таббаром "Истории" / "Люди"
      return DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey,
              tabs: [
                Tab(text: 'Истории'),
                Tab(text: 'Люди'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildStoriesResults(),
                  _buildPeopleResults(),
                ],
              ),
            ),
          ],
        ),
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

class _AllCategoriesScreen extends StatefulWidget {
  final List<Hashtag> categories;
  final Set<int> initiallySelected;

  const _AllCategoriesScreen({
    super.key,
    required this.categories,
    required this.initiallySelected,
  });

  @override
  State<_AllCategoriesScreen> createState() => _AllCategoriesScreenState();
}

class _AllCategoriesScreenState extends State<_AllCategoriesScreen> {
  late Set<int> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = Set<int>.from(widget.initiallySelected);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Все категории'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(_selectedIds);
            },
            child: const Text(
              'Готово',
              style: TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: widget.categories.map((cat) {
            final isSelected = _selectedIds.contains(cat.id);
            return FilterChip(
              label: Text(
                cat.name,
                overflow: TextOverflow.ellipsis,
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedIds.add(cat.id);
                  } else {
                    _selectedIds.remove(cat.id);
                  }
                });
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _SearchPerson {
  final int id;
  final String name;
  final String? avatarUrl;

  _SearchPerson({
    required this.id,
    required this.name,
    required this.avatarUrl,
  });
}
