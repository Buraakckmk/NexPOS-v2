import "dart:async";

import "package:flutter/material.dart";

class AppFeedbackService {
  AppFeedbackService._();

  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static String? _lastMessage;
  static DateTime? _lastShownAt;
  static String? _activeMessage;
  static OverlayEntry? _activeEntry;
  static Timer? _dismissTimer;

  static const Duration _displayDuration = Duration(seconds: 3);
  static const Duration _sameMessageCooldown = Duration(seconds: 10);

  static void showError(String message) {
    _show(
      message,
      backgroundColor: const Color(0xFFFEF2F2),
      borderColor: const Color(0xFFEF4444),
      icon: Icons.error_outline_rounded,
      iconColor: const Color(0xFFB91C1C),
    );
  }

  static void showSuccess(String message) {
    _show(
      message,
      backgroundColor: const Color(0xFFECFDF5),
      borderColor: const Color(0xFF22C55E),
      icon: Icons.check_circle_outline_rounded,
      iconColor: const Color(0xFF166534),
    );
  }

  static void showInfo(String message) {
    _show(
      message,
      backgroundColor: const Color(0xFFEFF6FF),
      borderColor: const Color(0xFF60A5FA),
      icon: Icons.info_outline_rounded,
      iconColor: const Color(0xFF1D4ED8),
    );
  }

  static void _show(
    String message, {
    required Color backgroundColor,
    required Color borderColor,
    required IconData icon,
    required Color iconColor,
  }) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;

    if (_activeEntry != null && _activeMessage == trimmed) {
      return;
    }

    final now = DateTime.now();
    if (_lastMessage == trimmed &&
        _lastShownAt != null &&
        now.difference(_lastShownAt!) < _sameMessageCooldown) {
      return;
    }

    _lastMessage = trimmed;
    _lastShownAt = now;

    _dismissCurrent();

    final overlay = navigatorKey.currentState?.overlay;
    if (overlay == null) {
      final messenger = scaffoldMessengerKey.currentState;
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(trimmed),
            backgroundColor: backgroundColor,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      return;
    }

    _activeEntry = OverlayEntry(
      builder: (context) => IgnorePointer(
        child: Material(
          color: Colors.transparent,
          child: SafeArea(
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 40.0),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: borderColor.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 30,
                              offset: const Offset(0, 12),
                              spreadRadius: -4,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: iconColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(icon, color: iconColor, size: 20),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                trimmed,
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    _activeMessage = trimmed;
    overlay.insert(_activeEntry!);
    _dismissTimer = Timer(_displayDuration, _dismissCurrent);
  }

  static void _dismissCurrent() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _activeEntry?.remove();
    _activeEntry = null;
    _activeMessage = null;
  }
}

