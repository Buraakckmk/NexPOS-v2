import "dart:math" as math;

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../providers/auth_provider.dart";
import "../services/app_feedback_service.dart";
import "../widgets/pin_display.dart";
import "../widgets/pin_pad.dart";
import "../widgets/server_ip_dialog.dart";
import "waiter_tables_screen.dart";

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  int? _lastSuccessRole;
  String? _lastError;

  late final AnimationController _orbController;
  late final AnimationController _floatController;
  late final AnimationController _rotateController;

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _orbController.dispose();
    _floatController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  Future<void> _handleDigitTap(BuildContext context, String digit) async {
    final auth = context.read<AuthProvider>();
    auth.addDigit(digit);

    if (auth.pin.length != 6) return;

    final success = await auth.submitPinIfReady();
    if (!context.mounted) return;

    if (!success || auth.currentUser == null) {
      return;
    }

    final roleId = auth.currentUser!.roleId;
    if (_lastSuccessRole != roleId) {
      _lastSuccessRole = roleId;
      AppFeedbackService.showSuccess(
        "Giriş Başarılı, Hoşgeldin ${auth.currentUser!.fullName}",
      );
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const WaiterTablesScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        if (auth.errorMessage != null && auth.errorMessage != _lastError) {
          _lastError = auth.errorMessage;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            AppFeedbackService.showError(auth.errorMessage!);
          });
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktopPlatform =
                !kIsWeb &&
                (defaultTargetPlatform == TargetPlatform.windows ||
                    defaultTargetPlatform == TargetPlatform.linux ||
                    defaultTargetPlatform == TargetPlatform.macOS);
            final isDesktopLayout =
                constraints.maxWidth > 800 || isDesktopPlatform;

            return isDesktopLayout
                ? _buildDesktopLogin(context, auth)
                : _buildMobileLogin(context, auth);
          },
        );
      },
    );
  }

  Widget _buildDesktopLogin(BuildContext context, AuthProvider auth) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Row(
        children: [
          // ── Sol: 3D Hero Panel ──────────────────────────────────────────
          Expanded(
            flex: 11,
            child: _HeroPanel(
              orbController: _orbController,
              floatController: _floatController,
              rotateController: _rotateController,
            ),
          ),
          // ── Sağ: PIN Girişi ────────────────────────────────────────────
          Expanded(
            flex: 9,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFFFFFFF),
                border: Border(
                  left: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // ── Dinamik boyut hesabı ──
                  final availH = constraints.maxHeight;
                  final availW = constraints.maxWidth;

                  // v1.2.0 alanı + dikey padding rezervi
                  const versionAreaH = 44.0;
                  const vertPad = 32.0; // 16 * 2
                  final usableH = availH - versionAreaH - vertPad;

                  // PinPad için dinamik aspect ratio hesabı
                  const pinSpacing = 12.0;
                  final pinAreaW = (availW - 48.0).clamp(0.0, 352.0);
                  final buttonW = (pinAreaW - 2 * pinSpacing) / 3;

                  // Sabit eleman yükseklikleri toplamı (badge+title+gap+subtitle+pinDisplay+loading+küçük spacer'lar)
                  const fixedContentH =
                      33.0 + 35.0 + 8.0 + 20.0 + 18.0 + 28.0 + 12.0;
                  const threeGaps = 48.0; // 3 × 16px dinamik gap
                  const pinPadRowSpacings = 36.0; // 3 satır arası × 12px

                  final availForButtons =
                      usableH - fixedContentH - threeGaps - pinPadRowSpacings;
                  final buttonH = (availForButtons / 4).clamp(44.0, 110.0);
                  final computedAspectRatio = (buttonW / buttonH).clamp(
                    0.7,
                    2.5,
                  );

                  // Gap: kalan boşluğu 3'e böl
                  final remainingGapSpace =
                      usableH - fixedContentH - 4 * buttonH - pinPadRowSpacings;
                  final gap = (remainingGapSpace / 3).clamp(6.0, 28.0);

                  return Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 400),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Giriş başlık bloğu
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF10B981,
                                      ).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(99),
                                      border: Border.all(
                                        color: const Color(
                                          0xFF10B981,
                                        ).withValues(alpha: 0.25),
                                      ),
                                    ),
                                    child: const Text(
                                      "Güvenli Giriş",
                                      style: TextStyle(
                                        color: Color(0xFF10B981),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: gap),
                                  Text(
                                    "Giriş Yapın",
                                    style: const TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF0F172A),
                                      letterSpacing: -1,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    "6 haneli PIN kodunuzu girin",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: gap),
                                  PinDisplay(
                                    length: auth.pin.length,
                                    maxLength: 6,
                                  ),
                                  SizedBox(height: gap),
                                  SizedBox(
                                    height: 28,
                                    child: auth.isLoading
                                        ? const CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Color(0xFF10B981),
                                                ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(height: 12),
                                  PinPad(
                                    isLoading: auth.isLoading,
                                    buttonAspectRatio: computedAspectRatio,
                                    onDigitPressed: (digit) =>
                                        _handleDigitTap(context, digit),
                                    onBackspacePressed: auth.removeDigit,
                                    onClearPressed: auth.clearPin,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // v1.2.0 sabit alt bölge
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: GestureDetector(
                          onLongPress: () {
                            showDialog(
                              context: context,
                              builder: (context) => const ServerIpDialog(),
                            );
                          },
                          child: const Text(
                            "v2.0.0",
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLogin(BuildContext context, AuthProvider auth) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: Stack(
        children: [
          // Arka plan orbs
          AnimatedBuilder(
            animation: _orbController,
            builder: (_, child) {
              return Stack(
                children: [
                  Positioned(
                    top:
                        -60 + math.sin(_orbController.value * 2 * math.pi) * 20,
                    left: -60,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF10B981).withValues(alpha: 0.1),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom:
                        -40 + math.cos(_orbController.value * 2 * math.pi) * 15,
                    right: -40,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF6366F1).withValues(alpha: 0.08),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isSmall = constraints.maxHeight < 600;
                return Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: isSmall ? 20 : 36,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo
                        AnimatedBuilder(
                          animation: _floatController,
                          builder: (_, child) => Transform.translate(
                            offset: Offset(0, -6 + _floatController.value * 12),
                            child: Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF10B981),
                                    Color(0xFF059669),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF10B981,
                                    ).withValues(alpha: 0.4),
                                    blurRadius: 28,
                                    spreadRadius: 4,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.restaurant_menu_rounded,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: isSmall ? 20 : 28),
                        const Text(
                          "NEXPOS",
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "PIN Kodunuzu Girin",
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: isSmall ? 28 : 36),
                        PinDisplay(length: auth.pin.length, maxLength: 6),
                        SizedBox(height: isSmall ? 20 : 28),
                        SizedBox(
                          height: 28,
                          child: auth.isLoading
                              ? const CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF10B981),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 8),
                        PinPad(
                          isLoading: auth.isLoading,
                          onDigitPressed: (digit) =>
                              _handleDigitTap(context, digit),
                          onBackspacePressed: auth.removeDigit,
                          onClearPressed: auth.clearPin,
                        ),
                        SizedBox(height: isSmall ? 20 : 32),
                        GestureDetector(
                          onLongPress: () {
                            showDialog(
                              context: context,
                              builder: (context) => const ServerIpDialog(),
                            );
                          },
                          child: const Text(
                            "v1.2.0",
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── _HeroPanel ───────────────────────────────────────────────────────────────

class _HeroPanel extends StatelessWidget {
  final AnimationController orbController;
  final AnimationController floatController;
  final AnimationController rotateController;

  const _HeroPanel({
    required this.orbController,
    required this.floatController,
    required this.rotateController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A5F), Color(0xFF1A3448), Color(0xFF1B3A2E)],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // ── Sahne orb'ları ──────────────────────────────────────────────
          AnimatedBuilder(
            animation: orbController,
            builder: (_, child) {
              final t = orbController.value * 2 * math.pi;
              return Stack(
                children: [
                  Positioned(
                    top: 80 + math.sin(t * 0.7) * 40,
                    left: 60 + math.cos(t * 0.5) * 30,
                    child: _Orb(
                      size: 380,
                      color: const Color(0xFF10B981),
                      alpha: 0.14,
                    ),
                  ),
                  Positioned(
                    bottom: 100 + math.sin(t * 0.4 + 1) * 50,
                    right: 40 + math.cos(t * 0.6) * 25,
                    child: _Orb(
                      size: 260,
                      color: const Color(0xFF6366F1),
                      alpha: 0.13,
                    ),
                  ),
                  Positioned(
                    top: 200 + math.cos(t * 0.3 + 2) * 35,
                    right: 80 + math.sin(t * 0.8) * 20,
                    child: _Orb(
                      size: 140,
                      color: const Color(0xFFF59E0B),
                      alpha: 0.12,
                    ),
                  ),
                ],
              );
            },
          ),

          // ── Izgaralı perspektif zemin çizgisi ──────────────────────────
          Positioned.fill(
            child: AnimatedBuilder(
              animation: rotateController,
              builder: (_, child) =>
                  CustomPaint(painter: _GridPainter(rotateController.value)),
            ),
          ),

          // ── Ortadaki 3D kart ─────────────────────────────────────────
          Center(
            child: AnimatedBuilder(
              animation: floatController,
              builder: (_, child) {
                final floatY = -10.0 + floatController.value * 20.0;
                return Transform.translate(
                  offset: Offset(0, floatY),
                  child: _GlassCard(rotateController: rotateController),
                );
              },
            ),
          ),

          // ── Alt özellikler şeridi ────────────────────────────────────
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _FeaturePill(
                  icon: Icons.bolt_rounded,
                  label: "Hızlı",
                  color: const Color(0xFFF59E0B),
                ),
                const SizedBox(width: 12),
                _FeaturePill(
                  icon: Icons.shield_rounded,
                  label: "Güvenilir",
                  color: const Color(0xFF10B981),
                ),
                const SizedBox(width: 12),
                _FeaturePill(
                  icon: Icons.auto_awesome_rounded,
                  label: "Modern",
                  color: const Color(0xFF6366F1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── _Orb ─────────────────────────────────────────────────────────────────────

class _Orb extends StatelessWidget {
  final double size;
  final Color color;
  final double alpha;

  const _Orb({required this.size, required this.color, required this.alpha});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

// ── _GlassCard ───────────────────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  final AnimationController rotateController;

  const _GlassCard({required this.rotateController});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: rotateController,
      builder: (_, child) {
        final tilt =
            math.sin(rotateController.value * 2 * math.pi * 0.5) * 0.04;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(tilt)
            ..rotateX(tilt * 0.4),
          child: Container(
            width: 340,
            padding: const EdgeInsets.all(36),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              color: Colors.white.withValues(alpha: 0.04),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  blurRadius: 60,
                  spreadRadius: 10,
                  offset: const Offset(0, 20),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 40,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo alan
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.5),
                        blurRadius: 30,
                        spreadRadius: 4,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.restaurant_menu_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 28),
                // Başlık
                const Text(
                  "NEXPOS",
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -1.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Geleceğin NEXPOS Sistemi",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 32),
                // İstatistik rozetleri
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _StatBadge(
                      value: "99%",
                      label: "Uptime",
                      color: const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 16),
                    _StatBadge(
                      value: "<1s",
                      label: "Yanıt",
                      color: const Color(0xFF6366F1),
                    ),
                    const SizedBox(width: 16),
                    _StatBadge(
                      value: "7/24",
                      label: "Destek",
                      color: const Color(0xFFF59E0B),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── _StatBadge ────────────────────────────────────────────────────────────────

class _StatBadge extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatBadge({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.7),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── _FeaturePill ──────────────────────────────────────────────────────────────

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _FeaturePill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── _GridPainter ──────────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  final double progress;
  _GridPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF10B981).withValues(alpha: 0.04)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    const cols = 12;
    const rows = 10;
    final dx = size.width / cols;
    final dy = size.height / rows;
    final offsetY = (progress * dy) % dy;

    for (var c = 0; c <= cols; c++) {
      canvas.drawLine(Offset(c * dx, 0), Offset(c * dx, size.height), paint);
    }
    for (var r = -1; r <= rows + 1; r++) {
      canvas.drawLine(
        Offset(0, r * dy + offsetY),
        Offset(size.width, r * dy + offsetY),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.progress != progress;
}
