import 'package:flutter/material.dart';
import 'package:readreels/theme.dart';

// --- 4. CUSTOM WIDGETS (Полный Необрутализм) ---
// Используйте ЭТИ виджеты, чтобы получить границы 4px/8px

enum NeoButtonType { login, signup, general, white }

class NeoIconButton extends StatelessWidget {
  final Widget child;
  final Widget icon;
  final VoidCallback? onPressed;
  final NeoButtonType type;

  const NeoIconButton({
    super.key,
    required this.child,
    required this.onPressed,
    required this.icon,
    this.type = NeoButtonType.general,
  });

  Color _getButtonColor() {
    switch (type) {
      case NeoButtonType.login:
        return btnColorLogin;
      case NeoButtonType.signup:
        return btnColorSignup;
      case NeoButtonType.white:
        return btnColorWhite;
      case NeoButtonType.general:
      default:
        return btnColorDefault;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = onPressed == null;
    return GestureDetector(
      onTap: onPressed,
      child: Opacity(
        opacity: isDisabled ? 0.6 : 1.0,
        child: Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: _getButtonColor(),
            // Асимметричные границы: Слева/Верх = 4, Справа/Низ = 8
            border: const Border(
              top: BorderSide(color: neoBlack, width: 4),
              left: BorderSide(color: neoBlack, width: 4),
              right: BorderSide(color: neoBlack, width: 8),
              bottom: BorderSide(color: neoBlack, width: 8),
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class NeoButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final NeoButtonType type;

  const NeoButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.type = NeoButtonType.general,
  });

  Color _getButtonColor() {
    switch (type) {
      case NeoButtonType.login:
        return btnColorLogin;
      case NeoButtonType.signup:
        return btnColorSignup;
      case NeoButtonType.general:
      default:
        return btnColorDefault;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = onPressed == null;
    return GestureDetector(
      onTap: onPressed,
      child: Opacity(
        opacity: isDisabled ? 0.6 : 1.0,
        child: Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: _getButtonColor(),
            // Асимметричные границы: Слева/Верх = 4, Справа/Низ = 8
            border: const Border(
              top: BorderSide(color: neoBlack, width: 4),
              left: BorderSide(color: neoBlack, width: 4),
              right: BorderSide(color: neoBlack, width: 8),
              bottom: BorderSide(color: neoBlack, width: 8),
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              text.toUpperCase(),
              textAlign: TextAlign.center,
              // Шрифт Epilogue
              style: neoTextStyle(18, weight: FontWeight.w900),
            ),
          ),
        ),
      ),
    );
  }
}

class NeoInput extends StatelessWidget {
  final String hintText;
  final TextEditingController? controller;
  final bool isPassword;

  const NeoInput({
    super.key,
    required this.hintText,
    this.controller,
    this.isPassword = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      height: 70,
      decoration: BoxDecoration(
        color: neoWhite,
        border: const Border(
          top: BorderSide(color: neoBlack, width: 4),
          left: BorderSide(color: neoBlack, width: 4),
          right: BorderSide(color: neoBlack, width: 8),
          bottom: BorderSide(color: neoBlack, width: 8),
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: neoTextStyle(18, weight: FontWeight.w600),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hintText,
          hintStyle: neoTextStyle(18, color: Colors.grey.shade600, weight: FontWeight.normal),
        ),
      ),
    );
  }
}

class NeoContainer extends StatelessWidget {
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final VoidCallback? onTap;

  const NeoContainer({
    super.key,
    required this.child,
    this.color = neoWhite,
    this.padding,
    this.width,
    this.height,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        padding: padding ?? const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          border: const Border(
            top: BorderSide(color: neoBlack, width: 4),
            left: BorderSide(color: neoBlack, width: 4),
            right: BorderSide(color: neoBlack, width: 8),
            bottom: BorderSide(color: neoBlack, width: 8),
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: child,
      ),
    );
  }
}