import 'package:socket_io_client/socket_io_client.dart' as io;
import '../core/constants/api_constants.dart';
import 'package:flutter/foundation.dart';
import 'api_client.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  bool _triedAlternatePort = false;
  final ValueNotifier<bool> connectionStatus = ValueNotifier<bool>(false);
  final ValueNotifier<io.Socket?> socketNotifier = ValueNotifier<io.Socket?>(
    null,
  );

  io.Socket? get socket => _socket;
  bool get isConnected => _socket?.connected ?? false;

  String _resolveSocketBaseUrl() {
    final base = ApiClient.dio.options.baseUrl.isNotEmpty
        ? ApiClient.dio.options.baseUrl
        : ApiConstants.baseUrl;
    final uri = Uri.parse(base);
    return "${uri.scheme}://${uri.host}:${uri.port}";
  }

  String? _alternateSocketBaseUrl(String currentBase) {
    final uri = Uri.parse(currentBase);
    if (!uri.hasPort) return null;
    if (uri.port != 3001 && uri.port != 3002) return null;
    final nextPort = uri.port == 3001 ? 3002 : 3001;
    return uri.replace(port: nextPort).toString();
  }

  io.Socket _buildSocket(String socketBaseUrl) {
    return io.io(
      socketBaseUrl,
      io.OptionBuilder()
          .setTransports(["websocket"])
          .enableReconnection()
          .setReconnectionAttempts(2147483647)
          .setReconnectionDelay(1000)
          .build(),
    );
  }

  void connect() {
    if (_socket != null && _socket!.connected) return;

    if (_socket != null && !_socket!.connected) {
      _socket!.connect();
      return;
    }

    final socketBaseUrl = _resolveSocketBaseUrl();

    debugPrint("Connecting to socket at $socketBaseUrl");

    _socket = _buildSocket(socketBaseUrl);
    socketNotifier.value = _socket;

    // Connection timeout ekle - eğer 10 saniye içinde bağlanmazsa alternatif port dene
    Future.delayed(const Duration(seconds: 10), () {
      if (_socket != null && !_socket!.connected && !_triedAlternatePort) {
        debugPrint("Socket connection timeout, trying alternate port");
        final alt = _alternateSocketBaseUrl(socketBaseUrl);
        if (alt != null) {
          _triedAlternatePort = true;
          try {
            _socket?.dispose();
          } catch (_) {}
          _socket = _buildSocket(alt);
          socketNotifier.value = _socket;
          debugPrint("Retrying socket at $alt");
          _setupSocketListeners();
        }
      }
    });

    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    _socket?.onConnect((_) {
      debugPrint("Socket connected");
      connectionStatus.value = true;
    });

    _socket?.onDisconnect((_) {
      debugPrint("Socket disconnected");
      connectionStatus.value = false;
    });

    _socket?.onConnectError((e) {
      debugPrint("Socket connect error: $e");
      connectionStatus.value = false;

      if (_triedAlternatePort) return;
      final socketBaseUrl = _resolveSocketBaseUrl();
      final alt = _alternateSocketBaseUrl(socketBaseUrl);
      if (alt == null) return;

      _triedAlternatePort = true;
      try {
        _socket?.dispose();
      } catch (_) {}
      _socket = _buildSocket(alt);
      socketNotifier.value = _socket;
      debugPrint("Retrying socket at $alt");
      _setupSocketListeners();
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
    socketNotifier.value = null;
    _triedAlternatePort = false;
    connectionStatus.value = false;
  }

  void reconnectIfNeeded() {
    if (_socket == null) {
      connect();
      return;
    }

    if (!(_socket?.connected ?? false)) {
      _socket?.connect();
    }
  }
}
