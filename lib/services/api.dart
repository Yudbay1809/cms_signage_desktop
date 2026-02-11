import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import '../models/types.dart';

class ApiService {
  String baseUrl;
  String? apiKey;
  static const Duration _timeout = Duration(seconds: 8);
  static const List<Duration> _retryDelays = [
    Duration(milliseconds: 400),
    Duration(milliseconds: 1000),
  ];
  ApiService(this.baseUrl, {this.apiKey});

  String _formatHttpError(http.Response res) {
    final reason = res.reasonPhrase ?? '';
    final body = res.body.trim();
    if (body.isEmpty) return '${res.statusCode} $reason'.trim();
    return '${res.statusCode} $reason - $body'.trim();
  }

  Uri _uri(String path, [Map<String, String>? queryParameters]) {
    final uri = path.startsWith('http')
        ? Uri.parse(path)
        : Uri.parse(baseUrl).resolve(path);
    if (queryParameters == null || queryParameters.isEmpty) return uri;
    return uri.replace(
      queryParameters: {...uri.queryParameters, ...queryParameters},
    );
  }

  Map<String, String> _headers() {
    if (apiKey == null || apiKey!.isEmpty) return {};
    return {'X-API-Key': apiKey!};
  }

  bool _isTransient(Object error) =>
      error is TimeoutException ||
      error is SocketException ||
      error is HttpException;

  Future<http.Response> _sendWithRetry(
    Future<http.Response> Function() call,
  ) async {
    Object? lastError;
    for (var attempt = 0; attempt <= _retryDelays.length; attempt++) {
      try {
        final res = await call().timeout(_timeout);
        if (res.statusCode >= 500 && attempt < _retryDelays.length) {
          await Future.delayed(_retryDelays[attempt]);
          continue;
        }
        return res;
      } catch (error) {
        lastError = error;
        if (!_isTransient(error) || attempt >= _retryDelays.length) rethrow;
        await Future.delayed(_retryDelays[attempt]);
      }
    }
    throw Exception('Request gagal: $lastError');
  }

  Future<List<DeviceInfo>> listDevices() async {
    final res = await _sendWithRetry(
      () => http.get(_uri('/devices'), headers: _headers()),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to list devices: ${_formatHttpError(res)}');
    }
    final data = jsonDecode(res.body) as List<dynamic>;
    return data.map((e) => DeviceInfo.fromJson(e)).toList();
  }

  Future<DeviceInfo> registerDevice({
    required String name,
    String location = '',
    String orientation = 'portrait',
  }) async {
    final res = await _sendWithRetry(
      () => http.post(
        _uri('/devices/register', {
          'name': name,
          'location': location,
          'orientation': orientation,
        }),
        headers: _headers(),
      ),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to register device: ${_formatHttpError(res)}');
    }
    return DeviceInfo.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> updateDeviceOrientation(
    String deviceId,
    String orientation,
  ) async {
    final res = await _sendWithRetry(
      () => http.put(
        _uri('/devices/$deviceId', {'orientation': orientation}),
        headers: _headers(),
      ),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to update device: ${_formatHttpError(res)}');
    }
  }

  Future<void> deleteDevice(String deviceId) async {
    final res = await _sendWithRetry(
      () => http.delete(_uri('/devices/$deviceId'), headers: _headers()),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to delete device: ${_formatHttpError(res)}');
    }
  }

  Future<List<MediaInfo>> listMedia() async {
    final res = await _sendWithRetry(
      () => http.get(_uri('/media'), headers: _headers()),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to list media: ${_formatHttpError(res)}');
    }
    final data = jsonDecode(res.body) as List<dynamic>;
    return data.map((e) => MediaInfo.fromJson(e)).toList();
  }

  Future<MediaPageInfo> listMediaPage({
    int offset = 0,
    int limit = 120,
    String? query,
    String? type,
  }) async {
    final params = <String, String>{'offset': '$offset', 'limit': '$limit'};
    final keyword = (query ?? '').trim();
    if (keyword.isNotEmpty) params['q'] = keyword;
    if (type != null && type.isNotEmpty && type != 'all') params['type'] = type;

    final res = await _sendWithRetry(
      () => http.get(_uri('/media/page', params), headers: _headers()),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to list media page: ${_formatHttpError(res)}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final itemsRaw = (data['items'] as List<dynamic>? ?? const []);
    final items = itemsRaw
        .map((e) => MediaInfo.fromJson(e as Map<String, dynamic>))
        .toList();
    return MediaPageInfo(
      items: items,
      total: (data['total'] as num?)?.toInt() ?? items.length,
      offset: (data['offset'] as num?)?.toInt() ?? offset,
      limit: (data['limit'] as num?)?.toInt() ?? limit,
    );
  }

  Future<Map<String, dynamic>> fetchDeviceConfigRaw(String deviceId) async {
    final res = await _sendWithRetry(
      () => http.get(_uri('/devices/$deviceId/config'), headers: _headers()),
    );
    if (res.statusCode != 200) {
      throw Exception(
        'Failed to fetch device config: ${_formatHttpError(res)}',
      );
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<ScreenInfo>> listScreensForDevice(String deviceId) async {
    final data = await fetchDeviceConfigRaw(deviceId);
    final rawScreens = data['screens'];
    if (rawScreens is! List) return [];
    final screens = rawScreens
        .whereType<Map>()
        .map(
          (s) => ScreenInfo(
            id: '${s['screen_id']}',
            name: (s['name'] ?? '').toString(),
            activePlaylistId: s['active_playlist_id']?.toString(),
            gridPreset: (s['grid_preset'] ?? '1x1').toString(),
            transitionDurationSec: (s['transition_duration_sec'] as num?)
                ?.toInt(),
          ),
        )
        .toList();
    return screens;
  }

  Future<void> updateScreenSettings({
    required String screenId,
    String? name,
    String? activePlaylistId,
    String? gridPreset,
    int? transitionDurationSec,
  }) async {
    final query = <String, String>{};
    if (name != null) query['name'] = name;
    if (activePlaylistId != null)
      query['active_playlist_id'] = activePlaylistId;
    if (gridPreset != null) query['grid_preset'] = gridPreset;
    if (transitionDurationSec != null) {
      query['transition_duration_sec'] = transitionDurationSec.toString();
    }
    final res = await _sendWithRetry(
      () => http.put(_uri('/screens/$screenId', query), headers: _headers()),
    );
    if (res.statusCode != 200) {
      throw Exception('Update screen failed: ${_formatHttpError(res)}');
    }
  }

  Future<List<PlaylistInfo>> listPlaylists(String screenId) async {
    final res = await _sendWithRetry(
      () => http.get(
        _uri('/playlists', {'screen_id': screenId}),
        headers: _headers(),
      ),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to list playlists: ${_formatHttpError(res)}');
    }
    final data = jsonDecode(res.body) as List<dynamic>;
    return data
        .map(
          (e) => PlaylistInfo(
            id: e['id'],
            name: e['name'] ?? '',
            isFlashSale: e['is_flash_sale'] == true,
          ),
        )
        .toList();
  }

  Future<MediaInfo> uploadMedia({
    required File file,
    required String name,
    required String type,
    required int durationSec,
    void Function(double progress)? onProgress,
  }) async {
    final dio = Dio();
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path),
      'name': name,
      'type': type,
      'duration_sec': durationSec.toString(),
    });

    final res = await dio.post(
      _uri('/media/upload').toString(),
      data: formData,
      options: Options(headers: _headers()),
      onSendProgress: (sent, total) {
        if (total > 0 && onProgress != null) {
          onProgress(sent / total);
        }
      },
    );

    if (res.statusCode != 200) {
      throw Exception('Upload failed: ${res.statusCode}');
    }

    return MediaInfo.fromJson(
      res.data is String ? jsonDecode(res.data) : res.data,
    );
  }

  Future<void> deleteMedia(String mediaId) async {
    final res = await _sendWithRetry(
      () => http.delete(_uri('/media/$mediaId'), headers: _headers()),
    );
    if (res.statusCode != 200) {
      throw Exception('Delete media failed: ${_formatHttpError(res)}');
    }
  }

  Future<PlaylistInfo> createPlaylist(
    String screenId,
    String name, {
    bool isFlashSale = false,
  }) async {
    final query = <String, String>{'screen_id': screenId, 'name': name};
    if (isFlashSale) query['is_flash_sale'] = 'true';
    final res = await _sendWithRetry(
      () => http.post(_uri('/playlists', query), headers: _headers()),
    );
    if (res.statusCode != 200) {
      throw Exception('Create playlist failed: ${_formatHttpError(res)}');
    }
    final data = jsonDecode(res.body);
    return PlaylistInfo(
      id: data['id'],
      name: data['name'] ?? name,
      isFlashSale: data['is_flash_sale'] == true,
    );
  }

  Future<void> deletePlaylist(String playlistId) async {
    final res = await _sendWithRetry(
      () => http.delete(_uri('/playlists/$playlistId'), headers: _headers()),
    );
    if (res.statusCode != 200) {
      throw Exception('Delete playlist failed: ${_formatHttpError(res)}');
    }
  }

  Future<void> updatePlaylistName(String playlistId, String name) async {
    final res = await _sendWithRetry(
      () => http.put(
        _uri('/playlists/$playlistId', {'name': name}),
        headers: _headers(),
      ),
    );
    if (res.statusCode != 200) {
      throw Exception('Update playlist failed: ${_formatHttpError(res)}');
    }
  }

  Future<void> updatePlaylistFlashSale(
    String playlistId,
    bool isFlashSale,
  ) async {
    final res = await _sendWithRetry(
      () => http.put(
        _uri('/playlists/$playlistId', {
          'is_flash_sale': isFlashSale ? 'true' : 'false',
        }),
        headers: _headers(),
      ),
    );
    if (res.statusCode != 200) {
      throw Exception(
        'Update playlist flash sale failed: ${_formatHttpError(res)}',
      );
    }
  }

  Future<void> updatePlaylistFlashMeta(
    String playlistId, {
    required String? note,
    required int? countdownSec,
    String? flashItemsJson,
  }) async {
    final params = <String, String>{};
    if (note != null) params['flash_note'] = note;
    if (countdownSec != null) {
      params['flash_countdown_sec'] = countdownSec.toString();
    }
    if (flashItemsJson != null) {
      params['flash_items_json'] = flashItemsJson;
    }
    final res = await _sendWithRetry(
      () =>
          http.put(_uri('/playlists/$playlistId', params), headers: _headers()),
    );
    if (res.statusCode != 200) {
      throw Exception(
        'Update playlist flash meta failed: ${_formatHttpError(res)}',
      );
    }
  }

  Future<void> addPlaylistItem({
    required String playlistId,
    required String mediaId,
    required int order,
    int? durationSec,
  }) async {
    final query = <String, String>{
      'media_id': mediaId,
      'order': order.toString(),
      'enabled': 'true',
    };
    if (durationSec != null) query['duration_sec'] = durationSec.toString();
    final res = await _sendWithRetry(
      () => http.post(
        _uri('/playlists/$playlistId/items', query),
        headers: _headers(),
      ),
    );
    if (res.statusCode != 200) {
      throw Exception('Add item failed: ${_formatHttpError(res)}');
    }
  }

  Future<List<PlaylistItemInfo>> listPlaylistItems(String playlistId) async {
    final res = await _sendWithRetry(
      () => http.get(_uri('/playlists/$playlistId/items'), headers: _headers()),
    );
    if (res.statusCode != 200) {
      throw Exception('List playlist items failed: ${_formatHttpError(res)}');
    }
    final data = jsonDecode(res.body) as List<dynamic>;
    return data
        .map((e) => PlaylistItemInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createSchedule({
    required String screenId,
    required String playlistId,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    String? note,
    int? countdownSec,
  }) async {
    final params = <String, String>{
      'screen_id': screenId,
      'playlist_id': playlistId,
      'day_of_week': dayOfWeek.toString(),
      'start_time': startTime,
      'end_time': endTime,
    };
    final normalizedNote = (note ?? '').trim();
    if (normalizedNote.isNotEmpty) params['note'] = normalizedNote;
    if (countdownSec != null && countdownSec > 0) {
      params['countdown_sec'] = countdownSec.toString();
    }
    final res = await _sendWithRetry(
      () => http.post(_uri('/schedules', params), headers: _headers()),
    );
    if (res.statusCode != 200) {
      throw Exception('Create schedule failed: ${_formatHttpError(res)}');
    }
  }

  Future<void> upsertFlashSaleNow({
    required String deviceId,
    required String note,
    required int countdownSec,
    required String productsJson,
  }) async {
    final res = await _sendWithRetry(
      () => http.put(
        _uri('/flash-sale/device/$deviceId/now', {
          'note': note,
          'countdown_sec': countdownSec.toString(),
          'products_json': productsJson,
        }),
        headers: _headers(),
      ),
    );
    if (res.statusCode != 200) {
      throw Exception('Flash sale now failed: ${_formatHttpError(res)}');
    }
  }

  Future<void> upsertFlashSaleSchedule({
    required String deviceId,
    required String note,
    required int countdownSec,
    required String productsJson,
    required String scheduleDaysCsv,
    required String startTime,
    required String endTime,
  }) async {
    final res = await _sendWithRetry(
      () => http.put(
        _uri('/flash-sale/device/$deviceId/schedule', {
          'note': note,
          'countdown_sec': countdownSec.toString(),
          'products_json': productsJson,
          'schedule_days': scheduleDaysCsv,
          'start_time': startTime,
          'end_time': endTime,
        }),
        headers: _headers(),
      ),
    );
    if (res.statusCode != 200) {
      throw Exception('Flash sale schedule failed: ${_formatHttpError(res)}');
    }
  }

  Future<void> disableFlashSale(String deviceId) async {
    final res = await _sendWithRetry(
      () => http.delete(_uri('/flash-sale/device/$deviceId'), headers: _headers()),
    );
    if (res.statusCode != 200) {
      throw Exception('Disable flash sale failed: ${_formatHttpError(res)}');
    }
  }

  Future<List<ScheduleInfo>> listSchedules(String screenId) async {
    final res = await _sendWithRetry(
      () => http.get(
        _uri('/schedules', {'screen_id': screenId}),
        headers: _headers(),
      ),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to list schedules: ${_formatHttpError(res)}');
    }
    final data = jsonDecode(res.body) as List<dynamic>;
    return data.map((e) => ScheduleInfo.fromJson(e)).toList();
  }

  Future<void> deleteSchedule(String scheduleId) async {
    final res = await _sendWithRetry(
      () => http.delete(_uri('/schedules/$scheduleId'), headers: _headers()),
    );
    if (res.statusCode != 200) {
      throw Exception('Delete schedule failed: ${_formatHttpError(res)}');
    }
  }

  Future<void> updateSchedule({
    required String scheduleId,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    required String playlistId,
    String? note,
    int? countdownSec,
  }) async {
    final params = <String, String>{
      'day_of_week': dayOfWeek.toString(),
      'start_time': startTime,
      'end_time': endTime,
      'playlist_id': playlistId,
    };
    if (note != null) params['note'] = note;
    if (countdownSec != null) params['countdown_sec'] = countdownSec.toString();
    final res = await _sendWithRetry(
      () =>
          http.put(_uri('/schedules/$scheduleId', params), headers: _headers()),
    );
    if (res.statusCode != 200) {
      throw Exception('Update schedule failed: ${_formatHttpError(res)}');
    }
  }

  Future<void> deletePlaylistItem(String itemId) async {
    final res = await _sendWithRetry(
      () => http.delete(_uri('/playlists/items/$itemId'), headers: _headers()),
    );
    if (res.statusCode != 200) {
      throw Exception('Delete playlist item failed: ${_formatHttpError(res)}');
    }
  }

  Future<void> updatePlaylistItem({
    required String itemId,
    int? order,
    int? durationSec,
    bool? enabled,
  }) async {
    final query = <String, String>{};
    if (order != null) query['order'] = order.toString();
    if (durationSec != null) query['duration_sec'] = durationSec.toString();
    if (enabled != null) query['enabled'] = enabled ? 'true' : 'false';
    final res = await _sendWithRetry(
      () => http.put(
        _uri('/playlists/items/$itemId', query),
        headers: _headers(),
      ),
    );
    if (res.statusCode != 200) {
      throw Exception('Update playlist item failed: ${_formatHttpError(res)}');
    }
  }
}
