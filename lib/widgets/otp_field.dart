import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OTPField extends StatefulWidget {
  final TextEditingController controller;
  final int otpLength;
  final Function(String) onSubmit;

  const OTPField(
    this.onSubmit, {
    Key? key,
    required this.controller,
    this.otpLength = 6,
  }) : super(key: key);

  @override
  _OTPFieldState createState() => _OTPFieldState();
}

class _OTPFieldState extends State<OTPField> {
  late List<FocusNode> focusNodes;
  late List<TextEditingController> controllers;

  @override
  void initState() {
    super.initState();
    focusNodes = List.generate(widget.otpLength, (index) => FocusNode());
    controllers = List.generate(
      widget.otpLength,
      (index) => TextEditingController(),
    );
  }

  @override
  void dispose() {
    for (var node in focusNodes) {
      node.dispose();
    }
    for (var controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // Обновляет основной контроллер, объединяя все символы
  void _updateMainController() {
    String otp = controllers.map((c) => c.text).join();
    widget.controller.text = otp;
    if (otp.length == widget.otpLength) {
      widget.onSubmit(otp);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(widget.otpLength, (index) {
        return SizedBox(
          width: 45,
          height: 55,
          child: TextField(
            controller: controllers[index],
            focusNode: focusNodes[index],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 1,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            decoration: InputDecoration(
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.blue, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Colors.deepPurple,
                  width: 2,
                ),
              ),
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],

            onSubmitted: widget.onSubmit,
            // >>> ИСПРАВЛЕННАЯ ЛОГИКА УПРАВЛЕНИЯ ФОКУСОМ <<<
            onChanged: (value) {
              _updateMainController();

              // 1. Переход вперед
              if (value.length == 1) {
                if (index < widget.otpLength - 1) {
                  FocusScope.of(context).requestFocus(focusNodes[index + 1]);
                } else {
                  FocusScope.of(context).unfocus(); // Последнее поле
                }
              }
              // 2. Переход назад (Backspace)
              else if (value.isEmpty && index > 0) {
                // Если поле очищено и это не первое поле, переходим к предыдущему.
                FocusScope.of(context).requestFocus(focusNodes[index - 1]);
              }
            },
          ),
        );
      }),
    );
  }
}
