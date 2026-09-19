import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'api_client.dart';
import 'local_db_service.dart';

class SyncService {
  final LocalDbService _localDb = LocalDbService();
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isSyncing = false;

  void start() {
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      if (results.isNotEmpty && results.first != ConnectivityResult.none) {
        _syncQueue();
      }
    });
  }

  void stop() {
    _subscription?.cancel();
  }

  Future<void> _syncQueue() async {
    if (_isSyncing) return;
    _isSyncing = true;

    if (!ApiClient.hasAccessToken) {
      _isSyncing = false;
      return;
    }

    final queue = await _localDb.getQueue();
    for (var item in queue) {
      try {
        final id = item['id'];
        final endpoint = item['endpoint'];
        final method = item['method'];
        final body = item['body'] != null ? jsonDecode(item['body']) : null;

        Response response;
        if (method == 'POST') {
          response = await ApiClient.dio.post(endpoint, data: body);
        } else if (method == 'PUT') {
          response = await ApiClient.dio.put(endpoint, data: body);
        } else if (method == 'DELETE') {
          response = await ApiClient.dio.delete(endpoint, data: body);
        } else {
          continue;
        }

        if (response.statusCode != null && response.statusCode! < 300) {
          await _localDb.removeFromQueue(id);
        }
      } catch (e) {
        // Hata durumunda kuyrukta kalsın, bir sonraki denemede tekrar deneriz.
        debugPrint("Sync failed for item ${item['id']}: $e");
        break; // Bir hata aldıysak muhtemelen hala ağ sorunu var, durabiliriz.
      }
    }

    _isSyncing = false;
  }

  // Manuel tetikleme için
  Future<void> forceSync() => _syncQueue();
}
