import "package:flutter/material.dart";

class PinDisplay extends StatelessWidget {
  final int length;
  final int maxLength;

  const PinDisplay({super.key, required this.length, this.maxLength = 4});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(maxLength, (index) {
        final isFilled = index < length;
        final isNext = index == length;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: isFilled ? 18 : 14,
          height: isFilled ? 18 : 14,
          decoration: BoxDecoration(
            color: isFilled ? const Color(0xFF10B981) : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: isFilled
                  ? const Color(0xFF10B981)
                  : (isNext ? const Color(0xFF3F3F46) : const Color(0xFF27272A)),
              width: isFilled ? 0 : 2,
            ),
            boxShadow: isFilled
                ? [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}

