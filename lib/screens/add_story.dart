import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:readreels/services/moderationEngine.dart';
import 'package:readreels/theme.dart';
import 'package:readreels/widgets/neowidgets.dart'; // Предполагается, что здесь NeoContainer
import '../models/hashtag.dart';
import '../models/story.dart';
import '../services/story_service.dart';

enum CreationStep { selectHashtags, enterContent }

bool isStoryValid(String text) {
  print('=== DEBUG isStoryValid ===');

  final cleaned = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  final words = cleaned.split(' ');

  print('Количество слов: ${words.length}');
  print('Уникальных слов: ${words.toSet().length}');

  // --- 1. Ровно 100 слов ---
  if (words.length != 100) {
    print('❌ Провал: не 100 слов, а ${words.length}');
    return false;
  }

  // --- 2. Минимум уникальных ---
  final uniqueWords = words.toSet();
  if (uniqueWords.length < 6) {
    print('❌ Провал: уникальных слов ${uniqueWords.length} < 6');
    return false;
  }

  // --- 3. Запрет 4+ подряд ---
  int streak = 1;
  for (int i = 1; i < words.length; i++) {
    if (words[i].toLowerCase() == words[i - 1].toLowerCase()) {
      streak++;
      if (streak >= 4) {
        print('❌ Провал: слово "${words[i]}" повторяется $streak раз подряд');
        return false;
      }
    } else {
      streak = 1;
    }
  }

  // --- 4. Частотный анализ ---
  const stopWords = {
    "и",
    "но",
    "а",
    "что",
    "как",
    "в",
    "на",
    "с",
    "по",
    "к",
    "у",
    "он",
    "она",
    "они",
    "мы",
    "я",
    "ты",
    "вы",
    "его",
    "ее",
    "их",
    "это",
    "то",
    "так",
    "же",
    "ли",
    "да",
  };

  final freq = <String, int>{};
  for (final w in words) {
    final lw = w.toLowerCase();
    freq[lw] = (freq[lw] ?? 0) + 1;
  }

  for (final entry in freq.entries) {
    final word = entry.key;
    final count = entry.value;

    if (stopWords.contains(word)) continue;

    final ratio = count / 100;

    // короткие слова (<=3 буквы) чаще треш
    if (word.length <= 3 && count > 18) {
      print('❌ Провал: короткое слово "$word" встречается $count раз (>18)');
      return false;
    }

    // обычные слова — 30% лимит
    if (ratio > 0.30) {
      print('❌ Провал: слово "$word" встречается $count раз (${ratio * 100}%)');
      return false;
    }
  }

  // --- 5. Проверка слоговой структуры ---
  final avgLen =
      words.map((w) => w.length).reduce((a, b) => a + b) / words.length;
  print('Средняя длина слова: $avgLen');

  if (avgLen < 3.8) {
    print('❌ Провал: средняя длина слова $avgLen < 3.8');
    return false;
  }

  // хотя бы одно слово длиннее 7 букв
  final longWords = words.where((w) => w.length > 7).toList();
  print('Слова длиннее 7 букв: $longWords');

  if (!words.any((w) => w.length > 7)) {
    print('❌ Провал: нет слов длиннее 7 букв');
    return false;
  }

  print('✅ Все проверки пройдены');
  return true;
}

// 3. New Screen for Category Creation
class NewHashtagScreen extends StatefulWidget {
  final StoryService storyService;
  const NewHashtagScreen({super.key, required this.storyService});

  @override
  State<NewHashtagScreen> createState() => _NewHashtagScreenState();
}

class EditStoryScreen extends StatefulWidget {
  final Story story; // 🔑 Принимаем существующую историю
  // Коллбэк, который можно вызвать после успешного обновления
  final VoidCallback? onStoryUpdated;

  const EditStoryScreen({super.key, required this.story, this.onStoryUpdated});

  @override
  State<EditStoryScreen> createState() => _EditStoryScreenState();
}

class _EditStoryScreenState extends State<EditStoryScreen> {
  final StoryService _storyService = StoryService();
  // 🔑 Инициализируем контроллеры данными из существующей истории
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  // ✅ ИЗМЕНЕНИЕ: Устанавливаем начальный шаг как ввод контента
  CreationStep _currentStep = CreationStep.enterContent;
  List<Hashtag> _availableHashtags = [];
  Set<int> _selectedHashtagIds = {};
  bool _isLoading = true;

  // Переменная для отображения индикатора сохранения на кнопке
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Инициализация контроллеров значениями из виджета
    _titleController = TextEditingController(text: widget.story.title);
    _contentController = TextEditingController(text: widget.story.content);

    // Инициализация выбранных хештегов из истории
    _selectedHashtagIds = widget.story.hashtags.map((h) => h.id).toSet();

    _fetchHashtags();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  // Методы _fetchHashtags, _toggleHashtag, _navigateToNewHashtag, _goToNextStep
  // остаются такими же, как в CreateStoryScreen.

  Future<void> _fetchHashtags() async {
    try {
      final hashtags = await _storyService.getHashtags();
      setState(() {
        _availableHashtags = hashtags;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки категорий: ${e.toString()}')),
        );
      }
    }
  }

  void _toggleHashtag(int id) {
    setState(() {
      if (_selectedHashtagIds.contains(id)) {
        _selectedHashtagIds.remove(id);
      } else {
        _selectedHashtagIds.add(id);
      }
    });
  }

  Future<void> _navigateToNewHashtag() async {
    final newHashtag = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => NewHashtagScreen(storyService: _storyService),
      ),
    );

    if (newHashtag != null && newHashtag is Hashtag) {
      setState(() {
        _availableHashtags.add(newHashtag);
        _selectedHashtagIds.add(newHashtag.id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Категория "${newHashtag.name}" создана и выбрана.'),
          ),
        );
      }
    }
  }

  void _goToNextStep() {
    if (_selectedHashtagIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пожалуйста, выберите хотя бы одну категорию'),
        ),
      );
      return;
    }
    setState(() {
      _currentStep = CreationStep.enterContent;
    });
  }

  // 🔑 КЛЮЧЕВОЕ ИЗМЕНЕНИЕ: Метод обновления истории
  Future<void> _updateStory() async {
    final content = _contentController.text.trim();

    // === 1. СНАЧАЛА: Проверка на 100 слов ===
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

    // === 2. ПОТОМ: Модерация ===
    final moderation = ModerationEngine.moderate(
      content,
      _titleController.text,
    );
    if (!moderation.allowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(moderation.reason ?? 'Текст не прошёл модерацию'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _storyService.updateStory(
        storyId: widget.story.id,
        title: _titleController.text,
        content: _contentController.text,
        hashtagIds: _selectedHashtagIds.toList(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('История успешно обновлена!')),
        );
        widget.onStoryUpdated?.call();
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка обновления: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // Методы _buildHashtagGrid, _buildNewHashtagTile, _buildStoryForm
  // остаются такими же, как в CreateStoryScreen.

  Widget _buildHashtagGrid(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.secondary;

    // Вставляем кнопку "Создать новую категорию" первой в список
    final List<Widget> gridItems = [
      _buildNewHashtagTile(context, accentColor),
      ..._availableHashtags.map((hashtag) {
        final isSelected = _selectedHashtagIds.contains(hashtag.id);

        final containerColor = isSelected ? btnColorDefault : neoWhite;

        return InkWell(
          onTap: () => _toggleHashtag(hashtag.id),
          child: NeoContainer(
            color: containerColor,
            child: Center(
              child: Text(
                hashtag.name,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium!.copyWith(
                  color: isSelected ? neoWhite : Colors.black,
                ),
              ),
            ),
          ),
        );
      }),
    ];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 24.0, left: 8.0, right: 8.0),
            child: Text(
              'Шаг 1: Select category for your story',
              style: theme.textTheme.headlineMedium,
            ),
          ),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.0,
              children: gridItems,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewHashtagTile(BuildContext context, Color accentColor) {
    return InkWell(
      onTap: _navigateToNewHashtag,
      child: Container(
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, size: 50, color: accentColor),
            const SizedBox(height: 8),
            Text(
              'Создать новую',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                fontWeight: FontWeight.bold,
                color: accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryForm(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24.0,
        24.0,
        24.0,
        24.0 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          // Заголовок
          TextField(
            controller: _titleController,
            style: theme.textTheme.headlineMedium,
            decoration: InputDecoration(
              hintText: 'Заголовок истории',
              hintStyle: theme.textTheme.headlineMedium!.copyWith(
                color: theme.textTheme.headlineMedium!.color!.withOpacity(0.5),
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              fillColor: Colors.transparent,
            ),
            maxLength: 100,
          ),
          Divider(color: theme.colorScheme.onBackground.withOpacity(0.5)),
          const SizedBox(height: 20),
          // Контент истории
          TextField(
            controller: _contentController,
            style: theme.textTheme.bodyLarge!.copyWith(height: 1.5),
            decoration: InputDecoration(
              hintText: 'Начните писать свою историю здесь...',
              hintStyle: theme.textTheme.bodyLarge!.copyWith(
                color: theme.textTheme.bodyLarge!.color!.withOpacity(0.5),
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              fillColor: Colors.transparent,
            ),
            maxLines: null,
            keyboardType: TextInputType.multiline,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          // Word counter
          Text(
            'Слов: ${_contentController.text.trim().isEmpty ? 0 : _contentController.text.trim().split(RegExp(r"\s+")).length}',
            style: theme.textTheme.bodyMedium!.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool showLoading = _isLoading || _isSaving;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentStep == CreationStep.selectHashtags
              ? 'Выберите категории'
              : 'Редактирование',
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (!showLoading)
            IconButton(
              icon: Icon(
                _currentStep == CreationStep.selectHashtags
                    ? Icons.arrow_forward
                    : Icons.check,
                color: neoBlack,
              ),
              onPressed:
                  _currentStep == CreationStep.selectHashtags
                      ? _goToNextStep
                      : _updateStory,
            ),
          if (showLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body:
          showLoading && _currentStep == CreationStep.selectHashtags
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                child:
                    _currentStep == CreationStep.selectHashtags
                        ? _buildHashtagGrid(context)
                        : _buildStoryForm(context),
              ),
    );
  }
}

class _NewHashtagScreenState extends State<NewHashtagScreen> {
  final _controller = TextEditingController();
  bool _isLoading = false;

  Future<void> _createNewHashtag() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Введите название категории')),
        );
      }
      return;
    }

    // === Модерация категории ===
    final moderation = ModerationEngine.moderate(name, "");
    if (!moderation.allowed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(moderation.reason ?? 'Название не прошло модерацию'),
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final newHashtag = await widget.storyService.createHashtag(name);

      if (mounted) {
        Navigator.of(context).pop(newHashtag);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка создания: ${e.toString()}')),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Новая категория',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.check, color: neoBlack, size: 28),
              onPressed: _createNewHashtag,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Название категории',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: 'Например: "Старые Легенды"',
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _createNewHashtag(),
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 32),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}

// 4. Refactored CreateStoryScreen
class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  final StoryService _storyService = StoryService();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  CreationStep _currentStep = CreationStep.selectHashtags;

  List<Hashtag> _availableHashtags = [];
  final Set<int> _selectedHashtagIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHashtags();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _fetchHashtags() async {
    try {
      final hashtags = await _storyService.getHashtags();
      setState(() {
        _availableHashtags = hashtags;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки категорий: ${e.toString()}')),
        );
      }
    }
  }

  void _toggleHashtag(int id) {
    setState(() {
      if (_selectedHashtagIds.contains(id)) {
        _selectedHashtagIds.remove(id);
      } else {
        _selectedHashtagIds.add(id);
      }
    });
  }

  Future<void> _navigateToNewHashtag() async {
    final newHashtag = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => NewHashtagScreen(storyService: _storyService),
      ),
    );

    if (newHashtag != null && newHashtag is Hashtag) {
      setState(() {
        // Добавляем новый хештег в список доступных и сразу выбираем
        _availableHashtags.add(newHashtag);
        _selectedHashtagIds.add(newHashtag.id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Категория "${newHashtag.name}" создана и выбрана.'),
          ),
        );
      }
    }
  }

  void _goToNextStep() {
    if (_selectedHashtagIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пожалуйста, выберите хотя бы одну категорию'),
        ),
      );
      return;
    }
    setState(() {
      _currentStep = CreationStep.enterContent;
    });
  }

  Future<void> _submitStory() async {
    final content = _contentController.text.trim();

    // === 1. СНАЧАЛА: Проверка на 100 слов ===
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

    // === 2. ПОТОМ: Модерация ===
    final moderation = ModerationEngine.moderate(
      content,
      _titleController.text,
    );
    if (!moderation.allowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(moderation.reason ?? 'Текст не прошёл модерацию'),
        ),
      );
      return;
    }

    try {
      setState(() => _isLoading = true);

      await _storyService.createStory(
        title: _titleController.text,
        content: _contentController.text,
        hashtagIds: _selectedHashtagIds.toList(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('История успешно опубликована!')),
        );
        context.go('/home');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка публикации: ${e.toString()}')),
        );
      }
    }
  }

  Widget _buildHashtagGrid(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.secondary;

    // Вставляем кнопку "Создать новую категорию" первой в список
    final List<Widget> gridItems = [
      _buildNewHashtagTile(context, accentColor),
      ..._availableHashtags.map((hashtag) {
        final isSelected = _selectedHashtagIds.contains(hashtag.id);

        // 🔑 КЛЮЧЕВОЕ ИЗМЕНЕНИЕ: Установка цвета для NeoContainer
        final containerColor = isSelected ? btnColorDefault : neoWhite;

        return InkWell(
          onTap: () => _toggleHashtag(hashtag.id),
          child: NeoContainer(
            // 🔑 ПЕРЕДАЕМ ИЗМЕНЕННЫЙ ЦВЕТ
            color: containerColor,
            child: Center(
              child: Text(
                hashtag.name,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium!.copyWith(
                  // 🔑 Установка цвета текста в зависимости от фона
                  color: isSelected ? neoWhite : Colors.black,
                ),
              ),
            ),
          ),
        );
      }),
    ];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.0, // Квадратные плитки
              children: gridItems,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewHashtagTile(BuildContext context, Color accentColor) {
    return InkWell(
      onTap: _navigateToNewHashtag,
      child: Container(
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, size: 50, color: accentColor),
            const SizedBox(height: 8),
            Text(
              'Создать новую',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                fontWeight: FontWeight.bold,
                color: accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryForm(BuildContext context) {
  final theme = Theme.of(context);
  final wordCount = _contentController.text.trim().isEmpty 
      ? 0 
      : _contentController.text.trim().split(RegExp(r"\s+")).length;

  return SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      24.0,
      8.0, // Уменьшили верхний отступ, так как счетчик теперь над формой
      24.0,
      24.0 + MediaQuery.of(context).viewInsets.bottom,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: wordCount == 100 ? Colors.green : (wordCount > 100 ? Colors.red : btnColorDefault),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$wordCount / 100 слов',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                      const SizedBox(height: 10),
        // Заголовок
        TextField(
          controller: _titleController,
          style: theme.textTheme.headlineMedium,
          decoration: InputDecoration(
            hintText: 'Заголовок истории',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            fillColor: Colors.transparent,
          ),
          maxLength: 100,
          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null, // Скрываем стандартный счетчик символов
        ),
        Divider(color: theme.colorScheme.onBackground.withOpacity(0.5)),
        const SizedBox(height: 10),
        // Контент истории
        TextField(
          controller: _contentController,
          style: theme.textTheme.bodyLarge!.copyWith(height: 1.5),
          decoration: InputDecoration(
            hintText: 'Начните писать свою историю здесь...',
            border: InputBorder.none,
            
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
            fillColor: Colors.transparent,
          ),
          maxLines: null,
          keyboardType: TextInputType.multiline,
          onChanged: (_) => setState(() {}), // Обновляем состояние для счетчика наверху
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentStep == CreationStep.selectHashtags
              ? 'Выберите категории'
              : 'Новая история',
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () {
            if (_currentStep == CreationStep.enterContent) {
              setState(() {
                _currentStep = CreationStep.selectHashtags;
              });
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          if (!(_isLoading && _currentStep == CreationStep.enterContent))
            IconButton(
              icon: Icon(
                _currentStep == CreationStep.selectHashtags
                    ? Icons.arrow_forward
                    : Icons.check,
                color: neoBlack,
              ),
              onPressed:
                  _currentStep == CreationStep.selectHashtags
                      ? _goToNextStep
                      : _submitStory,
            ),
          if (_isLoading && _currentStep == CreationStep.enterContent)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body:
          _currentStep == CreationStep.selectHashtags
              ? _buildHashtagGrid(context)
              : _buildStoryForm(context),
    );
  }
}
