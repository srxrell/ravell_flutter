import 'package:flutter/material.dart';

class MarkdownToolbar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onChanged;

  const MarkdownToolbar({
    super.key,
    required this.controller,
    this.onChanged,
  });

  void _applyFormatting(String pattern, {bool isLineStart = false}) {
    final text = controller.text;
    final selection = controller.selection;

    if (selection.start < 0 || selection.end < 0) return;

    String newText;
    TextSelection newSelection;

    if (isLineStart) {
      // Logic for line-start formatting like headers or lists
      final start = selection.start;
      // Find the start of the current line
      final lineStart = text.lastIndexOf('\n', start - 1) + 1;
      
      newText = text.replaceRange(lineStart, lineStart, pattern);
      newSelection = TextSelection.collapsed(offset: selection.baseOffset + pattern.length);
      
    } else {
      // Logic for wrapping text like bold/italic
      newText = text.replaceRange(
        selection.start,
        selection.end,
        '$pattern${text.substring(selection.start, selection.end)}$pattern',
      );
      
      newSelection = TextSelection(
        baseOffset: selection.start + pattern.length,
        extentOffset: selection.end + pattern.length,
      );
    }

    controller.value = TextEditingValue(
      text: newText,
      selection: newSelection,
    );
    
    onChanged?.call();
  }

  void _applyLink() {
    final text = controller.text;
    final selection = controller.selection;
    if (selection.start < 0 || selection.end < 0) return;

    final selectedText = text.substring(selection.start, selection.end);
    final newText = text.replaceRange(
      selection.start,
      selection.end,
      '[$selectedText](url)',
    );

    final newSelection = TextSelection(
      baseOffset: selection.start + 1, // cursor inside brackets
      extentOffset: selection.start + 1 + selectedText.length, 
    );
     // OR maybe select "url" so user can type over it?
     // Let's select "url" part: `[text](` is length 2 + text.length
     final urlStart = selection.start + 2 + selectedText.length;
     final finalSelection = TextSelection(baseOffset: urlStart, extentOffset: urlStart + 3);


    controller.value = TextEditingValue(
      text: newText,
      selection: finalSelection,
    );
    onChanged?.call();
  }

  void _applyHorizontalRule() {
    final text = controller.text;
    final selection = controller.selection;
    if (selection.start < 0 || selection.end < 0) return;

    final start = selection.start;
    final lineStart = text.lastIndexOf('\n', start - 1) + 1;
    
    // Insert --- at new line
    final newText = text.replaceRange(lineStart, lineStart, '---\n');
    final newSelection = TextSelection.collapsed(offset: lineStart + 4);

    controller.value = TextEditingValue(
      text: newText,
      selection: newSelection,
    );
    onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          IconButton(
            onPressed: () => _applyFormatting('**'),
            icon: const Icon(Icons.format_bold),
            tooltip: 'Жирный',
          ),
          IconButton(
            onPressed: () => _applyFormatting('*'),
            icon: const Icon(Icons.format_italic),
            tooltip: 'Курсив',
          ),
          IconButton(
            onPressed: () => _applyFormatting('~~'),
            icon: const Icon(Icons.strikethrough_s),
            tooltip: 'Зачеркнутый',
          ),
          IconButton(
             onPressed: () => _applyFormatting('`'),
             icon: const Icon(Icons.code),
             tooltip: 'Код',
           ),
           IconButton(
             onPressed: () => _applyFormatting('```'),
             icon: const Icon(Icons.terminal),
             tooltip: 'Блок кода',
           ),
          IconButton(
            onPressed: () => _applyFormatting('# ', isLineStart: true),
            icon: const Icon(Icons.title),
            tooltip: 'Заголовок 1',
          ),
          IconButton(
            onPressed: () => _applyFormatting('## ', isLineStart: true),
            icon: const Icon(Icons.text_fields),
             tooltip: 'Заголовок 2',
          ),
          IconButton(
            onPressed: () => _applyFormatting('> ', isLineStart: true),
            icon: const Icon(Icons.format_quote),
            tooltip: 'Цитата',
          ),
          IconButton(
            onPressed: () => _applyFormatting('- ', isLineStart: true),
            icon: const Icon(Icons.list),
            tooltip: 'Список',
          ),
          IconButton(
            onPressed: _applyLink,
            icon: const Icon(Icons.link),
            tooltip: 'Ссылка',
          ),
          IconButton(
            onPressed: _applyHorizontalRule,
            icon: const Icon(Icons.horizontal_rule),
            tooltip: 'Разделитель',
          ),
        ],
      ),
    );
  }
}
