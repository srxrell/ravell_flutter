import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExpandableStoryContent extends StatefulWidget {
  final String content;

  const ExpandableStoryContent({super.key, required this.content});

  @override
  State<ExpandableStoryContent> createState() => _ExpandableStoryContentState();
}

class _ExpandableStoryContentState extends State<ExpandableStoryContent> {
  bool _isExpanded = false;
  bool _needsExpansion = false;
  double _fontScale = 1.0;

  @override
  void initState() {
    super.initState();
    _loadFontSettings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfNeedsExpansion();
    });
  }

  Future<void> _loadFontSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _fontScale = prefs.getDouble('story_font_scale') ?? 1.0;
      });
    }
  }

  // ✅ ИСПРАВЛЕНИЕ 1: Пересчет состояния при смене контента
  @override
  void didUpdateWidget(covariant ExpandableStoryContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) {
      // Сбрасываем состояние развертывания при смене истории
      _isExpanded = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkIfNeedsExpansion();
      });
    }
  }

  void _checkIfNeedsExpansion() {
    if (!mounted) return;
    
    // Простая проверка: если текст больше 200 символов, вероятно нужна кнопка
    // Более точная проверка будет в LayoutBuilder
    if (widget.content.length > 200) {
      if (mounted) {
        setState(() {
          _needsExpansion = true;
        });
      }
    }
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Если текст короткий, показываем полностью
    if (!_needsExpansion || _isExpanded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.content,
            style: TextStyle(
              fontSize: 16 * _fontScale,
              color: Colors.black,
              height: 1.5,
            ),
          ),
          if (_needsExpansion && _isExpanded)
            GestureDetector(
              onTap: _toggleExpanded,
              child: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  children: [
                    Text(
                      'Свернуть',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 16 * _fontScale,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_drop_up,
                      color: Colors.blue,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    }

    // Показываем превью с кнопкой "Читать далее"
    return LayoutBuilder(
      builder: (context, constraints) {
        // Используем TextPainter для точного измерения
        final textPainter = TextPainter(
          text: TextSpan(
            text: widget.content,
            style: TextStyle(fontSize: 16 * _fontScale),
          ),
          maxLines: 5,
          textDirection: TextDirection.ltr,
        );
        
        textPainter.layout(maxWidth: constraints.maxWidth);
        
        // Находим позицию, где заканчивается 5-я строка
        final position = textPainter.getPositionForOffset(
          Offset(constraints.maxWidth, textPainter.height),
        );
        
        final previewText = widget.content.substring(
          0,
          position.offset.clamp(0, widget.content.length),
        );
        
        return GestureDetector(
          onTap: _toggleExpanded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                previewText,
                style: TextStyle(
                  fontSize: 16 * _fontScale,
                  color: Colors.black,
                  height: 1.5,
                ),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'Читать далее',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16 * _fontScale,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_right_alt,
                    color: Colors.black,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
