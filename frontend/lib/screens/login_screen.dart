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

class _HeroPanel extends StatefulWidget {
  final AnimationController orbController;
  final AnimationController floatController;
  final AnimationController rotateController;

  const _HeroPanel({
    required this.orbController,
    required this.floatController,
    required this.rotateController,
  });

  @override
  State<_HeroPanel> createState() => _HeroPanelState();
}

class _HeroPanelState extends State<_HeroPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _featureController;
  int _activeFeatureIndex = 0;

  final List<Map<String, dynamic>> _features = const [
    {
      "icon": Icons.table_restaurant_rounded,
      "title": "Akıllı Masa & Sipariş",
      "desc": "Masa durumları, hızlı adisyon alma, masa bölme & taşıma işlemleri.",
      "color": Color(0xFF10B981),
      "badge": "Hızlı POS",
    },
    {
      "icon": Icons.print_rounded,
      "title": "Mutfak & Bar Yönlendirme",
      "desc": "Mutfak, Bar ve Kasa yazıcılarına siparişlerin anlık iletimi.",
      "color": Color(0xFF0EA5E9),
      "badge": "Otomatik Print",
    },
    {
      "icon": Icons.analytics_rounded,
      "title": "Canlı Ciro & Z-Raporu",
      "desc": "Anlık günlük ciro analitiği, detaylı gider takibi ve bakiyeler.",
      "color": Color(0xFF6366F1),
      "badge": "Raporlama",
    },
  ];

  @override
  void initState() {
    super.initState();
    _featureController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _activeFeatureIndex = (_activeFeatureIndex + 1) % _features.length;
          });
          _featureController.forward(from: 0.0);
        }
      });
    _featureController.forward();
  }

  @override
  void dispose() {
    _featureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF8FAFC),
            Color(0xFFF1F5F9),
            Color(0xFFE2E8F0),
          ],
        ),
      ),
      child: Stack(
        children: [
          // ── Yumuşak Işık Halesi ──────────────────────────────────────────
          AnimatedBuilder(
            animation: widget.orbController,
            builder: (_, child) {
              final t = widget.orbController.value * 2 * math.pi;
              return Stack(
                children: [
                  Positioned(
                    top: 40 + math.sin(t * 0.7) * 30,
                    left: 40 + math.cos(t * 0.5) * 20,
                    child: _Orb(
                      size: 440,
                      color: const Color(0xFF10B981),
                      alpha: 0.08,
                    ),
                  ),
                  Positioned(
                    bottom: 60 + math.sin(t * 0.4 + 1) * 35,
                    right: 20 + math.cos(t * 0.6) * 20,
                    child: _Orb(
                      size: 360,
                      color: const Color(0xFF0EA5E9),
                      alpha: 0.07,
                    ),
                  ),
                ],
              );
            },
          ),

          // ── Zarif Noktalı Arka Plan ──────────────────────────────────────
          Positioned.fill(
            child: AnimatedBuilder(
              animation: widget.rotateController,
              builder: (_, child) => CustomPaint(
                painter: _LightDotGridPainter(widget.rotateController.value),
              ),
            ),
          ),

          // ── Ortadaki Şık Vitrin Kartı ───────────────────────────────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: AnimatedBuilder(
                  animation: widget.floatController,
                  builder: (_, child) {
                    final floatY = -6.0 + widget.floatController.value * 12.0;
                    return Transform.translate(
                      offset: Offset(0, floatY),
                      child: _HeroLightShowcase(
                        rotateController: widget.rotateController,
                        activeFeature: _features[_activeFeatureIndex],
                        featureIndex: _activeFeatureIndex,
                        totalFeatures: _features.length,
                        onFeatureSelect: (index) {
                          setState(() {
                            _activeFeatureIndex = index;
                          });
                          _featureController.forward(from: 0.0);
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // ── Alt Özellik Rozetleri ─────────────────────────────────────────
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _FeaturePill(
                  icon: Icons.circle,
                  iconSize: 8,
                  label: "Sistem Aktif",
                  color: const Color(0xFF10B981),
                ),
                const SizedBox(width: 12),
                _FeaturePill(
                  icon: Icons.bolt_rounded,
                  label: "Ultra Hızlı",
                  color: const Color(0xFFF59E0B),
                ),
                const SizedBox(width: 12),
                _FeaturePill(
                  icon: Icons.verified_user_rounded,
                  label: "Güvenli Altyapı",
                  color: const Color(0xFF0EA5E9),
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

// ── _HeroLightShowcase ───────────────────────────────────────────────────────

class _HeroLightShowcase extends StatelessWidget {
  final AnimationController rotateController;
  final Map<String, dynamic> activeFeature;
  final int featureIndex;
  final int totalFeatures;
  final ValueChanged<int> onFeatureSelect;

  const _HeroLightShowcase({
    required this.rotateController,
    required this.activeFeature,
    required this.featureIndex,
    required this.totalFeatures,
    required this.onFeatureSelect,
  });

  @override
  Widget build(BuildContext context) {
    final featureColor = activeFeature["color"] as Color;

    return Container(
      width: 420,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: Colors.white,
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 36,
            spreadRadius: 2,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Üst Logo & Başlık ──────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.restaurant_menu_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          "NEXPOS",
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFF10B981).withValues(alpha: 0.25),
                            ),
                          ),
                          child: const Text(
                            "v2.0",
                            style: TextStyle(
                              color: Color(0xFF059669),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      "Akıllı Restoran & POS Otomasyonu",
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Canlı Özellik Kartı ───────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: featureColor.withValues(alpha: 0.05),
              border: Border.all(
                color: featureColor.withValues(alpha: 0.2),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: featureColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        activeFeature["icon"] as IconData,
                        color: featureColor,
                        size: 22,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: featureColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        activeFeature["badge"] as String,
                        style: TextStyle(
                          color: featureColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  activeFeature["title"] as String,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  activeFeature["desc"] as String,
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── İndikatörler ──────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(totalFeatures, (index) {
              final isSelected = index == featureIndex;
              return GestureDetector(
                onTap: () => onFeatureSelect(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isSelected ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    color: isSelected
                        ? featureColor
                        : const Color(0xFFCBD5E1),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ── _FeaturePill ──────────────────────────────────────────────────────────────

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final double? iconSize;
  final String label;
  final Color color;

  const _FeaturePill({
    required this.icon,
    this.iconSize,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize ?? 14, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF334155),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── _LightDotGridPainter ──────────────────────────────────────────────────────

class _LightDotGridPainter extends CustomPainter {
  final double progress;
  _LightDotGridPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()..style = PaintingStyle.fill;
    const spacing = 32.0;
    final cols = (size.width / spacing).ceil();
    final rows = (size.height / spacing).ceil();

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final maxDist = math.sqrt(centerX * centerX + centerY * centerY);

    for (var i = 0; i <= cols; i++) {
      for (var j = 0; j <= rows; j++) {
        final x = i * spacing;
        final y = j * spacing;
        final dist = math.sqrt(
          math.pow(x - centerX, 2) + math.pow(y - centerY, 2),
        );
        final opacity = (1.0 - (dist / maxDist)).clamp(0.02, 0.12);

        dotPaint.color = const Color(0xFF0F172A).withValues(alpha: opacity);
        canvas.drawCircle(Offset(x, y), 1.5, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_LightDotGridPainter old) => old.progress != progress;
}


