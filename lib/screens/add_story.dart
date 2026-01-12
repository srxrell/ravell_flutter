import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:readreels/services/moderationEngine.dart';
import 'package:readreels/theme.dart';
import 'package:readreels/widgets/neowidgets.dart'; 
import '../models/hashtag.dart';
import 'package:readreels/widgets/markdown_toolbar.dart';
import '../models/story.dart';
import '../services/story_service.dart';

enum CreationStep { selectHashtags, enterContent }

bool isStoryValid(String text) {
  final cleaned = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  final words = cleaned.split(' ');

  if (words.length <= 100) return true;

  final uniqueWords = words.toSet();
  if (uniqueWords.length < 6) return false;

  int streak = 1;
  for (int i = 1; i < words.length; i++) {
    if (words[i].toLowerCase() == words[i - 1].toLowerCase()) {
      streak++;
      if (streak >= 4) return false;
    } else {
      streak = 1;
    }
  }

  const stopWords = {
    "и","но","а","что","как","в","на","с","по","к","у","он","она","они","мы","я","ты","вы","его","ее","их","это","то","так","же","ли","да",
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
    if (word.length <= 3 && count > 18) return false;
    if (ratio > 0.30) return false;
  }

  final avgLen = words.map((w) => w.length).reduce((a, b) => a + b) / words.length;
  if (avgLen < 3.8) return false;
  if (!words.any((w) => w.length > 7)) return false;

  return true;
}

// ===================== New Hashtag Screen =====================
class NewHashtagScreen extends StatefulWidget {
  final StoryService storyService;
  const NewHashtagScreen({super.key, required this.storyService});

  @override
  State<NewHashtagScreen> createState() => _NewHashtagScreenState();
}

class _NewHashtagScreenState extends State<NewHashtagScreen> {
  final _controller = TextEditingController();
  bool _isLoading = false;

  Future<void> _createNewHashtag() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Введите название категории')));
      return;
    }

    final moderation = ModerationEngine.moderate(name, "");
    if (!moderation.allowed) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(moderation.reason ?? 'Название не прошло модерацию')));
      return;
    }

    setState(() => _isLoading = true);
    try {

      final newHashtag = await widget.storyService.createHashtag(name);
      if (mounted) Navigator.of(context).pop(newHashtag);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка создания: ${e.toString()}')));
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
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20), onPressed: () => Navigator.of(context).pop()),
        title: Text('Новая категория', style: Theme.of(context).textTheme.headlineMedium),
        actions: [
          if (!_isLoading) IconButton(icon: const Icon(Icons.check, color: neoBlack, size: 28), onPressed: _createNewHashtag),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Название категории', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 8),
            TextField(
              
              controller: _controller,
              // Устанавливаем четкую высоту строки
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: 1.5,
              ),
              strutStyle: const StrutStyle(
                height: 1.4,
                forceStrutHeight: true,
              ),
              decoration: InputDecoration(
                hintText: 'Например: "Старые Легенды"',
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
                fillColor: Colors.white,
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _createNewHashtag(),
            ),
            if (_isLoading) const Padding(padding: EdgeInsets.only(top: 32), child: Center(child: CircularProgressIndicator())),
          ],
        ),
      ),
    );
  }
}

// ===================== Edit Story Screen =====================
class EditStoryScreen extends StatefulWidget {
  final Story story;
  final VoidCallback? onStoryUpdated;

  const EditStoryScreen({super.key, required this.story, this.onStoryUpdated});

  @override
  State<EditStoryScreen> createState() => _EditStoryScreenState();
}

class _EditStoryScreenState extends State<EditStoryScreen> {
  final StoryService _storyService = StoryService();
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  CreationStep _currentStep = CreationStep.enterContent;
  List<Hashtag> _availableHashtags = [];
  Set<int> _selectedHashtagIds = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.story.title);
    _contentController = TextEditingController(text: widget.story.content);
    _selectedHashtagIds = widget.story.hashtags.map((h) => h.id).toSet();
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка загрузки категорий: ${e.toString()}')));
    }
  }

  void _toggleHashtag(int id) => setState(() {
        if (_selectedHashtagIds.contains(id)) _selectedHashtagIds.remove(id);
        else _selectedHashtagIds.add(id);
      });

  Future<void> _navigateToNewHashtag() async {
    final newHashtag = await Navigator.of(context).push(MaterialPageRoute(builder: (context) => NewHashtagScreen(storyService: _storyService)));
    if (newHashtag != null && newHashtag is Hashtag) {
      setState(() {
        _availableHashtags.add(newHashtag);
        _selectedHashtagIds.add(newHashtag.id);
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Категория "${newHashtag.name}" создана и выбрана.')));
    }
  }

  void _goToNextStep() {
    if (_selectedHashtagIds.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Пожалуйста, выберите хотя бы одну категорию')));
      return;
    }
    setState(() => _currentStep = CreationStep.enterContent);
  }

  Future<void> _updateStory() async {
    final content = _contentController.text.trim();
    if (!isStoryValid(content)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('История должна быть осмысленной и содержать ровно 100 слов')));
      return;
    }

    final moderation = ModerationEngine.moderate(content, _titleController.text);
    if (!moderation.allowed) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(moderation.reason ?? 'Текст не прошёл модерацию')));
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('История успешно обновлена!')));
        widget.onStoryUpdated?.call();
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка обновления: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildHashtagGrid(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.secondary;

    final gridItems = [
      _buildNewHashtagTile(context, accentColor),
      ..._availableHashtags.map((hashtag) {
        final isSelected = _selectedHashtagIds.contains(hashtag.id);
        return InkWell(
          onTap: () => _toggleHashtag(hashtag.id),
          child: NeoContainer(
            color: isSelected ? btnColorDefault : neoWhite,
            child: Center(
              child: Text(hashtag.name, textAlign: TextAlign.center, style: theme.textTheme.headlineMedium!.copyWith(color: isSelected ? neoWhite : Colors.black)),
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
          Expanded(child: GridView.count(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, children: gridItems)),
        ],
      ),
    );
  }

  Widget _buildNewHashtagTile(BuildContext context, Color accentColor) {
    return InkWell(
      onTap: _navigateToNewHashtag,
      child: Container(
        decoration: BoxDecoration(color: accentColor.withOpacity(0.2), borderRadius: BorderRadius.circular(16), border: Border.all(color: accentColor, width: 2)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, size: 50, color: accentColor),
            const SizedBox(height: 8),
            Text('Создать новую', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall!.copyWith(fontWeight: FontWeight.bold, color: accentColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryForm(BuildContext context) {
    final theme = Theme.of(context);
    final wordCount = _contentController.text.trim().isEmpty ? 0 : _contentController.text.trim().split(RegExp(r'\s+')).length;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          TextField(
            
            controller: _titleController,
            style: theme.textTheme.headlineMedium,
            decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 8)),
            maxLength: 100,
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
          ),
          Divider(color: theme.colorScheme.onBackground.withOpacity(0.5)),
          const SizedBox(height: 10),
          TextField(
            
            controller: _contentController,
            style: theme.textTheme.bodyLarge!.copyWith(height: 1.5),
            decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero),
            maxLines: null,
            keyboardType: TextInputType.multiline,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showLoading = _isLoading || _isSaving;

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentStep == CreationStep.selectHashtags ? 'Выберите категории' : 'Редактирование'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () {
            if (_currentStep == CreationStep.enterContent) setState(() => _currentStep = CreationStep.selectHashtags);
            else Navigator.of(context).pop();
          },
        ),
        actions: [
          if (!showLoading)
            IconButton(
              icon: Icon(_currentStep == CreationStep.selectHashtags ? Icons.arrow_forward : Icons.check, color: neoBlack),
              onPressed: _currentStep == CreationStep.selectHashtags ? _goToNextStep : _updateStory,
            ),
          if (showLoading)
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
        ],
      ),
      body: _currentStep == CreationStep.selectHashtags ? _buildHashtagGrid(context) : _buildStoryForm(context),
    );
  }
}

// ===================== Create Story Screen =====================
class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  final StoryService _storyService = StoryService();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _searchController = TextEditingController();
  CreationStep _currentStep = CreationStep.selectHashtags;
  List<Hashtag> _availableHashtags = [];
  final Set<int> _selectedHashtagIds = {};
  bool _isLoading = true;

  String _searchQuery = '';

  List<Hashtag> get _filteredHashtags {
    if (_searchQuery.isEmpty) return _availableHashtags;
    return _availableHashtags.where((h) => h.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  @override
  void initState() {
    super.initState();
    _fetchHashtags();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _searchController.dispose();
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка загрузки категорий: ${e.toString()}')));
    }
  }

  void _toggleHashtag(int id) => setState(() {
        if (_selectedHashtagIds.contains(id)) _selectedHashtagIds.remove(id);
        else _selectedHashtagIds.add(id);
      });

  Future<void> _navigateToNewHashtag() async {
    final newHashtag = await Navigator.of(context).push(MaterialPageRoute(builder: (context) => NewHashtagScreen(storyService: _storyService)));
    if (newHashtag != null && newHashtag is Hashtag) {
      setState(() {
        _availableHashtags.add(newHashtag);
        _selectedHashtagIds.add(newHashtag.id);
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Категория "${newHashtag.name}" создана и выбрана.')));
    }
  }

  void _goToNextStep() {
    if (_selectedHashtagIds.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Пожалуйста, выберите хотя бы одну категорию')));
      return;
    }
    setState(() => _currentStep = CreationStep.enterContent);
  }

  Future<void> _submitStory() async {
    final content = _contentController.text.trim();
    if (!isStoryValid(content)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('История должна быть осмысленной и содержать ровно 100 слов')));
      return;
    }

    final moderation = ModerationEngine.moderate(content, _titleController.text);
    if (!moderation.allowed) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(moderation.reason ?? 'Текст не прошёл модерацию')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const FullscreenLoading(),
  );
      await _storyService.createStory(title: _titleController.text, content: _contentController.text, hashtagIds: _selectedHashtagIds.toList());
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('История успешно опубликована!')));
        context.go('/home');
      }
    } catch (e) {
      Navigator.of(context).pop();
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка публикации: ${e.toString()}')));
    }
  }

  Widget _buildHashtagGrid(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.secondary;

    final List<Widget> gridItems = [
      _buildNewHashtagTile(context, accentColor),
      ..._filteredHashtags.map((hashtag) {
        final isSelected = _selectedHashtagIds.contains(hashtag.id);
        return InkWell(
          onTap: () => _toggleHashtag(hashtag.id),
          child: NeoContainer(
            color: isSelected ? btnColorDefault : neoWhite,
            child: Center(
              child: Text(hashtag.name, textAlign: TextAlign.center, style: theme.textTheme.headlineMedium!.copyWith(color: isSelected ? neoWhite : Colors.black)),
            ),
          ),
        );
      }),
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: TextField(
              
              
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Поиск категории',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
              onChanged: (value) => setState(() => _searchQuery = value.trim()),
            ),
          ),
          Expanded(child: GridView.count(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, children: gridItems)),
        ],
      ),
    );
  }

  Widget _buildNewHashtagTile(BuildContext context, Color accentColor) {
    return InkWell(
      onTap: _navigateToNewHashtag,
      child: Container(
        decoration: BoxDecoration(color: accentColor.withOpacity(0.2), borderRadius: BorderRadius.circular(16), border: Border.all(color: accentColor, width: 2)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.add_circle_outline, size: 50, color: accentColor),
          const SizedBox(height: 8),
          Text('Создать новую', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall!.copyWith(fontWeight: FontWeight.bold, color: accentColor)),
        ]),
      ),
    );
  }

  Widget _buildStoryForm(BuildContext context) {
    final theme = Theme.of(context);
    final wordCount = _contentController.text.trim().isEmpty ? 0 : _contentController.text.trim().split(RegExp(r'\s+')).length;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          TextField(
            
            controller: _titleController,
           strutStyle: StrutStyle(
    forceStrutHeight: true,
    height: 1.5, // Совпадает с высотой в TextStyle
    fontSize: theme.textTheme.headlineMedium?.fontSize,
  ),
  style: theme.textTheme.headlineMedium?.copyWith(
    height: 1.5, // Межстрочный интервал
  ),
            textCapitalization: TextCapitalization.sentences, // 🟢 AUTO-CAPS
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(vertical: 20),
              hintText: 'Заголовок истории',
              hintStyle: theme.textTheme.headlineMedium!.copyWith(
                color: theme.textTheme.headlineMedium!.color!.withOpacity(0.5),
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              isDense: false,
              fillColor: Colors.transparent,
            ),
            maxLength: 100,
             buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
          ),
          Divider(color: theme.colorScheme.onBackground.withOpacity(0.5)),
          const SizedBox(height: 10),
          // Контент истории
          TextField(
            
            controller: _contentController,
            strutStyle: StrutStyle(
    forceStrutHeight: true,
    height: 1.5, // Совпадает с высотой в TextStyle
    fontSize: theme.textTheme.bodyLarge?.fontSize,
  ),
  style: theme.textTheme.bodyLarge?.copyWith(
    height: 1.5, // Межстрочный интервал
  ),
            textCapitalization: TextCapitalization.sentences, // 🟢 AUTO-CAPS
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(vertical: 20),
              hintText: 'Начните писать свою историю здесь...',
              hintStyle: theme.textTheme.bodyLarge!.copyWith(
                color: theme.textTheme.bodyLarge!.color!.withOpacity(0.5),
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              isDense: false,
              fillColor: Colors.transparent,
            ),
            maxLines: null,
            onChanged: (_) => setState(() {}),
            minLines: 5,
            keyboardType: TextInputType.multiline,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: _currentStep == CreationStep.enterContent
          ? MarkdownToolbar(controller: _contentController)
          : null,
      appBar: AppBar(
        title: Text(_currentStep == CreationStep.selectHashtags ? 'Выберите категории' : 'Новая история'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () {
            if (_currentStep == CreationStep.enterContent) setState(() => _currentStep = CreationStep.selectHashtags);
            else Navigator.of(context).pop();
          },
        ),
        actions: [
          if (!(_isLoading && _currentStep == CreationStep.enterContent))
            IconButton(
              icon: Icon(_currentStep == CreationStep.selectHashtags ? Icons.arrow_forward : Icons.check, color: neoBlack),
              onPressed: _currentStep == CreationStep.selectHashtags ? _goToNextStep : _submitStory,
            ),
          if (_isLoading && _currentStep == CreationStep.enterContent)
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
        ],
      ),
      body: _currentStep == CreationStep.selectHashtags ? _buildHashtagGrid(context) : _buildStoryForm(context),
    );
  }
}

class FullscreenLoading extends StatelessWidget {
  final String message;
  const FullscreenLoading({super.key, this.message = 'Публикация...'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.5),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}