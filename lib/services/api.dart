import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/types.dart';

class ApiService {
  String baseUrl;
  ApiService(this.baseUrl);

  String _url(String path) => path.startsWith('http') ? path : '$baseUrl$path';

  Future<List<DeviceInfo>> listDevices() async {
    final res = await http.get(Uri.parse(_url('/devices')));
    if (res.statusCode != 200) {
      throw Exception('Failed to list devices: ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as List<dynamic>;
    return data.map((e) => DeviceInfo.fromJson(e)).toList();
  }

  Future<List<MediaInfo>> listMedia() async {
    final res = await http.get(Uri.parse(_url('/media')));
    if (res.statusCode != 200) {
      throw Exception('Failed to list media: ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as List<dynamic>;
    return data.map((e) => MediaInfo.fromJson(e)).toList();
  }

  Future<List<ScreenInfo>> listScreensForDevice(String deviceId) async {
    final res = await http.get(Uri.parse(_url('/devices/$deviceId/config')));
    if (res.statusCode != 200) {
      throw Exception('Failed to fetch device config: ${res.statusCode}');
    }
    final data = jsonDecode(res.body);
    final screens = (data['screens'] as List).map((s) => ScreenInfo(id: s['screen_id'], name: s['name'] ?? '')).toList();
    return screens;
  }

  Future<List<PlaylistInfo>> listPlaylists(String screenId) async {
    final res = await http.get(Uri.parse(_url('/playlists?screen_id=$screenId')));
    if (res.statusCode != 200) {
      throw Exception('Failed to list playlists: ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as List<dynamic>;
    return data.map((e) => PlaylistInfo(id: e['id'], name: e['name'] ?? '')).toList();
  }

  Future<MediaInfo> uploadMedia({
    required File file,
    required String name,
    required String type,
    required int durationSec,
  }) async {
    final req = http.MultipartRequest('POST', Uri.parse(_url('/media/upload')));
    req.fields['name'] = name;
    req.fields['type'] = type;
    req.fields['duration_sec'] = durationSec.toString();
    req.files.add(await http.MultipartFile.fromPath('file', file.path));

    final res = await req.send();
    final body = await res.stream.bytesToString();
    if (res.statusCode != 200) {
      throw Exception('Upload failed: ${res.statusCode}');
    }
    return MediaInfo.fromJson(jsonDecode(body));
  }

  Future<PlaylistInfo> createPlaylist(String screenId, String name) async {
    final url = _url('/playlists?screen_id=$screenId&name=${Uri.encodeComponent(name)}');
    final res = await http.post(Uri.parse(url));
    if (res.statusCode != 200) {
      throw Exception('Create playlist failed: ${res.statusCode}');
    }
    final data = jsonDecode(res.body);
    return PlaylistInfo(id: data['id'], name: data['name'] ?? name);
  }

  Future<void> deletePlaylist(String playlistId) async {
    final res = await http.delete(Uri.parse(_url('/playlists/$playlistId')));
    if (res.statusCode != 200) {
      throw Exception('Delete playlist failed: ${res.statusCode}');
    }
  }

  Future<void> addPlaylistItem({
    required String playlistId,
    required String mediaId,
    required int order,
    required int durationSec,
  }) async {
    final url = _url('/playlists/$playlistId/items?media_id=$mediaId&order=$order&duration_sec=$durationSec&enabled=true');
    final res = await http.post(Uri.parse(url));
    if (res.statusCode != 200) {
      throw Exception('Add item failed: ${res.statusCode}');
    }
  }

  Future<void> createSchedule({
    required String screenId,
    required String playlistId,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
  }) async {
    final url = _url('/schedules?screen_id=$screenId&playlist_id=$playlistId&day_of_week=$dayOfWeek&start_time=$startTime&end_time=$endTime');
    final res = await http.post(Uri.parse(url));
    if (res.statusCode != 200) {
      throw Exception('Create schedule failed: ${res.statusCode}');
    }
  }
}
