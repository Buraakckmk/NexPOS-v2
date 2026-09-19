import "package:flutter/material.dart";
import "package:dio/dio.dart";
import "package:intl/intl.dart";
import "../models/payment_models.dart";
import "../services/api_client.dart";

class XReportPreviewDialog extends StatefulWidget {
  final XReportData data;

  const XReportPreviewDialog({super.key, required this.data});

  @override
  State<XReportPreviewDialog> createState() => _XReportPreviewDialogState();
}

class _XReportPreviewDialogState extends State<XReportPreviewDialog> {
  bool _isPrinting = false;

  DateTime _safeParseDate(String value) {
    final parsed = DateTime.tryParse(value);
    return parsed ?? DateTime.now();
  }

  Future<void> _printAgain() async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);
    try {
      final response = await ApiClient.dio.post(
        "/admin/x-report/print",
        options: Options(extra: {"showGlobalError": false}),
      );
      final data = response.data as Map<String, dynamic>;
      final reportData = XReportData.fromJson(
        data["data"] as Map<String, dynamic>,
      );
      final printedAt = reportData.printedAt ?? reportData.reportDate;

      if (!mounted) return;
      final date = _safeParseDate(printedAt);
      final time = DateFormat("HH:mm").format(date);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("X Raporu yazdırıldı: $time"),
          backgroundColor: const Color(0xFF166534),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("X Raporu yazdırılamadı."),
          backgroundColor: Color(0xFFB91C1C),
        ),
      );
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: "tr_TR", symbol: "₺");
    final reportDate = _safeParseDate(
      widget.data.printedAt ?? widget.data.reportDate,
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Theme(
        data: ThemeData.light(useMaterial3: true).copyWith(
          colorScheme: const ColorScheme.light(
            surface: Colors.white,
            onSurface: Color(0xFF0F172A),
          ),
          textTheme: ThemeData.light().textTheme.apply(
            bodyColor: const Color(0xFF0F172A),
            displayColor: const Color(0xFF0F172A),
          ),
        ),
        child: Container(
          width: 400,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "X Raporu Önizleme",
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 20, color: Color(0xFF0F172A)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // Paper Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Text(
                        "*** X RAPORU ***",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Kafe: KAHVE DERYASI / MERKEZ",
                        style: TextStyle(fontSize: 11, color: Color(0xFF475569)),
                      ),
                      Text(
                        "Tarih: ${DateFormat("dd.MM.yyyy HH:mm").format(reportDate)}",
                        style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                      ),
                      const Divider(height: 16),

                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "İŞLEMLER VE TUTARLAR:",
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildRow(
                        "Nakit:",
                        currencyFormat.format(widget.data.cashTotal),
                      ),
                      _buildRow(
                        "Kart:",
                        currencyFormat.format(widget.data.cardTotal),
                      ),
                      _buildRow(
                        "Toplam:",
                        currencyFormat.format(widget.data.totalRevenue),
                      ),
                      const Divider(height: 16),

                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "IPTAL/IADE/INDIRIM:",
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildRow(
                        "İndirim:",
                        currencyFormat.format(widget.data.totalDiscounts),
                      ),
                      const Divider(height: 16),

                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "KASA DETAYLARI:",
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildRow(
                        "Gider:",
                        currencyFormat.format(widget.data.totalExpenses),
                      ),
                      _buildRow(
                        "Kasa:",
                        currencyFormat.format(widget.data.generalCashRegister),
                      ),
                      _buildRow(
                        "Nakit:",
                        currencyFormat.format(widget.data.generalCashStatus),
                      ),
                      const Divider(height: 16),

                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "İSTATİSTİKLER:",
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildRow(
                        "Adet/Kişi:",
                        "${widget.data.totalOrders} / ${widget.data.averageGuestCount}",
                      ),
                      _buildRow(
                        "Ort. Süre (Dk):",
                        "${widget.data.averageDuration} dk",
                      ),
                    ],
                  ),
                ),
              ),

              // Action Buttons
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, size: 16, color: Color(0xFF0F172A)),
                        label: const Text(
                          "Kapat",
                          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isPrinting ? null : _printAgain,
                        icon: _isPrinting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF0F172A),
                                ),
                              )
                            : const Icon(Icons.print, size: 16, color: Color(0xFF0F172A)),
                        label: const Text(
                          "Yazdır",
                          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDCFCE7),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(
    String label,
    String value, {
    bool bold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              color: color ?? const Color(0xFF1E293B),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
              color: color ?? const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}
