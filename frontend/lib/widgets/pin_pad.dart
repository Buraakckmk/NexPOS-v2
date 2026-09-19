import "package:flutter/material.dart";

class PinPad extends StatelessWidget {
  final void Function(String digit) onDigitPressed;
  final VoidCallback onBackspacePressed;
  final VoidCallback onClearPressed;
  final bool isLoading;
  final double? buttonAspectRatio;

  const PinPad({
    super.key,
    required this.onDigitPressed,
    required this.onBackspacePressed,
    required this.onClearPressed,
    required this.isLoading,
    this.buttonAspectRatio,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final spacing = 12.0;
        final aspectRatio = buttonAspectRatio ?? (width < 380 ? 1.05 : 1.15);

        return GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: aspectRatio,
          children: [
            ...List.generate(9, (index) {
              final value = "${index + 1}";
              return _PinButton(
                label: value,
                onTap: isLoading ? null : () => onDigitPressed(value),
              );
            }),
            _PinButton(
              icon: Icons.close_rounded,
              iconColor: const Color(0xFFEF4444),
              onTap: isLoading ? null : onClearPressed,
            ),
            _PinButton(
              label: "0",
              onTap: isLoading ? null : () => onDigitPressed("0"),
            ),
            _PinButton(
              icon: Icons.backspace_rounded,
              iconColor: const Color(0xFF71717A),
              onTap: isLoading ? null : onBackspacePressed,
            ),
          ],
        );
      },
    );
  }
}

class _PinButton extends StatefulWidget {
  final String? label;
  final IconData? icon;
  final Color? iconColor;
  final VoidCallback? onTap;

  const _PinButton({this.label, this.icon, this.iconColor, this.onTap});

  @override
  State<_PinButton> createState() => _PinButtonState();
}

class _PinButtonState extends State<_PinButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: _isPressed ? const Color(0xFFE2E8F0) : const Color(0xFFFFFFFF),
          border: Border.all(
            color: _isPressed
                ? const Color(0xFF3F3F46)
                : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
          boxShadow: [
            if (!_isPressed)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Center(
          child: widget.icon != null
              ? Icon(
                  widget.icon,
                  size: 28,
                  color: widget.iconColor ?? const Color(0xFF0F172A),
                )
              : Text(
                  widget.label ?? "",
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    letterSpacing: -1,
                  ),
                ),
        ),
      ),
    );
  }
}
