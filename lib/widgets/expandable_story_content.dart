import 'package:flutter/material.dart';

// Порог, после которого текст СКРЫВАЕТСЯ ПОЛНОСТЬЮ
const int COLLAPSE_THRESHOLD = 170;

class ExpandableStoryContent extends StatefulWidget {
  final String content;

  const ExpandableStoryContent({super.key, required this.content});

  @override
  State<ExpandableStoryContent> createState() => _ExpandableStoryContentState();
}

class _ExpandableStoryContentState extends State<ExpandableStoryContent> {
  bool _isExpanded = false;
  int _totalWords = 170;
  bool _shouldBeHidden = false;

  @override
  void initState() {
    super.initState();
    _recalculateState();
  }

  // ✅ ИСПРАВЛЕНИЕ 1: Пересчет состояния при смене контента
  @override
  void didUpdateWidget(covariant ExpandableStoryContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) {
      // Сбрасываем состояние развертывания при смене истории
      _isExpanded = false;
      _recalculateState();
    }
  }

  void _recalculateState() {
    _totalWords = widget.content.split(RegExp(r'\s+')).length;

    // Если слов больше 150, мы должны ее СВЕРНУТЬ (изначально скрыть)
    _shouldBeHidden = _totalWords > COLLAPSE_THRESHOLD;

    // Если история короткая (<= 150), она должна быть ИЗНАЧАЛЬНО развернута
    if (!_shouldBeHidden) {
      _isExpanded = true;
    }
    // Если история длинная, _isExpanded остается false, чтобы показать триггер
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = true;
    });
  }

  void _toggleCollapsed() {
    setState(() {
      _isExpanded = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 1. ДЛИННАЯ ИСТОРИЯ И СВЕРНУТОЕ СОСТОЯНИЕ: Показываем только триггер
    // Правило 1: Длинная история скрывается полностью.
    if (_shouldBeHidden && !_isExpanded) {
      return GestureDetector(
        onTap: _toggleExpanded,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // обрежем до 150
              Text(
                widget.content.substring(0, COLLAPSE_THRESHOLD),
                style: const TextStyle(fontSize: 18, color: Colors.black),
              ),
              Row(
                children: [
                  Text(
                    'Читать далее ($_totalWords слов)...',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_right_alt,
                    color: Colors.blue,
                    size: 24,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // 2. КОРОТКАЯ ИСТОРИЯ ИЛИ РАЗВЕРНУТАЯ ДЛИННАЯ ИСТОРИЯ: Показываем полный текст
    // Правило 2: Короткая история не скрывается вовсе.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Отображение текста
        Text(
          widget.content,
          style: const TextStyle(fontSize: 18, color: Colors.black),
        ),

        // Опциональный триггер "Свернуть"
        if (_shouldBeHidden && _isExpanded)
          GestureDetector(
            onTap: _toggleCollapsed,
            child: const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Text(
                'Свернуть',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
          ),
      ],
    );
  }
}
