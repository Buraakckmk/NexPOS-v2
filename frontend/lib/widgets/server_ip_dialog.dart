import "package:flutter/material.dart";
import "package:dio/dio.dart";
import "../core/constants/api_constants.dart";
import "../services/api_client.dart";
import "../services/socket_service.dart";

class ServerIpDialog extends StatefulWidget {
  const ServerIpDialog({super.key});

  @override
  State<ServerIpDialog> createState() => _ServerIpDialogState();
}

class _ServerIpDialogState extends State<ServerIpDialog> {
  final _ipController = TextEditingController();
  bool _isSaving = false;
  bool _isTesting = false;
  String? _testStatus;

  @override
  void initState() {
    super.initState();
    _ipController.text = ApiConstants.serverHost;
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _handleTest() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) return;

    setState(() {
      _isTesting = true;
      _testStatus = "Bağlanıyor...";
    });

    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
        ),
      );

      final response = await dio
          .get("http://$ip:${ApiConstants.apiPort}/api/auth/status")
          .timeout(const Duration(seconds: 4));

      if (mounted) {
        setState(() {
          _isTesting = false;
          _testStatus = response.statusCode == 200
              ? "Bağlantı Başarılı! ✅"
              : "Sunucu hatası: ${response.statusCode}";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTesting = false;
          _testStatus =
              "Bağlantı Başarısız! ❌\n(IP doğru mu? Bilgisayar ve telefon aynı ağda mı?)";
        });
      }
    }
  }

  Future<void> _handleSave() async {
    final newIp = _ipController.text.trim();
    if (newIp.isEmpty) return;

    setState(() => _isSaving = true);

    final success = await ApiConstants.setServerHost(newIp);

    if (success) {
      // Servisleri yeni IP ile yapılandır
      ApiClient.configureBaseUrl();
      SocketService().disconnect();
      SocketService().connect();
    }

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Sunucu IP adresi güncellendi. Uygulamayı yeniden başlatmanız önerilir.",
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("IP adresi kaydedilemedi!"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFFFFFFFF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      title: const Text(
        "Sunucu Bağlantı Ayarları",
        style: TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Sunucu IP Adresi (Örn: 192.168.1.100)",
            style: TextStyle(color: Color(0xFF71717A), fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ipController,
            style: const TextStyle(color: Color(0xFF0F172A)),
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: "0.0.0.0",
              hintStyle: const TextStyle(color: Color(0xFF3F3F46)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF10B981)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Not: Telefon ve sunucu aynı WiFi ağına bağlı olmalıdır.",
            style: TextStyle(
              color: Color(0xFFF59E0B),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
          if (_testStatus != null) ...[
            const SizedBox(height: 12),
            Text(
              _testStatus!,
              style: TextStyle(
                color: _testStatus!.contains("✅") ? Colors.green : Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isTesting || _isSaving ? null : _handleTest,
          child: _isTesting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text(
                  "Bağlantıyı Test Et",
                  style: TextStyle(color: Color(0xFF3B82F6)),
                ),
        ),
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text(
            "İptal",
            style: TextStyle(color: Color(0xFF71717A)),
          ),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _handleSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDCFCE7),
            foregroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF0F172A),
                  ),
                )
              : const Text("Kaydet"),
        ),
      ],
    );
  }
}
