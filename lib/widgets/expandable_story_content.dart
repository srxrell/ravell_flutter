import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:readreels/managers/settings_manager.dart';

class ExpandableStoryContent extends StatefulWidget {
  final String content;
  final bool isDarkBackground;

  const ExpandableStoryContent({
    super.key, 
    required this.content,
    this.isDarkBackground = false,
  });

  @override
  State<ExpandableStoryContent> createState() => _ExpandableStoryContentState();
}

class _ExpandableStoryContentState extends State<ExpandableStoryContent> {
  bool _isExpanded = false;
  bool _needsExpansion = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfNeedsExpansion();
    });
  }

  @override
  void didUpdateWidget(covariant ExpandableStoryContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) {
      _isExpanded = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkIfNeedsExpansion();
      });
    }
  }

  void _checkIfNeedsExpansion() {
    if (!mounted) return;
    if (widget.content.length > 200) {
      setState(() {
        _needsExpansion = true;
      });
    }
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsManager>(context);
    final fontScale = settings.fontScale;
    final isDark = widget.isDarkBackground || false;
    final textColor = isDark ? Colors.white70 : Colors.black;
    final btnColor = isDark ? Colors.white : Colors.blue;

    if (!_needsExpansion || _isExpanded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.content,
            style: TextStyle(
              fontSize: 16 * fontScale,
              color: textColor,
              height: settings.lineHeight,
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
                      settings.translate('view_more'),
                      style: TextStyle(
                        color: btnColor,
                        fontSize: 16 * fontScale,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_drop_up,
                      color: btnColor,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: widget.content,
            style: TextStyle(fontSize: 16 * fontScale),
          ),
          maxLines: 5,
          textDirection: TextDirection.ltr,
        );
        
        textPainter.layout(maxWidth: constraints.maxWidth);
        
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
                  fontSize: 16 * fontScale,
                  color: textColor,
                  height: settings.lineHeight,
                ),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    settings.translate('read_more'),
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16 * fontScale,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
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
