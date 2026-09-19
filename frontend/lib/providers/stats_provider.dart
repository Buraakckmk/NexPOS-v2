import "dart:async";
import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:socket_io_client/socket_io_client.dart" as io;
import "../services/api_client.dart";
import "../services/socket_service.dart";

class DailySummary {
  final double instantRevenue;
  final int totalOrders;
  final int closedOrders;
  final double closedRevenue;
  final int averageDuration;
  final String starProductName;
  final double starProductQty;

  DailySummary({
    required this.instantRevenue,
    required this.totalOrders,
    required this.closedOrders,
    required this.closedRevenue,
    required this.averageDuration,
    required this.starProductName,
    required this.starProductQty,
  });

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? "").toString()) ?? 0.0;
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? "0").toString()) ?? 0;
  }

  factory DailySummary.fromJson(Map<String, dynamic> json) {
    final star = json["starProduct"] as Map<String, dynamic>? ?? {};
    return DailySummary(
      instantRevenue: _toDouble(json["instantRevenue"]),
      totalOrders: _toInt(json["totalOrders"]),
      closedOrders: _toInt(json["closedOrders"]),
      closedRevenue: _toDouble(json["closedRevenue"]),
      averageDuration: _toInt(json["averageDuration"]),
      starProductName: star["name"] as String? ?? "Henüz yok",
      starProductQty: _toDouble(star["quantity"]),
    );
  }

  factory DailySummary.empty() => DailySummary(
    instantRevenue: 0.0,
    totalOrders: 0,
    closedOrders: 0,
    closedRevenue: 0.0,
    averageDuration: 0,
    starProductName: "...",
    starProductQty: 0.0,
  );
}

class StatsProvider with ChangeNotifier {
  DailySummary? _summary;
  bool _isLoading = false;
  bool _isFetching = false;
  Timer? _pollingTimer;
  io.Socket? _boundSocket;

  DailySummary? get summary => _summary;
  bool get isLoading => _isLoading;

  StatsProvider() {
    final socketService = SocketService();
    socketService.socketNotifier.addListener(_onSocketChanged);
    socketService.connectionStatus.addListener(_onConnectionChanged);
    _bindSocket(socketService.socket);
  }

  void _onRealtimeRefresh(dynamic _) {
    fetchDailySummary();
  }

  void _bindSocket(io.Socket? socket) {
    if (identical(_boundSocket, socket)) return;

    if (_boundSocket != null) {
      _boundSocket!.off("tables:refresh", _onRealtimeRefresh);
      _boundSocket!.off("orders:refresh", _onRealtimeRefresh);
    }

    _boundSocket = socket;
    if (_boundSocket != null) {
      _boundSocket!.on("tables:refresh", _onRealtimeRefresh);
      _boundSocket!.on("orders:refresh", _onRealtimeRefresh);
    }
  }

  void _onSocketChanged() {
    _bindSocket(SocketService().socketNotifier.value);
  }

  void _onConnectionChanged() {
    if (SocketService().connectionStatus.value) {
      fetchDailySummary();
    }
  }

  void startPolling() {
    _pollingTimer?.cancel();
    fetchDailySummary(); // İlk çekim
    _pollingTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      fetchDailySummary();
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> fetchDailySummary() async {
    if (_isFetching) return;
    _isFetching = true;

    try {
      if (_summary == null) _isLoading = true;
      notifyListeners();

      final response = await ApiClient.dio.get(
        "/stats/daily-summary",
        options: Options(extra: {"showGlobalError": false}),
      );
      _summary = DailySummary.fromJson(response.data);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint("Stats fetch error: $e");
      _isLoading = false;
      notifyListeners();
    } finally {
      _isFetching = false;
    }
  }

  @override
  void dispose() {
    SocketService().socketNotifier.removeListener(_onSocketChanged);
    SocketService().connectionStatus.removeListener(_onConnectionChanged);
    if (_boundSocket != null) {
      _boundSocket!.off("tables:refresh", _onRealtimeRefresh);
      _boundSocket!.off("orders:refresh", _onRealtimeRefresh);
      _boundSocket = null;
    }
    stopPolling();
    super.dispose();
  }
}
