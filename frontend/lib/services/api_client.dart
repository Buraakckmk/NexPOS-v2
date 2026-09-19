import "package:dio/dio.dart";
import "package:flutter/foundation.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../core/constants/api_constants.dart";
import "app_feedback_service.dart";
import "local_db_service.dart";
import "local_error_log_service.dart";

class ApiClient {
  ApiClient._();

  static const String _urgentSupportText =
      "Acil: Destek birimi ile iletişime geçin.";

  static String? _accessToken;

  static void setAccessToken(String? token) {
    final normalized = token?.trim();
    _accessToken = normalized == null || normalized.isEmpty ? null : normalized;
  }

  static bool get hasAccessToken =>
      _accessToken != null && _accessToken!.isNotEmpty;

  static bool get _isMobilePlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  static bool _isConnectionIssue(DioException error) {
    return error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.unknown;
  }

  static Uri? _tryParseBaseUrl(RequestOptions options) {
    try {
      return Uri.parse(options.baseUrl);
    } catch (_) {
      return null;
    }
  }

  static int? _extractPort(RequestOptions options) {
    final uri = _tryParseBaseUrl(options);
    if (uri == null) return null;
    return uri.hasPort ? uri.port : null;
  }

  static String? _buildAlternateBaseUrl(RequestOptions options) {
    final uri = _tryParseBaseUrl(options);
    if (uri == null) return null;
    if (!uri.hasPort) return null;
    if (uri.port != 3001 && uri.port != 3002) return null;

    final nextPort = uri.port == 3001 ? 3002 : 3001;
    return uri.replace(port: nextPort).toString();
  }

  static void configureBaseUrl([String? baseUrl]) {
    dio.options.baseUrl = baseUrl ?? ApiConstants.baseUrl;
  }

  static String describeDioError(DioException error) {
    final responseData = error.response?.data;
    if (responseData is Map<String, dynamic>) {
      final message = responseData["message"]?.toString().trim();
      if (message != null &&
          message.isNotEmpty &&
          !_containsTechnicalTerms(message)) {
        return message;
      }
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return "Sisteme şu an ulaşılamıyor. Lütfen kısa süre sonra tekrar deneyin. $_urgentSupportText";
      case DioExceptionType.connectionError:
        return "Sistem bağlantısı kurulamadı. İşlem şu an tamamlanamadı. $_urgentSupportText";
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode != null && statusCode >= 500) {
          return "Sistem şu an hizmet veremiyor. $_urgentSupportText";
        }
        return "İşlem şu an tamamlanamadı. Lütfen tekrar deneyin.";
      case DioExceptionType.cancel:
        return "İstek iptal edildi.";
      default:
        return "Beklenmeyen bir ağ hatası oluştu.";
    }
  }

  static bool _containsTechnicalTerms(String message) {
    final lower = message.toLowerCase();
    return lower.contains("token") ||
        lower.contains("backend") ||
        lower.contains("api") ||
        lower.contains("http") ||
        lower.contains("server") ||
        lower.contains("sunucu");
  }

  static final Dio dio =
      Dio(
          BaseOptions(
            baseUrl: ApiConstants.baseUrl,
            connectTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 6),
            sendTimeout: const Duration(seconds: 6),
            headers: {"Content-Type": "application/json"},
          ),
        )
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) async {
              final memoryToken = _accessToken;
              if (memoryToken != null && memoryToken.isNotEmpty) {
                options.headers["Authorization"] = "Bearer $memoryToken";
              } else if (_isMobilePlatform) {
                try {
                  final prefs = await SharedPreferences.getInstance();
                  final token = prefs.getString("access_token");
                  if (token != null && token.isNotEmpty) {
                    options.headers["Authorization"] = "Bearer $token";
                  }
                } catch (_) {}
              }

              if (options.method != 'GET' && !options.headers.containsKey('X-Request-ID')) {
                options.headers['X-Request-ID'] = 'req_${DateTime.now().millisecondsSinceEpoch}_${options.path.replaceAll('/', '_')}';
              }
              handler.next(options);
            },
            onError: (error, handler) async {
              final requestOptions = error.requestOptions;
              final hasRetriedAltPort =
                  requestOptions.extra["altPortRetry"] == true;

              if (_isConnectionIssue(error) && !hasRetriedAltPort) {
                final alternateBaseUrl = _buildAlternateBaseUrl(requestOptions);
                if (alternateBaseUrl != null) {
                  final originalBaseUrl = dio.options.baseUrl;
                  try {
                    dio.options.baseUrl = alternateBaseUrl;
                    final retryResponse = await dio.request(
                      requestOptions.path,
                      data: requestOptions.data,
                      queryParameters: requestOptions.queryParameters,
                      options: Options(
                        method: requestOptions.method,
                        headers: requestOptions.headers,
                        responseType: requestOptions.responseType,
                        contentType: requestOptions.contentType,
                        followRedirects: requestOptions.followRedirects,
                        receiveDataWhenStatusError:
                            requestOptions.receiveDataWhenStatusError,
                        validateStatus: requestOptions.validateStatus,
                        sendTimeout: requestOptions.sendTimeout,
                        receiveTimeout: requestOptions.receiveTimeout,
                        extra: {
                          ...requestOptions.extra,
                          "altPortRetry": true,
                          "showGlobalError": false,
                        },
                      ),
                      cancelToken: requestOptions.cancelToken,
                      onReceiveProgress: requestOptions.onReceiveProgress,
                      onSendProgress: requestOptions.onSendProgress,
                    );

                    await LocalErrorLogService.instance.log(
                      source: "api_auto_port_switch",
                      message:
                          "Bağlantı portu otomatik değiştirildi: ${_extractPort(requestOptions)} -> ${Uri.parse(alternateBaseUrl).port}",
                      details:
                          "${requestOptions.method} ${requestOptions.path}",
                      stackTrace: null,
                    );

                    return handler.resolve(retryResponse);
                  } catch (_) {
                    dio.options.baseUrl = originalBaseUrl;
                  }
                }
              }

              await LocalErrorLogService.instance.log(
                source: "api_error",
                message: describeDioError(error),
                details:
                    "${requestOptions.method} ${requestOptions.path} | "
                    "status=${error.response?.statusCode} type=${error.type}",
                stackTrace: error.stackTrace,
              );

              // Eğer bağlantı hatasıysa ve GET değilse kuyruğa atalım
              if (_isConnectionIssue(error) && requestOptions.method != 'GET') {
                final db = LocalDbService();
                await db.addToQueue(
                  requestOptions.path,
                  requestOptions.method,
                  requestOptions.data,
                );

                return handler.resolve(
                  Response(
                    requestOptions: requestOptions,
                    data: {
                      'message':
                          'Bağlantı sorunu nedeniyle çevrimdışı kaydedildi.',
                      'offline': true,
                      // Mock data to prevent crashes in OrderProvider
                      'order': {
                        'id':
                            'offline-${DateTime.now().millisecondsSinceEpoch}',
                      },
                      'success': true,
                    },
                    statusCode: 200,
                  ),
                );
              }

              final shouldShowGlobalError =
                  requestOptions.extra["showGlobalError"] != false;
              if (shouldShowGlobalError) {
                AppFeedbackService.showError(describeDioError(error));
              }
              handler.next(error);
            },
          ),
        );
}
