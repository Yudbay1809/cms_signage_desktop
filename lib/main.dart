import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'models/types.dart';
import 'services/api.dart';
import 'widgets/drop_zone.dart';

void main() {
  runApp(const CmsApp());
}

class CmsApp extends StatelessWidget {
  const CmsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0E7490),
      brightness: Brightness.light,
    );
    return MaterialApp(
      title: 'Content Control',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF2F6FB),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white.withValues(alpha: 0.94),
          elevation: 3,
          shadowColor: const Color(0x1A0F172A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8FBFF),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        tabBarTheme: TabBarThemeData(
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicator: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(12),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      home: const CmsHome(),
    );
  }
}

class CmsHome extends StatefulWidget {
  const CmsHome({super.key});

  @override
  State<CmsHome> createState() => _CmsHomeState();
}

class _CmsHomeState extends State<CmsHome> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController(text: '08:00:00');
  final TextEditingController _endTimeController = TextEditingController(text: '23:00:00');

  static const List<String> _videoExtensions = [
    '.mp4',
    '.m4v',
    '.mov',
    '.mkv',
    '.avi',
    '.wmv',
    '.webm',
    '.flv',
    '.3gp',
    '.mpg',
    '.mpeg',
    '.ts',
  ];
  static const List<String> _imageExtensions = [
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.bmp',
    '.webp',
    '.heic',
    '.svg',
  ];

  Timer? _autoRefreshTimer;
  bool _refreshing = false;
  DateTime? _lastRefreshAt;
  String? _lastError;

  List<DeviceInfo> _devices = [];
  List<MediaInfo> _media = [];
  List<PlaylistInfo> _playlists = [];
  List<_PlaylistTemplate> _playlistLibrary = [];
  List<ScheduleInfo> _schedules = [];

  final Set<String> _selectedDeviceIds = {};
  String? _selectedScreenId;
  String? _selectedPlaylistId;
  String? _selectedLibraryPlaylistId;
  List<File> _selectedFiles = [];
  String _mediaType = 'auto';
  int _durationSec = 10;
  String _playlistMediaQuery = '';
  String _playlistMediaFilter = 'all';
  int _scheduleDay = DateTime.now().weekday % 7;
  final List<String> _selectedMediaIds = [];
  final Map<String, int> _mediaDurations = {};
  final Map<String, String> _screenGridPresets = {};
  String _currentGridPreset = '1x1';
  bool _autoGridPresetByOrientation = true;
  bool _uploading = false;
  double _uploadProgress = 0.0;
  bool _autoRefresh = true;
  int _mediaTotal = 0;
  int _mediaOffset = 0;
  static const int _mediaPageSize = 120;
  bool _mediaPageLoading = false;
  String _mediaServerQuery = '';
  String _mediaServerType = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeAndRefresh();
    _setAutoRefresh(true);
  }

  ApiService get _api => ApiService(_baseUrlController.text.trim(), apiKey: _apiKeyController.text.trim());

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _tabController.dispose();
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }

  void _setAutoRefresh(bool enabled) {
    _autoRefreshTimer?.cancel();
    setState(() => _autoRefresh = enabled);
    if (!enabled) return;

    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refresh();
    });
  }

  Future<String?> _probeBaseUrl(String url) async {
    final normalized = _normalizeBaseUrl(url);
    if (normalized.isEmpty) return null;
    final parsed = Uri.tryParse(normalized);
    if (parsed == null || parsed.host.isEmpty) return null;
    final host = parsed.host;
    final port = parsed.hasPort ? parsed.port : 8000;
    final probes = <String>[
      'https://$host:$port',
      'http://$host:$port',
    ];

    for (final probeUrl in probes) {
      final probeParsed = Uri.parse(probeUrl);
      final scheme = probeParsed.scheme;
      try {
        final res = await http.get(Uri.parse('$probeUrl/server-info')).timeout(const Duration(milliseconds: 500));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final discoveredPort = (data['server_port'] ?? '$port').toString().trim();
          if (discoveredPort.isNotEmpty) return '$scheme://$host:$discoveredPort';
          return '$scheme://$host';
        }

        final fallback = await http.get(Uri.parse('$probeUrl/healthz')).timeout(const Duration(milliseconds: 450));
        if (fallback.statusCode == 200) {
          final data = jsonDecode(fallback.body) as Map<String, dynamic>;
          final discoveredPort = (data['server_port'] ?? '$port').toString().trim();
          if (discoveredPort.isNotEmpty) return '$scheme://$host:$discoveredPort';
          return '$scheme://$host';
        }
      } catch (_) {}
    }
    return null;
  }

  String _normalizeBaseUrl(String value) {
    var out = value.trim();
    if (out.isEmpty) return '';
    if (!out.startsWith(RegExp(r'https?://'))) {
      out = 'https://$out';
    }
    while (out.endsWith('/')) {
      out = out.substring(0, out.length - 1);
    }
    final parsed = Uri.tryParse(out);
    if (parsed != null && parsed.host.isNotEmpty && !parsed.hasPort) {
      out = '${parsed.scheme}://${parsed.host}:8000';
    }
    return out;
  }

  Future<String?> _discoverBaseUrl() async {
    final common = [
      _baseUrlController.text.trim(),
      'http://127.0.0.1:8000',
      'http://localhost:8000',
    ];
    for (final url in common) {
      if (url.isEmpty) continue;
      final found = await _probeBaseUrl(url);
      if (found != null) return found;
    }

    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLinkLocal: false);
    for (final iface in interfaces) {
      for (final address in iface.addresses) {
        final ip = address.address;
        if (!(ip.startsWith('192.168.') || ip.startsWith('10.') || ip.startsWith('172.'))) {
          continue;
        }

        final parts = ip.split('.');
        if (parts.length != 4) continue;
        final prefix = '${parts[0]}.${parts[1]}.${parts[2]}.';
        final futures = <Future<String?>>[];
        for (var host = 1; host <= 254; host++) {
          futures.add(_probeBaseUrl('http://$prefix$host:8000'));
        }
        final results = await Future.wait(futures);
        for (final found in results) {
          if (found != null) return found;
        }
      }
    }

    return null;
  }

  Future<void> _initializeAndRefresh() async {
    final found = await _discoverBaseUrl();
    if (found != null && found != _baseUrlController.text.trim()) {
      _baseUrlController.text = found;
    }
    await _refresh();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    final baseUrl = _normalizeBaseUrl(_baseUrlController.text);
    if (baseUrl != _baseUrlController.text.trim()) {
      _baseUrlController.text = baseUrl;
    }
    if (baseUrl.isEmpty) {
      _showMessage('Base URL belum diisi');
      return;
    }

    setState(() {
      _refreshing = true;
      _lastError = null;
    });
    try {
      final devices = await _api.listDevices();
      final mediaPage = await _api.listMediaPage(
        offset: 0,
        limit: _mediaPageSize,
        query: _mediaServerQuery,
        type: _mediaServerType,
      );
      setState(() {
        _devices = devices;
        _media = mediaPage.items;
        _mediaTotal = mediaPage.total;
        _mediaOffset = mediaPage.items.length;
        _lastRefreshAt = DateTime.now();

        final availableDeviceIds = devices.map((d) => d.id).toSet();
        _selectedDeviceIds.removeWhere((id) => !availableDeviceIds.contains(id));
        if (_selectedDeviceIds.isEmpty && devices.isNotEmpty) _selectedDeviceIds.add(devices.first.id);

        final availableMediaIds = media.map((m) => m.id).toSet();
        _selectedMediaIds.removeWhere((id) => !availableMediaIds.contains(id));
        _mediaDurations.removeWhere((key, _) => !availableMediaIds.contains(key));
      });
      await _loadScreens();
    } catch (e) {
      setState(() => _lastError = e.toString());
      _showMessage(e.toString());
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _loadMoreMedia() async {
    if (_mediaPageLoading) return;
    if (_mediaOffset >= _mediaTotal) return;
    setState(() => _mediaPageLoading = true);
    try {
      final page = await _api.listMediaPage(
        offset: _mediaOffset,
        limit: _mediaPageSize,
        query: _mediaServerQuery,
        type: _mediaServerType,
      );
      setState(() {
        _media.addAll(page.items);
        _mediaOffset += page.items.length;
        _mediaTotal = page.total;
      });
    } catch (e) {
      _showMessage(e.toString());
    } finally {
      if (mounted) setState(() => _mediaPageLoading = false);
    }
  }

  Future<void> _loadScreens() async {
    if (_selectedDeviceIds.isEmpty) {
      setState(() {
        _playlists = [];
        _playlistLibrary = [];
        _schedules = [];
        _selectedScreenId = null;
        _selectedPlaylistId = null;
        _selectedLibraryPlaylistId = null;
        _currentGridPreset = '1x1';
      });
      return;
    }
    try {
      final firstDeviceId = _devices
          .map((d) => d.id)
          .firstWhere((id) => _selectedDeviceIds.contains(id), orElse: () => _selectedDeviceIds.first);
      final screens = await _api.listScreensForDevice(firstDeviceId);
      setState(() {
        final hasSelected = _selectedScreenId != null && screens.any((s) => s.id == _selectedScreenId);
        if (!hasSelected) {
          _selectedScreenId = screens.isNotEmpty ? screens.first.id : null;
          _selectedPlaylistId = null;
        }
        if (_autoGridPresetByOrientation) {
          _currentGridPreset = _autoGridPresetForSelectedDevices();
        } else if (_selectedScreenId != null) {
          _currentGridPreset = _screenGridPresets[_selectedScreenId!] ?? '1x1';
        } else {
          _currentGridPreset = '1x1';
        }
      });
      await _loadPlaylists();
      await _loadPlaylistLibrary();
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<void> _loadPlaylistLibrary() async {
    if (_devices.isEmpty) {
      setState(() {
        _playlistLibrary = [];
        _selectedLibraryPlaylistId = null;
      });
      return;
    }
    final templates = <_PlaylistTemplate>[];
    for (final device in _devices) {
      final screens = await _api.listScreensForDevice(device.id);
      if (screens.isEmpty) continue;
      final primaryScreenId = screens.first.id;
      final playlists = await _api.listPlaylists(primaryScreenId);
      for (final playlist in playlists) {
        templates.add(
          _PlaylistTemplate(
            playlistId: playlist.id,
            name: playlist.name,
            deviceId: device.id,
            deviceName: device.name,
            screenId: primaryScreenId,
          ),
        );
      }
    }
    setState(() {
      _playlistLibrary = templates;
      final hasSelected = _selectedLibraryPlaylistId != null && templates.any((t) => t.playlistId == _selectedLibraryPlaylistId);
      if (!hasSelected) {
        _selectedLibraryPlaylistId = templates.isNotEmpty ? templates.first.playlistId : null;
      }
    });
  }

  Future<void> _loadPlaylists() async {
    if (_selectedScreenId == null) return;
    try {
      final playlists = await _api.listPlaylists(_selectedScreenId!);
      setState(() {
        _playlists = playlists;
        final hasSelected = _selectedPlaylistId != null && playlists.any((p) => p.id == _selectedPlaylistId);
        if (!hasSelected) {
          _selectedPlaylistId = playlists.isNotEmpty ? playlists.first.id : null;
        }
      });
      await _loadSchedules();
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<void> _loadSchedules() async {
    if (_selectedScreenId == null) {
      setState(() => _schedules = []);
      return;
    }
    try {
      final schedules = await _api.listSchedules(_selectedScreenId!);
      setState(() => _schedules = schedules);
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool _validateTime(String value) {
    final regex = RegExp(r'^\d{2}:\d{2}:\d{2}$');
    return regex.hasMatch(value);
  }

  bool _validateSchedule() {
    final start = _startTimeController.text.trim();
    final end = _endTimeController.text.trim();
    if (!_validateTime(start) || !_validateTime(end)) {
      _showMessage('Format waktu harus HH:MM:SS');
      return false;
    }
    if (start.compareTo(end) >= 0) {
      _showMessage('Start time harus lebih kecil dari End time');
      return false;
    }
    return true;
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: [..._videoExtensions, ..._imageExtensions].map((e) => e.replaceFirst('.', '')).toList(),
    );
    if (result == null || result.files.isEmpty) return;
    final files = result.files.where((f) => f.path != null).map((f) => File(f.path!)).toList();
    if (files.isEmpty) return;
    _setSelectedFilesWithFilter(files, source: 'picker');
  }

  String _fileName(File file) {
    final normalized = file.path.replaceAll('\\', '/');
    final name = normalized.split('/').last.trim();
    if (name.isNotEmpty) return name;
    return 'media_${DateTime.now().millisecondsSinceEpoch}';
  }

  void _setSelectedFilesWithFilter(List<File> files, {required String source}) {
    final accepted = <File>[];
    final rejectedNames = <String>[];

    for (final file in files) {
      if (_inferType(file) != null) {
        accepted.add(file);
      } else {
        rejectedNames.add(_fileName(file));
      }
    }

    if (accepted.isEmpty) {
      _showMessage('Tidak ada file media valid dari $source');
      return;
    }

    if (rejectedNames.isNotEmpty) {
      _showMessage('File tidak didukung: ${rejectedNames.join(', ')}');
    }

    setState(() => _selectedFiles = accepted);
  }

  String? _inferType(File file) {
    final name = _fileName(file).toLowerCase();
    if (_videoExtensions.any(name.endsWith)) return 'video';
    if (_imageExtensions.any(name.endsWith)) return 'image';
    return null;
  }

  bool _isVideoPath(String path) {
    final name = path.toLowerCase();
    return _videoExtensions.any(name.endsWith);
  }

  bool _isImagePath(String path) {
    final name = path.toLowerCase();
    return _imageExtensions.any(name.endsWith);
  }

  List<MediaInfo> _filteredMediaForPlaylist() {
    final query = _playlistMediaQuery.trim().toLowerCase();
    return _media.where((m) {
      final isVideo = m.type == 'video' || _isVideoPath(m.path);
      final isImage = m.type == 'image' || _isImagePath(m.path);
      if (_playlistMediaFilter == 'video' && !isVideo) return false;
      if (_playlistMediaFilter == 'image' && !isImage) return false;
      if (query.isEmpty) return true;
      final name = m.name.toLowerCase();
      final path = m.path.toLowerCase();
      return name.contains(query) || path.contains(query);
    }).toList();
  }

  Future<void> _upload() async {
    if (_selectedFiles.isEmpty) {
      _showMessage('Pilih file dulu');
      return;
    }
    setState(() {
      _uploading = true;
      _uploadProgress = 0.0;
    });
    try {
      final total = _selectedFiles.length;
      var done = 0;
      for (final file in _selectedFiles) {
        final type = _mediaType == 'auto' ? _inferType(file) : _mediaType;
        if (type == null) {
          _showMessage('Tipe file tidak dikenali: ${file.uri.pathSegments.last}');
          continue;
        }
        await _api.uploadMedia(
          file: file,
          name: _fileName(file),
          type: type,
          durationSec: _durationSec,
          onProgress: (p) {
            setState(() => _uploadProgress = (done + p) / total);
          },
        );
        done += 1;
        setState(() => _uploadProgress = done / total);
      }
      _showMessage('Upload berhasil');
      setState(() => _selectedFiles = []);
      await _refresh();
    } catch (e) {
      _showMessage(e.toString());
    } finally {
      setState(() {
        _uploading = false;
      });
    }
  }

  Future<String?> _promptPlaylistName() async {
    final controller = TextEditingController(text: 'Playlist-${DateTime.now().millisecondsSinceEpoch}');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Playlist name'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Name'),
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.of(ctx).pop(controller.text.trim()), child: const Text('Create')),
          ],
        );
      },
    );
    final name = result?.trim();
    if (name == null || name.isEmpty) return null;
    return name;
  }

  Future<void> _createPlaylistForSelectedScreen() async {
    if (_selectedScreenId == null) {
      _showMessage('Pilih device dulu');
      return;
    }
    if (_selectedMediaIds.isEmpty) {
      _showMessage('Pilih media untuk playlist');
      return;
    }
    final name = await _promptPlaylistName();
    if (name == null) return;

    try {
      final playlist = await _api.createPlaylist(_selectedScreenId!, name);
      var order = 1;
      for (final mediaId in _selectedMediaIds) {
        MediaInfo? media;
        for (final m in _media) {
          if (m.id == mediaId) {
            media = m;
            break;
          }
        }
        final isVideo = media != null && (media.type == 'video' || _isVideoPath(media.path));
        final duration = _mediaDurations[mediaId] ?? _durationSec;
        await _api.addPlaylistItem(
          playlistId: playlist.id,
          mediaId: mediaId,
          order: order,
          durationSec: isVideo ? null : duration,
        );
        order += 1;
      }
      _showMessage('Playlist dibuat');
      setState(() => _selectedPlaylistId = playlist.id);
      await _loadPlaylists();
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<void> _createPlaylistAndSchedule() async {
    if (_selectedDeviceIds.isEmpty) {
      _showMessage('Pilih minimal satu device');
      return;
    }
    if (_selectedMediaIds.isEmpty) {
      _showMessage('Pilih media untuk playlist');
      return;
    }
    if (!_validateSchedule()) return;

    final playlistName = await _promptPlaylistName();
    if (playlistName == null) return;

    try {
      for (final deviceId in _selectedDeviceIds) {
        final screens = await _api.listScreensForDevice(deviceId);
        if (screens.isEmpty) {
          _showMessage('Device $deviceId tidak punya screen');
          continue;
        }
        final target = screens.first;
        final playlist = await _api.createPlaylist(target.id, playlistName);
        var order = 1;
        for (final mediaId in _selectedMediaIds) {
          MediaInfo? media;
          for (final m in _media) {
            if (m.id == mediaId) {
              media = m;
              break;
            }
          }
          final isVideo = media != null && (media.type == 'video' || _isVideoPath(media.path));
          final duration = _mediaDurations[mediaId] ?? _durationSec;
          await _api.addPlaylistItem(
            playlistId: playlist.id,
            mediaId: mediaId,
            order: order,
            durationSec: isVideo ? null : duration,
          );
          order += 1;
        }
        await _api.createSchedule(
          screenId: target.id,
          playlistId: playlist.id,
          dayOfWeek: _scheduleDay,
          startTime: _startTimeController.text.trim(),
          endTime: _endTimeController.text.trim(),
        );
      }
      _showMessage('Playlist & schedule dibuat untuk device terpilih');
      await _loadPlaylists();
      await _loadSchedules();
      await _loadPlaylistLibrary();
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<void> _assignLibraryPlaylistToSelectedDevices() async {
    if (_selectedDeviceIds.isEmpty) {
      _showMessage('Pilih minimal satu device');
      return;
    }
    if (_selectedLibraryPlaylistId == null) {
      _showMessage('Pilih playlist dari library');
      return;
    }
    if (!_validateSchedule()) return;

    _PlaylistTemplate? sourceTemplate;
    for (final template in _playlistLibrary) {
      if (template.playlistId == _selectedLibraryPlaylistId) {
        sourceTemplate = template;
        break;
      }
    }
    if (sourceTemplate == null) {
      _showMessage('Playlist source tidak ditemukan');
      return;
    }

    try {
      final sourceConfig = await _api.fetchDeviceConfigRaw(sourceTemplate.deviceId);
      final rawPlaylists = sourceConfig['playlists'];
      if (rawPlaylists is! List) {
        _showMessage('Data playlist source tidak valid');
        return;
      }

      Map<String, dynamic>? sourcePlaylist;
      for (final item in rawPlaylists) {
        if (item is Map && '${item['id']}' == sourceTemplate.playlistId) {
          sourcePlaylist = Map<String, dynamic>.from(item.cast<String, dynamic>());
          break;
        }
      }
      if (sourcePlaylist == null) {
        _showMessage('Playlist source tidak ada pada konfigurasi device');
        return;
      }

      final rawItems = sourcePlaylist['items'];
      if (rawItems is! List || rawItems.isEmpty) {
        _showMessage('Playlist source tidak memiliki item');
        return;
      }

      final items = rawItems
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e.cast<String, dynamic>()))
          .toList()
        ..sort((a, b) => ((a['order'] as num?)?.toInt() ?? 0).compareTo((b['order'] as num?)?.toInt() ?? 0));

      for (final deviceId in _selectedDeviceIds) {
        final screens = await _api.listScreensForDevice(deviceId);
        if (screens.isEmpty) {
          _showMessage('Device $deviceId tidak punya screen');
          continue;
        }
        final targetScreen = screens.first;
        final newPlaylist = await _api.createPlaylist(targetScreen.id, sourceTemplate.name);

        var nextOrder = 1;
        for (final item in items) {
          final mediaId = '${item['media_id']}'.trim();
          if (mediaId.isEmpty) continue;
          final duration = (item['duration_sec'] as num?)?.toInt();
          await _api.addPlaylistItem(
            playlistId: newPlaylist.id,
            mediaId: mediaId,
            order: nextOrder,
            durationSec: duration,
          );
          nextOrder += 1;
        }

        await _api.createSchedule(
          screenId: targetScreen.id,
          playlistId: newPlaylist.id,
          dayOfWeek: _scheduleDay,
          startTime: _startTimeController.text.trim(),
          endTime: _endTimeController.text.trim(),
        );
      }
      _showMessage('Playlist library berhasil diterapkan ke device terpilih');
      await _loadPlaylists();
      await _loadSchedules();
      await _loadPlaylistLibrary();
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<void> _deletePlaylist() async {
    if (_selectedPlaylistId == null) {
      _showMessage('Pilih playlist dulu');
      return;
    }
    try {
      await _api.deletePlaylist(_selectedPlaylistId!);
      _showMessage('Playlist dihapus');
      await _loadPlaylists();
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<void> _createScheduleForSelectedPlaylist() async {
    if (_selectedScreenId == null || _selectedPlaylistId == null) {
      _showMessage('Pilih device dan playlist dulu');
      return;
    }
    if (!_validateSchedule()) return;

    try {
      await _api.createSchedule(
        screenId: _selectedScreenId!,
        playlistId: _selectedPlaylistId!,
        dayOfWeek: _scheduleDay,
        startTime: _startTimeController.text.trim(),
        endTime: _endTimeController.text.trim(),
      );
      _showMessage('Schedule dibuat');
      await _loadSchedules();
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<void> _deleteSchedule(ScheduleInfo schedule) async {
    try {
      await _api.deleteSchedule(schedule.id);
      _showMessage('Schedule dihapus');
      await _loadSchedules();
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<void> _deleteMedia(MediaInfo media) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Hapus media'),
          content: Text('Yakin hapus media "${media.name}"?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')),
            ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Hapus')),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await _api.deleteMedia(media.id);
      _showMessage('Media dihapus');
      await _refresh();
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<void> _editSchedule(ScheduleInfo schedule) async {
    if (_playlists.isEmpty) {
      _showMessage('Playlist kosong untuk screen ini');
      return;
    }
    final startController = TextEditingController(text: schedule.startTime);
    final endController = TextEditingController(text: schedule.endTime);
    var selectedDay = schedule.dayOfWeek;
    var selectedPlaylist = _playlists.any((p) => p.id == schedule.playlistId) ? schedule.playlistId : _playlists.first.id;

    final submit = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('Edit Schedule'),
              content: SizedBox(
                width: 430,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButton<int>(
                      value: selectedDay,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('Sunday')),
                        DropdownMenuItem(value: 1, child: Text('Monday')),
                        DropdownMenuItem(value: 2, child: Text('Tuesday')),
                        DropdownMenuItem(value: 3, child: Text('Wednesday')),
                        DropdownMenuItem(value: 4, child: Text('Thursday')),
                        DropdownMenuItem(value: 5, child: Text('Friday')),
                        DropdownMenuItem(value: 6, child: Text('Saturday')),
                      ],
                      onChanged: (v) => setLocalState(() => selectedDay = v ?? selectedDay),
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: selectedPlaylist,
                      isExpanded: true,
                      items: _playlists.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                      onChanged: (v) => setLocalState(() => selectedPlaylist = v ?? selectedPlaylist),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: startController,
                      decoration: const InputDecoration(labelText: 'Start (HH:MM:SS)'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: endController,
                      decoration: const InputDecoration(labelText: 'End (HH:MM:SS)'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Save')),
              ],
            );
          },
        );
      },
    );

    if (submit != true) return;
    final start = startController.text.trim();
    final end = endController.text.trim();
    if (!_validateTime(start) || !_validateTime(end)) {
      _showMessage('Format waktu harus HH:MM:SS');
      return;
    }
    if (start.compareTo(end) >= 0) {
      _showMessage('Start time harus lebih kecil dari End time');
      return;
    }

    try {
      await _api.updateSchedule(
        scheduleId: schedule.id,
        dayOfWeek: selectedDay,
        startTime: start,
        endTime: end,
        playlistId: selectedPlaylist,
      );
      _showMessage('Schedule diupdate');
      await _loadSchedules();
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  String _absoluteUrl(String path) {
    if (path.startsWith('http')) return path;
    return Uri.parse(_baseUrlController.text.trim()).resolve(path).toString();
  }

  List<String> _gridPresetOptions() {
    return const ['1x1', '1x2', '2x1', '2x2', '3x3', '4x4'];
  }

  String _gridPresetLabel(String preset) {
    switch (preset) {
      case '1x1':
        return 'Full Screen (1x1)';
      case '1x2':
        return 'Split Horizontal (1x2)';
      case '2x1':
        return 'Split Vertical (2x1)';
      case '2x2':
        return 'Quad View (2x2)';
      case '3x3':
        return 'Matrix (3x3)';
      case '4x4':
        return 'Matrix (4x4)';
      default:
        return preset;
    }
  }

  int _gridRows(String preset) {
    final parts = preset.split('x');
    return parts.length == 2 ? int.tryParse(parts[0]) ?? 1 : 1;
  }

  int _gridCols(String preset) {
    final parts = preset.split('x');
    return parts.length == 2 ? int.tryParse(parts[1]) ?? 1 : 1;
  }

  String _autoGridPresetForSelectedDevices() {
    if (_selectedDeviceIds.isEmpty) return '1x1';
    var portraitCount = 0;
    var landscapeCount = 0;
    for (final device in _devices) {
      if (!_selectedDeviceIds.contains(device.id)) continue;
      if ((device.orientation ?? 'portrait') == 'landscape') {
        landscapeCount += 1;
      } else {
        portraitCount += 1;
      }
    }
    if (landscapeCount > 0 && portraitCount == 0) return '2x1';
    if (portraitCount > 0 && landscapeCount == 0) return '1x2';
    if (portraitCount > 0 && landscapeCount > 0) return '2x2';
    return '1x1';
  }

  void _setGridPresetForSelectedScreen(String preset) {
    if (_autoGridPresetByOrientation) {
      _showMessage('Nonaktifkan auto grid untuk memilih manual');
      return;
    }
    final screenId = _selectedScreenId;
    if (screenId == null) {
      _showMessage('Pilih device dulu');
      return;
    }
    setState(() {
      _currentGridPreset = preset;
      _screenGridPresets[screenId] = preset;
    });
  }

  String _dayLabel(int day) {
    switch (day) {
      case 0:
        return 'Sunday';
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      default:
        return 'Day $day';
    }
  }

  void _previewMedia(MediaInfo media) {
    final url = _absoluteUrl(media.path);
    final isVideo = media.type == 'video' || _isVideoPath(media.path);
    final isImage = media.type == 'image' || _isImagePath(media.path);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(media.name),
          content: SizedBox(
            width: 460,
            height: 320,
            child: isVideo
                ? _VideoPreview(url: url)
                : isImage
                    ? Image.network(url, fit: BoxFit.contain)
                    : const Center(child: Text('Unknown media type')),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
          ],
        );
      },
    );
  }

  Future<void> _openDevicePicker() async {
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Pilih device'),
          content: SizedBox(
            width: 360,
            child: ListView(
              shrinkWrap: true,
              children: _devices.map((d) {
                final selected = _selectedDeviceIds.contains(d.id);
                return CheckboxListTile(
                  value: selected,
                  title: Text(d.name),
                  subtitle: Text(d.id),
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedDeviceIds.add(d.id);
                      } else {
                        _selectedDeviceIds.remove(d.id);
                      }
                      if (_autoGridPresetByOrientation) {
                        _currentGridPreset = _autoGridPresetForSelectedDevices();
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Done')),
          ],
        );
      },
    );
    await _loadScreens();
  }

  Future<void> _exportConfig() async {
    if (_selectedDeviceIds.isEmpty) {
      _showMessage('Pilih device dulu');
      return;
    }
    final deviceId = _selectedDeviceIds.first;
    try {
      final data = await _api.fetchDeviceConfigRaw(deviceId);
      final withGrid = Map<String, dynamic>.from(data);
      withGrid['desktop_grid_settings'] = _screenGridPresets;
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save config',
        fileName: 'signage_config_$deviceId.json',
      );
      if (path == null) return;
      final file = File(path);
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(withGrid));
      _showMessage('Export berhasil');
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<void> _setDeviceOrientation(DeviceInfo device, String orientation) async {
    try {
      await _api.updateDeviceOrientation(device.id, orientation);
      _showMessage('Orientation ${device.name} diubah ke $orientation');
      await _refresh();
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<void> _deleteDevice(DeviceInfo device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Hapus device'),
          content: Text('Yakin ingin hapus device "${device.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _api.deleteDevice(device.id);
      _selectedDeviceIds.remove(device.id);
      _showMessage('Device ${device.name} dihapus');
      await _refresh();
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<void> _deleteSelectedDevices() async {
    if (_selectedDeviceIds.isEmpty) {
      _showMessage('Pilih device dulu');
      return;
    }

    final selectedIds = _selectedDeviceIds.toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Hapus device terpilih'),
          content: Text('Yakin ingin hapus ${selectedIds.length} device terpilih?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    var deleted = 0;
    for (final deviceId in selectedIds) {
      try {
        await _api.deleteDevice(deviceId);
        deleted += 1;
      } catch (_) {}
    }

    _selectedDeviceIds.clear();
    await _refresh();
    _showMessage('$deleted device berhasil dihapus');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Content Control', style: TextStyle(fontWeight: FontWeight.w700)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F766E), Color(0xFF0369A1), Color(0xFF1D4ED8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(54),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Media'),
                Tab(text: 'Playlists'),
                Tab(text: 'Schedule'),
                Tab(text: 'Devices'),
              ],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8FAFD), Color(0xFFF0F7FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _baseUrlController,
                          decoration: const InputDecoration(labelText: 'Base URL'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 180,
                        child: TextField(
                          controller: _apiKeyController,
                          decoration: const InputDecoration(labelText: 'API Key (opsional)'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _openDevicePicker,
                        child: Text('Devices (${_selectedDeviceIds.length})'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(onPressed: _refreshing ? null : _refresh, child: const Text('Refresh')),
                      const SizedBox(width: 8),
                      ElevatedButton(onPressed: _exportConfig, child: const Text('Export')),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Switch(
                        value: _autoRefresh,
                        onChanged: _setAutoRefresh,
                      ),
                      const Text('Auto refresh (30s)'),
                      const SizedBox(width: 12),
                      if (_lastRefreshAt != null) Text('Last: ${_lastRefreshAt!.toLocal()}'),
                      const SizedBox(width: 12),
                      if (_refreshing)
                        const Row(
                          children: [
                            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 8),
                            Text('Refreshing...'),
                          ],
                        ),
                      if (!_refreshing && _lastError != null)
                        Flexible(
                          child: Text(
                            'Error: $_lastError',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Card(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _mediaTab(),
                        _playlistTab(),
                        _scheduleTab(),
                        _devicesTab(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mediaTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropZone(onFiles: (files) => _setSelectedFilesWithFilter(files, source: 'drag drop')),
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton(onPressed: _pickFile, child: const Text('Pick File')),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _mediaType,
                items: const [
                  DropdownMenuItem(value: 'auto', child: Text('Auto')),
                  DropdownMenuItem(value: 'image', child: Text('Image')),
                  DropdownMenuItem(value: 'video', child: Text('Video')),
                ],
                onChanged: (v) => setState(() => _mediaType = v ?? 'auto'),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 120,
                child: TextField(
                  decoration: const InputDecoration(labelText: 'Durasi (detik)'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => _durationSec = int.tryParse(v) ?? 10,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _upload, child: const Text('Upload')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Cari media di server (nama/path)',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (value) {
                    _mediaServerQuery = value;
                    _refresh();
                  },
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _mediaServerType,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(value: 'image', child: Text('Image')),
                  DropdownMenuItem(value: 'video', child: Text('Video')),
                ],
                onChanged: (value) {
                  setState(() => _mediaServerType = value ?? 'all');
                  _refresh();
                },
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _refreshing ? null : _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Apply Filter'),
              ),
            ],
          ),
          if (_uploading) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: _uploadProgress),
          ],
          const SizedBox(height: 12),
          if (_selectedFiles.isNotEmpty)
            Text('Selected files: ${_selectedFiles.map((f) => f.uri.pathSegments.last).join(', ')}'),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Media loaded: ${_media.length} / $_mediaTotal'),
              const SizedBox(width: 10),
              if (_mediaOffset < _mediaTotal)
                OutlinedButton(
                  onPressed: _mediaPageLoading ? null : _loadMoreMedia,
                  child: Text(_mediaPageLoading ? 'Loading...' : 'Load More'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: _media.length,
              itemBuilder: (context, i) {
                final m = _media[i];
                final inferredType = _isVideoPath(m.path) ? 'video' : _isImagePath(m.path) ? 'image' : m.type;
                return ListTile(
                  title: Text(m.name),
                  subtitle: Text('$inferredType | ${m.path}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(onPressed: () => _previewMedia(m), child: const Text('Preview')),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => _deleteMedia(m),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _playlistTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ElevatedButton(onPressed: _createPlaylistForSelectedScreen, child: const Text('Create Playlist')),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _createPlaylistAndSchedule, child: const Text('Create + Schedule')),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _selectedPlaylistId,
                hint: const Text('Playlist'),
                items: _playlists.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                onChanged: (v) => setState(() => _selectedPlaylistId = v),
              ),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _deletePlaylist, child: const Text('Delete Playlist')),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Pilih media untuk playlist, atur durasi, dan urutan:'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Cari media (nama/path)',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => _playlistMediaQuery = value),
                ),
              ),
              const SizedBox(width: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: Text('Semua')),
                  ButtonSegment(value: 'image', label: Text('Gambar')),
                  ButtonSegment(value: 'video', label: Text('Video')),
                ],
                selected: {_playlistMediaFilter},
                onSelectionChanged: (value) {
                  final selected = value.isNotEmpty ? value.first : 'all';
                  setState(() => _playlistMediaFilter = selected);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final filteredMedia = _filteredMediaForPlaylist();
                      if (filteredMedia.isEmpty) {
                        return const Center(child: Text('Media tidak ditemukan untuk filter ini'));
                      }
                      return ListView.builder(
                        itemCount: filteredMedia.length,
                        itemBuilder: (context, i) {
                          final m = filteredMedia[i];
                          final selected = _selectedMediaIds.contains(m.id);
                          return Row(
                            children: [
                              Expanded(
                                child: CheckboxListTile(
                                  value: selected,
                                  title: Text(m.name),
                                  subtitle: Text(m.type),
                                  onChanged: (value) {
                                    setState(() {
                                      if (value == true) {
                                        _selectedMediaIds.add(m.id);
                                        _mediaDurations[m.id] = _mediaDurations[m.id] ?? _durationSec;
                                      } else {
                                        _selectedMediaIds.remove(m.id);
                                        _mediaDurations.remove(m.id);
                                      }
                                    });
                                  },
                                ),
                              ),
                              SizedBox(
                                width: 100,
                                child: TextField(
                                  decoration: const InputDecoration(labelText: 'Durasi'),
                                  keyboardType: TextInputType.number,
                                  onChanged: (v) {
                                    final val = int.tryParse(v) ?? _durationSec;
                                    _mediaDurations[m.id] = val;
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ReorderableListView(
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final id = _selectedMediaIds.removeAt(oldIndex);
                        _selectedMediaIds.insert(newIndex, id);
                      });
                    },
                    children: [
                      for (final id in _selectedMediaIds)
                        ListTile(
                          key: ValueKey(id),
                          title: Text(_media.firstWhere((m) => m.id == id).name),
                          subtitle: Text('Durasi: ${_mediaDurations[id] ?? _durationSec}s'),
                          trailing: const Icon(Icons.drag_handle),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scheduleTab() {
    final playlistNames = <String, String>{for (final p in _playlists) p.id: p.name};
    return Padding(
      padding: const EdgeInsets.all(12),
      child: ListView(
        children: [
          const Text('Buat schedule untuk playlist:'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButton<String>(
                value: _selectedPlaylistId,
                hint: const Text('Playlist'),
                items: _playlists.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                onChanged: (v) => setState(() => _selectedPlaylistId = v),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButton<int>(
                value: _scheduleDay,
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Sunday')),
                  DropdownMenuItem(value: 1, child: Text('Monday')),
                  DropdownMenuItem(value: 2, child: Text('Tuesday')),
                  DropdownMenuItem(value: 3, child: Text('Wednesday')),
                  DropdownMenuItem(value: 4, child: Text('Thursday')),
                  DropdownMenuItem(value: 5, child: Text('Friday')),
                  DropdownMenuItem(value: 6, child: Text('Saturday')),
                ],
                onChanged: (v) => setState(() => _scheduleDay = v ?? 0),
              ),
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _startTimeController,
                  decoration: const InputDecoration(labelText: 'Start (HH:MM:SS)'),
                ),
              ),
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _endTimeController,
                  decoration: const InputDecoration(labelText: 'End (HH:MM:SS)'),
                ),
              ),
              ElevatedButton(onPressed: _createScheduleForSelectedPlaylist, child: const Text('Create Schedule')),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButton<String>(
                value: _selectedLibraryPlaylistId,
                hint: const Text('Playlist Library (all devices)'),
                items: _playlistLibrary
                    .map(
                      (p) => DropdownMenuItem(
                        value: p.playlistId,
                        child: Text('${p.name} (${p.deviceName})'),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedLibraryPlaylistId = v),
              ),
              ElevatedButton(
                onPressed: _assignLibraryPlaylistToSelectedDevices,
                child: const Text('Apply Library Playlist to Selected Devices'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Grid Preset', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              Switch(
                value: _autoGridPresetByOrientation,
                onChanged: (value) {
                  setState(() {
                    _autoGridPresetByOrientation = value;
                    if (value) {
                      _currentGridPreset = _autoGridPresetForSelectedDevices();
                    }
                  });
                },
              ),
              Text(
                _autoGridPresetByOrientation
                    ? 'Auto by orientation ($_currentGridPreset)'
                    : 'Manual grid preset',
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _gridPresetOptions().map((preset) {
              final selected = preset == _currentGridPreset;
              return ChoiceChip(
                label: Text(_gridPresetLabel(preset)),
                selected: selected,
                onSelected: (_) => _setGridPresetForSelectedScreen(preset),
                avatar: Icon(
                  selected ? Icons.check_circle : Icons.grid_view_rounded,
                  size: 16,
                  color: selected ? Colors.white : Theme.of(context).colorScheme.primary,
                ),
                selectedColor: Theme.of(context).colorScheme.primary,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
                side: BorderSide(
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE0F2FE), Color(0xFFECFEFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF7DD3FC)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Preview ${_gridRows(_currentGridPreset)}x${_gridCols(_currentGridPreset)}'),
                const SizedBox(height: 8),
                SizedBox(
                  height: 112,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _gridRows(_currentGridPreset) * _gridCols(_currentGridPreset),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _gridCols(_currentGridPreset),
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                    ),
                    itemBuilder: (context, i) {
                      final cellNo = i + 1;
                      return Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFBAE6FD)),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x140F172A),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          'Cell $cellNo',
                          style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF075985)),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text('Schedule aktif:'),
          const SizedBox(height: 8),
          if (_schedules.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Belum ada schedule pada screen ini')),
            ),
          if (_schedules.isNotEmpty)
            ..._schedules.map((schedule) {
              final playlistLabel = playlistNames[schedule.playlistId] ?? schedule.playlistId;
              return ListTile(
                title: Text('${_dayLabel(schedule.dayOfWeek)} | ${schedule.startTime} - ${schedule.endTime}'),
                subtitle: Text('Playlist: $playlistLabel'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Edit schedule',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _editSchedule(schedule),
                    ),
                    IconButton(
                      tooltip: 'Delete schedule',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _deleteSchedule(schedule),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _devicesTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Total: ${_devices.length} | Selected: ${_selectedDeviceIds.length}'),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _selectedDeviceIds.isEmpty ? null : _deleteSelectedDevices,
                child: const Text('Hapus Device Terpilih'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_devices.isEmpty)
            const Text('Belum ada device terdaftar.'),
          Expanded(
            child: ListView.builder(
              itemCount: _devices.length,
              itemBuilder: (context, i) {
                final d = _devices[i];
                final selected = _selectedDeviceIds.contains(d.id);
                final lastSeen = d.lastSeen;
                final isOnline = lastSeen != null && DateTime.now().difference(lastSeen).inMinutes < 2;
                final status = isOnline ? 'online' : 'offline';
                final statusColor = isOnline ? const Color(0xFF15803D) : const Color(0xFFB91C1C);
                final orientation = (d.orientation == 'landscape') ? 'landscape' : 'portrait';
                final orientationIcon =
                    orientation == 'landscape' ? Icons.stay_current_landscape : Icons.stay_current_portrait;
                return CheckboxListTile(
                  value: selected,
                  title: Row(
                    children: [
                      Icon(orientationIcon, size: 18),
                      const SizedBox(width: 6),
                      Expanded(child: Text(d.name)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: 'Delete device',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteDevice(d),
                      ),
                    ],
                  ),
                  subtitle: Text('${d.id} | $orientation | last: ${lastSeen ?? '-'}'),
                  secondary: PopupMenuButton<String>(
                    tooltip: 'Set orientation',
                    onSelected: (value) => _setDeviceOrientation(d, value),
                    itemBuilder: (ctx) => const [
                      PopupMenuItem(
                        value: 'portrait',
                        child: Text('Set Portrait'),
                      ),
                      PopupMenuItem(
                        value: 'landscape',
                        child: Text('Set Landscape'),
                      ),
                    ],
                    icon: const Icon(Icons.screen_rotation),
                  ),
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedDeviceIds.add(d.id);
                      } else {
                        _selectedDeviceIds.remove(d.id);
                      }
                      if (_autoGridPresetByOrientation) {
                        _currentGridPreset = _autoGridPresetForSelectedDevices();
                      }
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaylistTemplate {
  final String playlistId;
  final String name;
  final String deviceId;
  final String deviceName;
  final String screenId;

  _PlaylistTemplate({
    required this.playlistId,
    required this.name,
    required this.deviceId,
    required this.deviceName,
    required this.screenId,
  });
}

class _VideoPreview extends StatefulWidget {
  final String url;
  const _VideoPreview({required this.url});

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller!.initialize().then((_) {
      if (mounted) setState(() {});
      _controller!.play();
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: VideoPlayer(_controller!),
    );
  }
}
