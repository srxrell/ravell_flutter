import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, FlutterError;

// =================================================================
// 1. Ядро парсера SVG-пути (CustomPainter)
// Преобразует строку "d" в объект Flutter Path.
// =================================================================

/// Класс, содержащий логику для парсинга и отрисовки SVG-пути.
class SvgPathPainter extends CustomPainter {
  final String svgPathData;
  final Color color;

  SvgPathPainter({required this.svgPathData, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Парсим строку пути SVG в объект Flutter Path
    final path = _parseSvgPath(svgPathData);

    // Если путь пуст, не рисуем ничего
    if (path.getBounds().isEmpty) return;

    // 2. Определяем границы пути для масштабирования
    final bounds = path.getBounds();

    // 3. Вычисляем коэффициент масштабирования
    final scaleX = size.width / bounds.width;
    final scaleY = size.height / bounds.height;
    // Используем минимальный масштаб, чтобы путь поместился в меньшую сторону
    final scale = (scaleX.isFinite && scaleY.isFinite) ? scaleX.clamp(0.0, scaleY) : 1.0;

    // 4. Применяем трансформацию: центрирование и масштабирование
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    canvas.translate(-bounds.center.dx, -bounds.center.dy);

    // 5. Создаем кисти
    final Paint fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Толщина контура обратно пропорциональна масштабу, чтобы выглядеть одинаково
    final Paint strokePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 / scale.clamp(1.0, double.infinity);

    // 6. Отрисовываем путь
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  // --- ФУНКЦИЯ ПАРСИНГА ПУТИ (M, L, C, Z и их относительные версии) ---
  Path _parseSvgPath(String data) {
    final path = Path();
    // Чистим данные: заменяем разделители на один пробел и убираем лишние
    final tokens = data.replaceAll(RegExp(r'[,\s]+'), ' ').trim().split(' ').where((s) => s.isNotEmpty).toList();

    String currentCommand = '';
    int tokenIndex = 0;

    double lastX = 0;
    double lastY = 0;

    // Вспомогательная функция для безопасного чтения следующего числа
    double _readNext(List<String> tokens, int index, String command) {
      if (index >= tokens.length) {
        throw Exception('Недостаточно координат для команды $command');
      }
      final value = double.tryParse(tokens[index]);
      if (value == null) {
        throw Exception('Неверное значение координаты: ${tokens[index]} для команды $command');
      }
      return value;
    }

    while (tokenIndex < tokens.length) {
      final token = tokens[tokenIndex];
      final charCode = token.codeUnitAt(0);

      // 1. Если токен — это команда (буква)
      if (token.length == 1 && (charCode >= 'A'.codeUnitAt(0) && charCode <= 'Z'.codeUnitAt(0) || charCode >= 'a'.codeUnitAt(0) && charCode <= 'z'.codeUnitAt(0))) {
        currentCommand = token;
        tokenIndex++;
      }
      // 2. Если токен — это число (данные команды)
      else if (currentCommand.isNotEmpty) {

        try {
          String upperCommand = currentCommand.toUpperCase();
          bool isRelative = currentCommand == currentCommand.toLowerCase();

          double dx = isRelative ? lastX : 0;
          double dy = isRelative ? lastY : 0;

          switch (upperCommand) {
            case 'M': // MoveTo (M x y, m dx dy)
              double x = _readNext(tokens, tokenIndex++, currentCommand);
              double y = _readNext(tokens, tokenIndex++, currentCommand);

              path.moveTo(x + dx, y + dy);
              lastX = x + dx;
              lastY = y + dy;
              // Последующие координаты M обрабатываются как L
              if (currentCommand == 'M') currentCommand = 'L';
              if (currentCommand == 'm') currentCommand = 'l';
              break;

            case 'L': // LineTo (L x y, l dx dy)
              double x = _readNext(tokens, tokenIndex++, currentCommand);
              double y = _readNext(tokens, tokenIndex++, currentCommand);

              path.lineTo(x + dx, y + dy);
              lastX = x + dx;
              lastY = y + dy;
              break;

            case 'C': // Cubic Bezier (C x1 y1 x2 y2 x y)
              double x1 = _readNext(tokens, tokenIndex++, currentCommand) + dx;
              double y1 = _readNext(tokens, tokenIndex++, currentCommand) + dy;
              double x2 = _readNext(tokens, tokenIndex++, currentCommand) + dx;
              double y2 = _readNext(tokens, tokenIndex++, currentCommand) + dy;
              double x = _readNext(tokens, tokenIndex++, currentCommand) + dx;
              double y = _readNext(tokens, tokenIndex++, currentCommand) + dy;

              path.cubicTo(x1, y1, x2, y2, x, y);
              lastX = x;
              lastY = y;
              break;

            case 'Z': // ClosePath (Z, z)
              path.close();
              // SVG спецификация сбрасывает текущую точку после Z, но не команду.
              // Для простоты здесь сбрасываем команду.
              // В более полном парсере нужно восстанавливать точку.
              currentCommand = '';
              break;

            default:
            // Игнорируем неподдерживаемые команды, пропускаем токен
              tokenIndex++;
              break;
          }
        } catch (e) {
          debugPrint('SVG Path Error: Ошибка парсинга координат для команды $currentCommand. Ошибка: $e');
          break; // Прерываем парсинг при ошибке
        }
      }
      // 3. Если это не команда и не ожидаемое число
      else {
        tokenIndex++; // Пропускаем неизвестный токен
      }
    }
    return path;
  }

  @override
  bool shouldRepaint(SvgPathPainter oldDelegate) => oldDelegate.svgPathData != svgPathData || oldDelegate.color != color;
}

// =================================================================
// 2. Виджет-загрузчик (SvgAssetViewer)
// Читает файл по пути и передает d-атрибут в SvgPathPainter.
// =================================================================

/// Готовый виджет для отображения SVG-пути, загружая данные из файла актива.
class SvgAssetViewer extends StatefulWidget {
  final String assetPath; // Путь к SVG-файлу в assets/
  final Color color;
  final double size;

  const SvgAssetViewer({
    super.key,
    required this.assetPath,
    this.color = Colors.black,
    this.size = 150.0,
  });

  @override
  State<SvgAssetViewer> createState() => _SvgAssetViewerState();
}

class _SvgAssetViewerState extends State<SvgAssetViewer> {
  // Переменная для хранения извлеченной строки пути 'd'
  String? _svgData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSvgData();
  }

  // --- Асинхронная функция загрузки и парсинга ---
  Future<void> _loadSvgData() async {
    try {
      // 1. Читаем файл актива по пути
      final String svgContent = await rootBundle.loadString(widget.assetPath);

      // 2. Ищем атрибут 'd' внутри тега <path> с помощью простого Regex.
      // Ищет: <path ... d="ПУТЬ" ...>
      final RegExp dAttributeRegex = RegExp(
          r"""<path[^>]*\sd\s*=\s*["']([^"']+)["']""",
          caseSensitive: false
      );
      final Match? match = dAttributeRegex.firstMatch(svgContent);

      if (match != null && match.group(1) != null) {
        if (mounted) {
          setState(() {
            _svgData = match.group(1);
            _isLoading = false;
          });
        }
      } else {
        // Ошибка, если атрибут d не найден.
        throw Exception('В SVG-файле не найден атрибут "d" в теге <path>. Возможно, файл содержит растровое изображение, текст или другие неподдерживаемые элементы SVG.');
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Error loading SVG asset: ${widget.assetPath}. Error: $e');
        setState(() {
          // Если файл не найден (FlutterError), выводим понятное сообщение.
          _error = e is FlutterError ? 'Ошибка актива: Проверьте, добавлен ли файл в pubspec.yaml' : e.toString().split('.').first;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_error != null || _svgData == null) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.red.shade300, width: 1),
            borderRadius: BorderRadius.circular(8),
            color: Colors.red.withOpacity(0.1),
          ),
          padding: const EdgeInsets.all(4),
          child: Center(
            child: Text(
              _error!.contains('Failed to load asset') ? 'Ошибка загрузки актива!' : 'Ошибка парсинга SVG!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red, fontSize: widget.size * 0.1, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );
    }

    // Если данные загружены, отрисовываем их с помощью CustomPainter
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: SvgPathPainter(
          svgPathData: _svgData!,
          color: widget.color,
        ),
      ),
    );
  }
}