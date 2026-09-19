import "package:flutter/material.dart";
import "../services/admin_auth_service.dart";
import "pin_display.dart";
import "pin_pad.dart";

class AdminPinDialog extends StatefulWidget {
  final String title;
  final String message;
  final String actionLabel;

  const AdminPinDialog({
    super.key,
    this.title = "Yönetici Paneli",
    this.message = "Panele girmek için yönetici PIN kodunu tekrar girin.",
    this.actionLabel = "Panele Gir",
  });

  @override
  State<AdminPinDialog> createState() => _AdminPinDialogState();
}

class _AdminPinDialogState extends State<AdminPinDialog> {
  String _pin = "";
  String? _errorText;
  bool _isVerifying = false;

  void _handleDigitTap(String digit) {
    if (_pin.length >= 6 || _isVerifying) return;
    setState(() {
      _pin += digit;
      _errorText = null;
    });
  }

  void _handleBackspace() {
    if (_pin.isEmpty || _isVerifying) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _errorText = null;
    });
  }

  void _handleClear() {
    if (_isVerifying) return;
    setState(() {
      _pin = "";
      _errorText = null;
    });
  }

  Future<void> _verifyPin() async {
    if (_pin.length != 6 || _isVerifying) {
      setState(() {
        _errorText = "6 haneli yönetici PIN girin.";
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorText = null;
    });

    final isAdmin = await AdminAuthService.verifyAdminPin(_pin);

    if (!mounted) return;

    if (!isAdmin) {
      setState(() {
        _isVerifying = false;
        _errorText = "Yönetici şifresi hatalı.";
        _pin = "";
      });
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 40,
              spreadRadius: 10,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: Color(0xFF3B82F6),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF71717A),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: Color(0xFFE2E8F0), height: 1),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PinDisplay(length: _pin.length, maxLength: 6),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 20,
                      child: _errorText != null
                          ? Text(
                              _errorText!,
                              style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 16),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: PinPad(
                        isLoading: _isVerifying,
                        onDigitPressed: _handleDigitTap,
                        onBackspacePressed: _handleBackspace,
                        onClearPressed: _handleClear,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Divider(color: Color(0xFFE2E8F0), height: 1),

            // Footer Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF71717A),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    child: const Text(
                      "Vazgeç",
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _isVerifying ? null : _verifyPin,
                    icon: _isVerifying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF0F172A),
                            ),
                          )
                        : const Icon(Icons.lock_open_rounded, size: 18),
                    label: Text(widget.actionLabel),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFDBEAFE),
                      foregroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
