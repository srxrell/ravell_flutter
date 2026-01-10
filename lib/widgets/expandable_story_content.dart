import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:readreels/managers/settings_manager.dart';

class ExpandableStoryContent extends StatefulWidget {
  final String content;
  final bool isDarkBackground;
  final VoidCallback? onReadMore; // Добавили параметр для клика

  const ExpandableStoryContent({
    super.key,
    required this.content,
    this.isDarkBackground = false,
    this.onReadMore,
  });

  @override
  State<ExpandableStoryContent> createState() => _ExpandableStoryContentState();
}

class _ExpandableStoryContentState extends State<ExpandableStoryContent> {
  bool _needsExpansion = false;

  @override
  void initState() {
    super.initState();
    _checkIfNeedsExpansion();
  }

  @override
  void didUpdateWidget(covariant ExpandableStoryContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) {
      _checkIfNeedsExpansion();
    }
  }

  void _checkIfNeedsExpansion() {
    // Упрощенная проверка: если текст длинный, помечаем что нужно сокращение
    if (widget.content.length > 200) {
      setState(() {
        _needsExpansion = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsManager>(context);
    final fontScale = settings.fontScale;
    final textColor = widget.isDarkBackground ? Colors.white70 : Colors.black;
    final btnColor = widget.isDarkBackground ? Colors.white : Colors.blue;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Если текст короткий — просто выводим его
        if (!_needsExpansion) {
          return Text(
            widget.content,
            style: TextStyle(
              fontSize: 16 * fontScale,
              color: textColor,
              height: settings.lineHeight,
            ),
          );
        }

        // Если длинный — используем Column внутри Flexible (чтобы не было overflow)
        return Column(
          mainAxisSize: MainAxisSize.min, // Важно: колонка занимает минимум места
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                widget.content,
                style: TextStyle(
                  fontSize: 16 * fontScale,
                  color: textColor,
                  height: settings.lineHeight,
                ),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: widget.onReadMore, // Используем параметр
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    settings.translate('read_more'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16 * fontScale,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_right_alt,
                    size: 20,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}