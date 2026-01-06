import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:readreels/managers/settings_manager.dart';
import 'package:provider/provider.dart';

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
    final settings = Provider.of<SettingsManager>(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          IconButton(
            onPressed: () => _applyFormatting('**'),
            icon: const Icon(Icons.format_bold),
            tooltip: settings.translate('bold'),
          ),
          IconButton(
            onPressed: () => _applyFormatting('*'),
            icon: const Icon(Icons.format_italic),
            tooltip: settings.translate('italic'),
          ),
          IconButton(
            onPressed: () => _applyFormatting('~~'),
            icon: const Icon(Icons.strikethrough_s),
            tooltip: settings.translate('strikethrough'),
          ),
          IconButton(
             onPressed: () => _applyFormatting('`'),
             icon: const Icon(Icons.code),
             tooltip: settings.translate('code'),
           ),
           IconButton(
             onPressed: () => _applyFormatting('```'),
             icon: const Icon(Icons.terminal),
             tooltip: settings.translate('code_block'),
           ),
          IconButton(
            onPressed: () => _applyFormatting('# ', isLineStart: true),
            icon: const Icon(Icons.title),
            tooltip: settings.translate('h1'),
          ),
          IconButton(
            onPressed: () => _applyFormatting('## ', isLineStart: true),
            icon: const Icon(Icons.text_fields),
             tooltip: settings.translate('h2'),
          ),
          IconButton(
            onPressed: () => _applyFormatting('> ', isLineStart: true),
            icon: const Icon(Icons.format_quote),
            tooltip: settings.translate('quote'),
          ),
          IconButton(
            onPressed: () => _applyFormatting('- ', isLineStart: true),
            icon: const Icon(Icons.list),
            tooltip: settings.translate('list'),
          ),
          IconButton(
            onPressed: _applyLink,
            icon: const Icon(Icons.link),
            tooltip: settings.translate('link'),
          ),
          IconButton(
            onPressed: _applyHorizontalRule,
            icon: const Icon(Icons.horizontal_rule),
            tooltip: settings.translate('divider'),
          ),
        ],
      ),
    );
  }
}
