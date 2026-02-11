import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      title: 'CMS Signage Desktop',
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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
  Timer? _realtimeReconnectTimer;
  Timer? _realtimeRefreshDebounce;
  WebSocket? _realtimeSocket;
  String? _connectedWsUrl;
  bool _realtimeConnecting = false;
  int _lastRealtimeRevision = 0;
  bool _refreshing = false;
  DateTime? _lastRefreshAt;
  String? _lastError;

  List<DeviceInfo> _devices = [];
  List<MediaInfo> _media = [];
  List<PlaylistInfo> _playlists = [];
  List<_PlaylistTemplate> _playlistLibrary = [];
  List<_GridPreviewItem> _gridTargetPreviewItems = [];
  final Map<String, String> _deviceNowPlayingName = {};
  final Map<String, String?> _deviceNowPlayingPlaylistId = {};
  final Map<String, String> _deviceGridPreset = {};
  final Map<String, String?> _devicePlaylistSelection = {};
  String? _managePlaylistId;
  final TextEditingController _managePlaylistNameController =
      TextEditingController();
  String? _manageAddMediaId;
  final TextEditingController _manageAddDurationController =
      TextEditingController(text: '10');
  List<_ManagePlaylistItem> _managePlaylistItems = [];
  final Set<String> _manageSelectedItemIds = {};
  bool _managePlaylistLoading = false;
  bool _managePlaylistDirty = false;
  final TextEditingController _flashSaleScheduleStartController =
      TextEditingController(text: '09:00');
  final TextEditingController _flashSaleScheduleEndController =
      TextEditingController(text: '21:00');
  final TextEditingController _flashSaleCountdownController =
      TextEditingController(text: '600');
  final TextEditingController _flashSaleNoteController =
      TextEditingController();
  final List<_FlashSaleProductDraft> _flashSaleProducts = [
    _FlashSaleProductDraft(
      name: 'Cushion Foundation',
      brand: 'Glow Kiss',
      normalPrice: '129000',
      promoPrice: '79000',
      stock: '12',
      mediaId: '',
    ),
    _FlashSaleProductDraft(
      name: 'Lip Cream Matte',
      brand: 'Velvet Charm',
      normalPrice: '99000',
      promoPrice: '59000',
      stock: '9',
      mediaId: '',
    ),
    _FlashSaleProductDraft(
      name: 'Serum Vitamin C',
      brand: 'Pure Aura',
      normalPrice: '189000',
      promoPrice: '109000',
      stock: '6',
      mediaId: '',
    ),
  ];
  final Set<String> _flashSaleDeviceIds = {};
  final Set<String> _selectedFlashSalePlaylistIds = {};
  final Set<int> _flashSaleScheduleDays = {1, 2, 3, 4, 5, 6, 0};
  String? _flashSaleSourcePlaylistName;
  bool _flashSaleBusy = false;
  bool _flashSaleCleanupBusy = false;
  bool _flashSaleMediaCheckBusy = false;
  DateTime? _flashSaleMediaCheckedAt;
  final Map<String, List<String>> _flashSaleMissingMediaByDevice = {};
  final Map<String, String> _flashSaleMediaErrorByDevice = {};
  String? _gridTargetDeviceId;
  String _gridTargetPreset = '1x1';
  bool _gridTargetLoading = false;

  final Set<String> _selectedDeviceIds = {};
  String? _selectedScreenId;
  String? _selectedPlaylistId;
  String? _bulkPlaylistName;
  List<File> _selectedFiles = [];
  String _mediaType = 'auto';
  int _durationSec = 10;
  String _playlistMediaQuery = '';
  String _playlistMediaFilter = 'all';
  final List<String> _selectedMediaIds = [];
  final Map<String, int> _mediaDurations = {};
  final Map<String, String> _screenGridPresets = {};
  final Map<String, int> _screenTransitionDurations = {};
  int _gridTargetTransitionDuration = 1;
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
    _tabController = TabController(length: 7, vsync: this);
    _initializeAndRefresh();
    _setAutoRefresh(true);
  }

  ApiService get _api => ApiService(
    _baseUrlController.text.trim(),
    apiKey: _apiKeyController.text.trim(),
  );

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _realtimeReconnectTimer?.cancel();
    _realtimeRefreshDebounce?.cancel();
    _closeRealtimeSocket();
    _tabController.dispose();
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _managePlaylistNameController.dispose();
    _manageAddDurationController.dispose();
    _flashSaleScheduleStartController.dispose();
    _flashSaleScheduleEndController.dispose();
    _flashSaleCountdownController.dispose();
    _flashSaleNoteController.dispose();
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

  void _closeRealtimeSocket() {
    try {
      _realtimeSocket?.close();
    } catch (_) {}
    _realtimeSocket = null;
    _connectedWsUrl = null;
  }

  String _toWsUrl(String baseUrl) {
    final uri = Uri.parse(baseUrl);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    final portPart = uri.hasPort ? ':${uri.port}' : '';
    return '$scheme://${uri.host}$portPart';
  }

  void _scheduleRealtimeReconnect() {
    _realtimeReconnectTimer?.cancel();
    _realtimeReconnectTimer = Timer(
      const Duration(seconds: 5),
      _connectRealtime,
    );
  }

  void _queueRealtimeRefresh() {
    if (_realtimeRefreshDebounce?.isActive == true) return;
    _realtimeRefreshDebounce = Timer(const Duration(milliseconds: 500), () {
      _refresh();
    });
  }

  Future<void> _connectRealtime() async {
    if (!mounted || _realtimeConnecting) return;
    final base = _normalizeBaseUrl(_baseUrlController.text);
    if (base.isEmpty) return;
    final wsUrl = '${_toWsUrl(base)}/ws/updates';
    final isOpen =
        _realtimeSocket != null &&
        _realtimeSocket!.readyState == WebSocket.open;
    if (isOpen && _connectedWsUrl == wsUrl) return;

    _realtimeConnecting = true;
    _realtimeReconnectTimer?.cancel();
    _closeRealtimeSocket();
    try {
      final socket = await WebSocket.connect(
        wsUrl,
      ).timeout(const Duration(seconds: 5));
      _realtimeSocket = socket;
      _connectedWsUrl = wsUrl;
      socket.listen(
        (raw) {
          try {
            if (raw is! String) return;
            final map = jsonDecode(raw) as Map<String, dynamic>;
            final type = (map['type'] ?? '').toString();
            final revision = (map['revision'] as num?)?.toInt() ?? 0;
            if (revision > 0) {
              if (revision <= _lastRealtimeRevision) return;
              _lastRealtimeRevision = revision;
            }
            if (type == 'config_changed' || type == 'device_status_changed') {
              _queueRealtimeRefresh();
            }
          } catch (_) {
            // Ignore malformed message and keep socket alive.
          }
        },
        onDone: _scheduleRealtimeReconnect,
        onError: (_) => _scheduleRealtimeReconnect(),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleRealtimeReconnect();
    } finally {
      _realtimeConnecting = false;
    }
  }

  Future<String?> _probeBaseUrl(String url) async {
    final normalized = _normalizeBaseUrl(url);
    if (normalized.isEmpty) return null;
    final parsed = Uri.tryParse(normalized);
    if (parsed == null || parsed.host.isEmpty) return null;
    final host = parsed.host;
    final port = parsed.hasPort ? parsed.port : 8000;
    final probes = <String>['http://$host:$port'];

    for (final probeUrl in probes) {
      final probeParsed = Uri.parse(probeUrl);
      final scheme = probeParsed.scheme;
      try {
        final res = await http
            .get(Uri.parse('$probeUrl/server-info'))
            .timeout(const Duration(milliseconds: 500));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final base = _normalizeBaseUrl((data['base_url'] ?? '').toString());
          if (base.isNotEmpty) return base;
          final discoveredPort = (data['server_port'] ?? '$port')
              .toString()
              .trim();
          if (discoveredPort.isNotEmpty)
            return '$scheme://$host:$discoveredPort';
          return '$scheme://$host';
        }

        final fallback = await http
            .get(Uri.parse('$probeUrl/healthz'))
            .timeout(const Duration(milliseconds: 450));
        if (fallback.statusCode == 200) {
          final data = jsonDecode(fallback.body) as Map<String, dynamic>;
          final discoveredPort = (data['server_port'] ?? '$port')
              .toString()
              .trim();
          if (discoveredPort.isNotEmpty)
            return '$scheme://$host:$discoveredPort';
          return '$scheme://$host';
        }
      } catch (_) {}
    }
    return null;
  }

  String _normalizeBaseUrl(String value) {
    var out = value.trim();
    if (out.isEmpty) return '';
    if (out.startsWith('https://')) {
      out = 'http://${out.substring('https://'.length)}';
    }
    if (!out.startsWith(RegExp(r'https?://'))) {
      out = 'http://$out';
    }
    while (out.endsWith('/')) {
      out = out.substring(0, out.length - 1);
    }
    final parsed = Uri.tryParse(out);
    if (parsed != null && parsed.host.isNotEmpty) {
      final port = parsed.hasPort ? parsed.port : 8000;
      out = 'http://${parsed.host}:$port';
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

    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
    );
    for (final iface in interfaces) {
      for (final address in iface.addresses) {
        final ip = address.address;
        if (!(ip.startsWith('192.168.') ||
            ip.startsWith('10.') ||
            ip.startsWith('172.'))) {
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
    _connectRealtime();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    final baseUrl = _normalizeBaseUrl(_baseUrlController.text);
    if (baseUrl != _baseUrlController.text.trim()) {
      _baseUrlController.text = baseUrl;
    }
    if (baseUrl.isNotEmpty) {
      final canonical = await _probeBaseUrl(baseUrl);
      if (canonical != null &&
          canonical.isNotEmpty &&
          canonical != _baseUrlController.text.trim()) {
        _baseUrlController.text = canonical;
        _connectRealtime();
      }
    }
    if (baseUrl.isEmpty) {
      _showMessage('Base URL belum diisi');
      return;
    }
    _connectRealtime();

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
        _selectedDeviceIds.removeWhere(
          (id) => !availableDeviceIds.contains(id),
        );
        if (_selectedDeviceIds.isEmpty && devices.isNotEmpty)
          _selectedDeviceIds.add(devices.first.id);
        if (_gridTargetDeviceId != null &&
            !availableDeviceIds.contains(_gridTargetDeviceId!)) {
          _gridTargetDeviceId = null;
          _gridTargetPreviewItems = [];
        }
        if (_gridTargetDeviceId == null && devices.isNotEmpty) {
          _gridTargetDeviceId = devices.first.id;
        }

        final availableMediaIds = mediaPage.items.map((m) => m.id).toSet();
        _selectedMediaIds.removeWhere((id) => !availableMediaIds.contains(id));
        _mediaDurations.removeWhere(
          (key, _) => !availableMediaIds.contains(key),
        );
      });
      await _loadScreens();
      if (_gridTargetDeviceId != null && _gridTargetPreviewItems.isEmpty) {
        await _loadGridPreviewForDevice(_gridTargetDeviceId!);
      }
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
        _selectedScreenId = null;
        _selectedPlaylistId = null;
        _bulkPlaylistName = null;
        _deviceNowPlayingName.clear();
        _deviceNowPlayingPlaylistId.clear();
        _deviceGridPreset.clear();
        _devicePlaylistSelection.clear();
        _gridTargetDeviceId = null;
        _gridTargetTransitionDuration = 1;
        _gridTargetPreviewItems = [];
      });
      return;
    }
    try {
      final firstDeviceId = _devices
          .map((d) => d.id)
          .firstWhere(
            (id) => _selectedDeviceIds.contains(id),
            orElse: () => _selectedDeviceIds.first,
          );
      final screens = await _api.listScreensForDevice(firstDeviceId);
      setState(() {
        final hasSelected =
            _selectedScreenId != null &&
            screens.any((s) => s.id == _selectedScreenId);
        if (!hasSelected) {
          _selectedScreenId = screens.isNotEmpty ? screens.first.id : null;
          _selectedPlaylistId = null;
        }
        ScreenInfo? activeScreen;
        if (_selectedScreenId != null) {
          for (final screen in screens) {
            if (screen.id == _selectedScreenId) {
              activeScreen = screen;
              break;
            }
          }
        }
        if (activeScreen?.gridPreset != null &&
            activeScreen!.gridPreset!.isNotEmpty &&
            _selectedScreenId != null) {
          _screenGridPresets[_selectedScreenId!] = activeScreen.gridPreset!;
        }
        if (_selectedScreenId != null) {
          _screenTransitionDurations[_selectedScreenId!] =
              _sanitizeTransitionDuration(activeScreen?.transitionDurationSec);
        }
      });
      await _loadPlaylists();
      await _loadPlaylistLibrary();
      await _refreshNowPlayingForSelectedDevices();
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<void> _loadPlaylistLibrary() async {
    if (_devices.isEmpty) {
      setState(() {
        _playlistLibrary = [];
      });
      return;
    }
    final templates = <_PlaylistTemplate>[];
    for (final device in _devices) {
      final config = await _api.fetchDeviceConfigRaw(device.id);
      final rawScreens = (config['screens'] as List<dynamic>? ?? const []);
      final screens = rawScreens
          .whereType<Map>()
          .map((s) => Map<String, dynamic>.from(s.cast<String, dynamic>()))
          .toList();
      if (screens.isEmpty) continue;

      final rawPlaylists = (config['playlists'] as List<dynamic>? ?? const []);
      final playlists = rawPlaylists
          .whereType<Map>()
          .map((p) => Map<String, dynamic>.from(p.cast<String, dynamic>()))
          .toList();
      for (final map in playlists) {
        final playlistId = (map['id'] ?? '').toString().trim();
        final screenId = (map['screen_id'] ?? '').toString().trim();
        if (playlistId.isEmpty || screenId.isEmpty) continue;
        final name = (map['name'] ?? '').toString().trim();
        final isFlashSale = map['is_flash_sale'] == true;
        final flashNote = (map['flash_note'] ?? '').toString().trim();
        final flashCountdownSec = (map['flash_countdown_sec'] as num?)?.toInt();
        final flashItemsJson = (map['flash_items_json'] ?? '').toString();
        templates.add(
          _PlaylistTemplate(
            playlistId: playlistId,
            name: name.isEmpty ? playlistId : name,
            deviceId: device.id,
            deviceName: device.name,
            isFlashSale: isFlashSale,
            flashNote: flashNote,
            flashCountdownSec: flashCountdownSec,
            flashItemsJson: flashItemsJson,
          ),
        );
      }
    }
    setState(() {
      _playlistLibrary = templates;
    });
    _syncDevicePlaylistSelections();
    await _loadManagePlaylistData();
  }

  Future<void> _loadPlaylists() async {
    if (_selectedScreenId == null) return;
    try {
      final playlists = await _api.listPlaylists(_selectedScreenId!);
      setState(() {
        _playlists = playlists;
        final hasSelected =
            _selectedPlaylistId != null &&
            playlists.any((p) => p.id == _selectedPlaylistId);
        if (!hasSelected) {
          _selectedPlaylistId = playlists.isNotEmpty
              ? playlists.first.id
              : null;
        }
        final hasManageSelected =
            _managePlaylistId != null &&
            playlists.any((p) => p.id == _managePlaylistId);
        if (!hasManageSelected) {
          _managePlaylistId = playlists.isNotEmpty ? playlists.first.id : null;
        }
      });
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<void> _loadManagePlaylistData() async {
    final playlistId = _managePlaylistId;
    if (playlistId == null || playlistId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _managePlaylistNameController.text = '';
        _manageAddMediaId = null;
        _managePlaylistItems = [];
        _manageSelectedItemIds.clear();
        _managePlaylistLoading = false;
        _managePlaylistDirty = false;
      });
      return;
    }

    setState(() => _managePlaylistLoading = true);
    try {
      final mediaById = <String, MediaInfo>{
        for (final item in _media) item.id: item,
      };
      final itemsRaw = await _api.listPlaylistItems(playlistId);

      var playlistName = playlistId;
      for (final item in _playlists) {
        if (item.id == playlistId) {
          playlistName = item.name;
          break;
        }
      }

      final mapped = <_ManagePlaylistItem>[];
      for (final item in itemsRaw) {
        final itemId = item.id.trim();
        if (itemId.isEmpty) continue;
        final mediaId = item.mediaId.trim();
        final order = item.order;
        final duration = item.durationSec;
        final media = mediaById[mediaId];
        final mediaPath = media?.path ?? '';
        final mediaType = media?.type ?? '';
        final mediaName = media?.name.isNotEmpty == true
            ? media!.name
            : (mediaPath.isEmpty
                  ? mediaId
                  : mediaPath.split('/').last.split('\\').last);
        mapped.add(
          _ManagePlaylistItem(
            itemId: itemId,
            mediaId: mediaId,
            order: order,
            durationSec: duration,
            mediaName: mediaName,
            mediaType: mediaType,
          ),
        );
      }

      if (_manageSelectedItemIds.isNotEmpty) {
        _manageSelectedItemIds.removeWhere(
          (itemId) => !mapped.any((row) => row.itemId == itemId),
        );
      }

      if (!mounted) return;
      setState(() {
        _managePlaylistNameController.text = playlistName;
        if (_manageAddMediaId == null ||
            !mediaById.containsKey(_manageAddMediaId)) {
          _manageAddMediaId = _media.isNotEmpty ? _media.first.id : null;
        }
        _managePlaylistItems = mapped;
        _managePlaylistLoading = false;
        _managePlaylistDirty = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _managePlaylistLoading = false);
      _showMessage(e.toString());
    }
  }

  Future<void> _addMediaToManagedPlaylist() async {
    final playlistId = _managePlaylistId;
    final mediaId = _manageAddMediaId;
    if (playlistId == null || mediaId == null || mediaId.isEmpty) {
      _showMessage('Pilih media yang akan ditambahkan');
      return;
    }
    MediaInfo? media;
    for (final item in _media) {
      if (item.id == mediaId) {
        media = item;
        break;
      }
    }
    if (media == null) {
      _showMessage('Media tidak ditemukan');
      return;
    }
    final isVideo = media.type == 'video' || _isVideoPath(media.path);
    final order = _managePlaylistItems.isEmpty
        ? 1
        : (_managePlaylistItems
                  .map((item) => item.order)
                  .reduce((a, b) => a > b ? a : b) +
              1);
    final duration =
        int.tryParse(_manageAddDurationController.text.trim()) ?? _durationSec;
    try {
      await _api.addPlaylistItem(
        playlistId: playlistId,
        mediaId: media.id,
        order: order,
        durationSec: isVideo ? null : duration,
      );
      _showMessage('Media ditambahkan ke playlist');
      await _loadManagePlaylistData();
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  void _reorderManagedPlaylistItems(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _managePlaylistItems.removeAt(oldIndex);
      _managePlaylistItems.insert(newIndex, item);
      _managePlaylistDirty = true;
    });
  }

  Future<void> _updateManagedPlaylist() async {
    final playlistId = _managePlaylistId;
    if (playlistId == null || playlistId.isEmpty) {
      _showMessage('Pilih playlist dulu');
      return;
    }
    if (!_managePlaylistDirty) {
      _showMessage('Belum ada perubahan urutan media');
      return;
    }
    try {
      for (var i = 0; i < _managePlaylistItems.length; i++) {
        await _api.updatePlaylistItem(
          itemId: _managePlaylistItems[i].itemId,
          order: i + 1,
        );
      }
      _showMessage('Playlist berhasil diupdate');
      await _loadManagePlaylistData();
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<void> _renameManagedPlaylist() async {
    final playlistId = _managePlaylistId;
    if (playlistId == null || playlistId.isEmpty) {
      _showMessage('Pilih playlist dulu');
      return;
    }
    final nextName = _managePlaylistNameController.text.trim();
    if (nextName.isEmpty) {
      _showMessage('Nama playlist tidak boleh kosong');
      return;
    }
    try {
      await _api.updatePlaylistName(playlistId, nextName);
      _showMessage('Nama playlist diperbarui');
      await _loadPlaylistLibrary();
      await _loadManagePlaylistData();
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<void> _deleteManagedPlaylistItems() async {
    if (_manageSelectedItemIds.isEmpty) {
      _showMessage('Pilih item media dulu');
      return;
    }
    try {
      for (final itemId in _manageSelectedItemIds.toList()) {
        await _api.deletePlaylistItem(itemId);
      }
      _showMessage('Item media terpilih dihapus');
      await _loadManagePlaylistData();
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<void> _deleteManagedPlaylist() async {
    final playlistId = _managePlaylistId;
    if (playlistId == null || playlistId.isEmpty) {
      _showMessage('Pilih playlist dulu');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus playlist'),
        content: const Text('Yakin hapus playlist ini?'),
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
      ),
    );
    if (confirm != true) return;

    try {
      await _api.deletePlaylist(playlistId);
      _showMessage('Playlist dihapus');
      setState(() {
        _managePlaylistId = null;
        _managePlaylistDirty = false;
      });
      await _loadPlaylists();
      await _loadPlaylistLibrary();
      await _loadManagePlaylistData();
      await _refreshNowPlayingForSelectedDevices();
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  void _syncDevicePlaylistSelections() {
    for (final deviceId in _selectedDeviceIds) {
      final devicePlaylists = _playlistsForDevice(deviceId);
      final current = _devicePlaylistSelection[deviceId];
      if (current != null &&
          devicePlaylists.any((p) => p.playlistId == current)) {
        continue;
      }
      final nowPlayingId = _deviceNowPlayingPlaylistId[deviceId];
      if (nowPlayingId != null &&
          devicePlaylists.any((p) => p.playlistId == nowPlayingId)) {
        _devicePlaylistSelection[deviceId] = nowPlayingId;
      } else if (devicePlaylists.isNotEmpty) {
        _devicePlaylistSelection[deviceId] = devicePlaylists.first.playlistId;
      } else {
        _devicePlaylistSelection[deviceId] = null;
      }
    }
    _devicePlaylistSelection.removeWhere(
      (deviceId, _) => !_selectedDeviceIds.contains(deviceId),
    );
  }

  int _parseClockMinutes(String value) {
    final parts = value.split(':');
    if (parts.length < 2) return -1;
    final hh = int.tryParse(parts[0]) ?? -1;
    final mm = int.tryParse(parts[1]) ?? -1;
    if (hh < 0 || mm < 0) return -1;
    return hh * 60 + mm;
  }

  String? _resolvePlaylistIdFromConfig(Map<String, dynamic> config) {
    final rawPlaylists = (config['playlists'] as List<dynamic>? ?? const []);
    final playlists = rawPlaylists
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e.cast<String, dynamic>()))
        .toList();
    if (playlists.isEmpty) return null;

    final rawScreens = (config['screens'] as List<dynamic>? ?? const []);
    if (rawScreens.isEmpty) {
      return playlists.first['id']?.toString();
    }
    final firstScreenRaw = rawScreens.first;
    if (firstScreenRaw is! Map) return playlists.first['id']?.toString();
    final firstScreen = Map<String, dynamic>.from(
      firstScreenRaw.cast<String, dynamic>(),
    );
    return _resolvePlaylistIdForScreen(playlists, firstScreen);
  }

  String? _resolvePlaylistIdForScreen(
    List<Map<String, dynamic>> playlists,
    Map<String, dynamic> screen,
  ) {
    if (playlists.isEmpty) return null;
    final forced = (screen['active_playlist_id'] ?? '').toString().trim();
    if (forced.isNotEmpty && playlists.any((p) => '${p['id']}' == forced)) {
      return forced;
    }

    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final day = now.weekday % 7;
    final schedules = (screen['schedules'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e.cast<String, dynamic>()))
        .toList();
    for (final schedule in schedules) {
      if ((schedule['day_of_week'] as num?)?.toInt() != day) continue;
      final start = _parseClockMinutes(
        (schedule['start_time'] ?? '').toString(),
      );
      final end = _parseClockMinutes((schedule['end_time'] ?? '').toString());
      if (start < 0 || end < 0) continue;
      if (nowMinutes >= start && nowMinutes < end) {
        final schedulePlaylistId = (schedule['playlist_id'] ?? '')
            .toString()
            .trim();
        if (schedulePlaylistId.isNotEmpty &&
            playlists.any((p) => '${p['id']}' == schedulePlaylistId)) {
          return schedulePlaylistId;
        }
      }
    }
    return playlists.first['id']?.toString();
  }

  Future<void> _refreshNowPlayingForSelectedDevices() async {
    if (_selectedDeviceIds.isEmpty) {
      if (mounted) {
        setState(() {
          _deviceNowPlayingName.clear();
          _deviceNowPlayingPlaylistId.clear();
          _deviceGridPreset.clear();
        });
      }
      return;
    }
    final names = <String, String>{};
    final ids = <String, String?>{};
    final gridByDevice = <String, String>{};
    for (final deviceId in _selectedDeviceIds) {
      try {
        final config = await _api.fetchDeviceConfigRaw(deviceId);
        final playlistId = _resolvePlaylistIdFromConfig(config);
        ids[deviceId] = playlistId;
        final rawScreens = (config['screens'] as List<dynamic>? ?? const []);
        String gridPreset = '1x1';
        for (final screen in rawScreens) {
          if (screen is Map) {
            final found = (screen['grid_preset'] ?? '').toString().trim();
            if (found.isNotEmpty) {
              gridPreset = found;
              break;
            }
          }
        }
        gridByDevice[deviceId] = gridPreset;
        if (playlistId == null || playlistId.isEmpty) {
          names[deviceId] = 'No playlist';
          continue;
        }
        final rawPlaylists =
            (config['playlists'] as List<dynamic>? ?? const []);
        String label = playlistId;
        for (final item in rawPlaylists) {
          if (item is Map && '${item['id']}' == playlistId) {
            label = (item['name'] ?? playlistId).toString();
            break;
          }
        }
        names[deviceId] = label;
      } catch (_) {
        names[deviceId] = 'Unknown';
        ids[deviceId] = null;
        gridByDevice[deviceId] = '-';
      }
    }
    if (!mounted) return;
    setState(() {
      _deviceNowPlayingName
        ..clear()
        ..addAll(names);
      _deviceNowPlayingPlaylistId
        ..clear()
        ..addAll(ids);
      _deviceGridPreset
        ..clear()
        ..addAll(gridByDevice);
      _syncDevicePlaylistSelections();
    });
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickFile() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform
          .pickFiles(
            allowMultiple: true,
            type: FileType.custom,
            allowedExtensions: [
              ..._videoExtensions,
              ..._imageExtensions,
            ].map((e) => e.replaceFirst('.', '')).toList(),
          )
          .timeout(const Duration(seconds: 25));
    } on TimeoutException {
      _showMessage('Dialog pilih file timeout. Coba lagi.');
      return;
    } on PlatformException catch (e) {
      _showMessage('File picker error: ${e.message ?? e.code}');
      return;
    } catch (e) {
      _showMessage('Gagal membuka file picker: $e');
      return;
    }
    if (result == null || result.files.isEmpty) return;
    final files = result.files
        .where((f) => f.path != null)
        .map((f) => File(f.path!))
        .toList();
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

  String _formatHms(String input) {
    final cleaned = input.trim();
    if (cleaned.isEmpty) return '';
    final parts = cleaned.split(':');
    if (parts.length < 2 || parts.length > 3) return '';
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final s = parts.length == 3 ? int.tryParse(parts[2]) : 0;
    if (h == null || m == null || s == null) return '';
    if (h < 0 || h > 23 || m < 0 || m > 59 || s < 0 || s > 59) return '';
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  List<int> _flashSaleCountdownPresetSeconds() {
    return const [300, 600, 900, 1800, 3600];
  }

  String _flashSaleCountdownLabel(int seconds) {
    if (seconds % 3600 == 0) {
      final h = seconds ~/ 3600;
      return '$h jam';
    }
    if (seconds % 60 == 0) {
      final m = seconds ~/ 60;
      return '$m menit';
    }
    return '$seconds detik';
  }

  List<DeviceInfo> _flashSaleLandscapeDevices() {
    return _devices
        .where((device) => (device.orientation ?? 'portrait') == 'landscape')
        .toList();
  }

  String _normalizedText(String value) => value.trim().toLowerCase();

  List<_PlaylistTemplate> _flashSalePlaylists() {
    final rows = _playlistLibrary.where((item) => item.isFlashSale).toList();
    rows.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
    return rows;
  }

  List<String> _flashSaleSourcePlaylistOptions() {
    final names = <String>{};
    for (final item in _playlistLibrary) {
      final value = item.name.trim();
      if (value.isEmpty) continue;
      names.add(value);
    }
    final result = names.toList();
    result.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return result;
  }

  _PlaylistTemplate? _findFlashSaleSourceTemplate() {
    final target = (_flashSaleSourcePlaylistName ?? '').trim();
    if (target.isEmpty) return null;
    for (final item in _playlistLibrary) {
      if (_normalizedText(item.name) == _normalizedText(target)) return item;
    }
    return null;
  }

  List<MediaInfo> _flashSaleMediaOptions() {
    final rows = [..._media];
    rows.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return rows;
  }

  String _flashSaleMediaLabelById(String? mediaId) {
    final id = (mediaId ?? '').trim();
    if (id.isEmpty) return 'Media belum dipilih';
    for (final media in _media) {
      if (media.id == id) {
        final name = media.name.trim().isEmpty ? media.id : media.name.trim();
        return '$name (${media.type})';
      }
    }
    return '$id (media tidak ditemukan di list saat ini)';
  }

  void _prefillFlashSaleMetaFromTemplate(_PlaylistTemplate template) {
    if (template.flashNote.trim().isNotEmpty) {
      _flashSaleNoteController.text = template.flashNote.trim();
    }
    if ((template.flashCountdownSec ?? 0) > 0) {
      _flashSaleCountdownController.text = '${template.flashCountdownSec}';
    }
    final raw = template.flashItemsJson.trim();
    if (raw.isNotEmpty) {
      _applyFlashProductsFromJson(raw);
    }
    _resetFlashSaleMediaCheckStatus();
  }

  Future<void> _ensurePlaylistFlashSale(_PlaylistTemplate template) async {
    if (template.isFlashSale) return;
    await _api.updatePlaylistFlashSale(template.playlistId, true);
  }

  int? _flashSaleCountdownFromInput() {
    final value = int.tryParse(_flashSaleCountdownController.text.trim());
    if (value == null || value <= 0) return null;
    return value;
  }

  String _flashSaleNoteFromInput() => _flashSaleNoteController.text.trim();

  bool _validateFlashSaleMetaInput() {
    final note = _flashSaleNoteFromInput();
    if (note.isEmpty) {
      _showMessage('Note Flash Sale wajib diisi untuk running text mobile');
      return false;
    }
    final countdown = _flashSaleCountdownFromInput();
    if (countdown == null) {
      _showMessage('Countdown Flash Sale wajib diisi (detik) dan > 0');
      return false;
    }
    final productRows = _flashSaleProducts
        .map((item) => item.toJson())
        .where((item) => (item['name'] ?? '').toString().trim().isNotEmpty)
        .toList();
    if (productRows.isEmpty) {
      _showMessage('Tambahkan minimal 1 produk Flash Sale');
      return false;
    }
    for (var i = 0; i < productRows.length; i += 1) {
      final mediaId = (productRows[i]['media_id'] ?? '').toString().trim();
      if (mediaId.isEmpty) {
        _showMessage('Media produk #${i + 1} wajib dipilih');
        return false;
      }
    }
    _flashSaleCountdownController.text = countdown.toString();
    return true;
  }

  String _flashSaleProductsJson() {
    final rows = _flashSaleProducts
        .map((item) => item.toJson())
        .where((item) => (item['name'] ?? '').toString().trim().isNotEmpty)
        .toList();
    return jsonEncode(rows);
  }

  void _applyFlashProductsFromJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final next = <_FlashSaleProductDraft>[];
      for (final row in decoded) {
        if (row is! Map) continue;
        final name = (row['name'] ?? '').toString();
        final brand = (row['brand'] ?? '').toString();
        final normalPrice = (row['normal_price'] ?? '').toString();
        final promoPrice = (row['promo_price'] ?? '').toString();
        final stock = (row['stock'] ?? '').toString();
        final mediaId = (row['media_id'] ?? '').toString();
        next.add(
          _FlashSaleProductDraft(
            name: name,
            brand: brand,
            normalPrice: normalPrice,
            promoPrice: promoPrice,
            stock: stock,
            mediaId: mediaId,
          ),
        );
      }
      if (next.isEmpty) return;
      _flashSaleProducts
        ..clear()
        ..addAll(next);
    } catch (_) {}
  }

  Future<void> _editFlashSaleProduct(int index) async {
    if (index < 0 || index >= _flashSaleProducts.length) return;
    final current = _flashSaleProducts[index];
    final nameController = TextEditingController(text: current.name);
    final brandController = TextEditingController(text: current.brand);
    final normalPriceController = TextEditingController(
      text: current.normalPrice,
    );
    final promoPriceController = TextEditingController(
      text: current.promoPrice,
    );
    final stockController = TextEditingController(text: current.stock);
    final mediaOptions = _flashSaleMediaOptions();
    String selectedMediaId = current.mediaId.trim();
    final mediaExists = mediaOptions.any((item) => item.id == selectedMediaId);
    if (selectedMediaId.isNotEmpty && !mediaExists) {
      selectedMediaId = '';
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: Text('Edit Produk ${index + 1}'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nama produk',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: brandController,
                        decoration: const InputDecoration(labelText: 'Brand'),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: selectedMediaId.isEmpty
                            ? null
                            : selectedMediaId,
                        hint: const Text('Pilih media untuk produk ini'),
                        items: mediaOptions
                            .map(
                              (media) => DropdownMenuItem(
                                value: media.id,
                                child: Text(
                                  '${media.name.isEmpty ? media.id : media.name} (${media.type})',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setLocalState(() => selectedMediaId = value ?? '');
                        },
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: normalPriceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Harga normal (angka, contoh 129000)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: promoPriceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Harga promo (angka, contoh 79000)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: stockController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Stok tersisa (angka)',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) return;
    setState(() {
      _flashSaleProducts[index] = _FlashSaleProductDraft(
        name: nameController.text.trim(),
        brand: brandController.text.trim(),
        normalPrice: normalPriceController.text.trim(),
        promoPrice: promoPriceController.text.trim(),
        stock: stockController.text.trim(),
        mediaId: selectedMediaId.trim(),
      );
      _resetFlashSaleMediaCheckStatus();
    });
  }

  List<String> _flashSaleTargetDeviceIds() {
    final landscapeDeviceIds = _flashSaleLandscapeDevices()
        .map((device) => device.id)
        .toSet();
    return _flashSaleDeviceIds.where(landscapeDeviceIds.contains).toList();
  }

  Set<String> _flashSaleProductMediaIds() {
    return _flashSaleProducts
        .map((item) => item.mediaId.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  void _resetFlashSaleMediaCheckStatus() {
    _flashSaleMediaCheckedAt = null;
    _flashSaleMissingMediaByDevice.clear();
    _flashSaleMediaErrorByDevice.clear();
  }

  Future<void> _checkFlashSaleMediaSyncStatus() async {
    if (_flashSaleMediaCheckBusy) return;
    final targetDeviceIds = _flashSaleTargetDeviceIds();
    if (targetDeviceIds.isEmpty) {
      _showMessage('Pilih minimal satu device target untuk cek sinkron media');
      return;
    }
    final requiredMediaIds = _flashSaleProductMediaIds();
    if (requiredMediaIds.isEmpty) {
      _showMessage('Pilih media pada produk Flash Sale dulu');
      return;
    }

    setState(() {
      _flashSaleMediaCheckBusy = true;
      _flashSaleMissingMediaByDevice.clear();
      _flashSaleMediaErrorByDevice.clear();
    });

    try {
      for (final deviceId in targetDeviceIds) {
        try {
          final config = await _api.fetchDeviceConfigRaw(deviceId);
          final mediaRaw = (config['media'] as List<dynamic>? ?? const []);
          final mediaIds = <String>{};
          for (final row in mediaRaw) {
            if (row is! Map) continue;
            final id = '${row['id']}'.trim();
            if (id.isNotEmpty) mediaIds.add(id);
          }
          final missing = requiredMediaIds.where((id) => !mediaIds.contains(id));
          _flashSaleMissingMediaByDevice[deviceId] = missing
              .map(_flashSaleMediaLabelById)
              .toList();
        } catch (e) {
          _flashSaleMediaErrorByDevice[deviceId] = e.toString();
        }
      }
      _flashSaleMediaCheckedAt = DateTime.now();
    } finally {
      if (mounted) setState(() => _flashSaleMediaCheckBusy = false);
    }
  }

  Future<void> _runFlashSaleNow() async {
    if (_flashSaleBusy) return;
    if (!_validateFlashSaleMetaInput()) return;
    final targetDeviceIds = _flashSaleTargetDeviceIds();
    if (targetDeviceIds.isEmpty) {
      _showMessage('Pilih minimal satu device untuk Flash Sale');
      return;
    }

    setState(() => _flashSaleBusy = true);
    try {
      final note = _flashSaleNoteFromInput();
      final countdownSec = _flashSaleCountdownFromInput() ?? 0;
      final productsJson = _flashSaleProductsJson();
      final failed = <String>[];
      for (final deviceId in targetDeviceIds) {
        try {
          await _api.upsertFlashSaleNow(
            deviceId: deviceId,
            note: note,
            countdownSec: countdownSec,
            productsJson: productsJson,
          );
        } catch (_) {
          failed.add(deviceId);
        }
      }

      if (failed.isEmpty) {
        _showMessage('Flash Sale berhasil ditayangkan sekarang');
      } else {
        _showMessage(
          'Sebagian gagal tayang. Device gagal: ${failed.join(', ')}',
        );
      }
      await _refreshNowPlayingForSelectedDevices();
    } catch (e) {
      _showMessage(e.toString());
    } finally {
      if (mounted) setState(() => _flashSaleBusy = false);
    }
  }

  Future<void> _openScheduleFlashSaleDialog() async {
    if (_flashSaleBusy) return;
    if (!_validateFlashSaleMetaInput()) return;
    final targetDeviceIds = _flashSaleTargetDeviceIds();
    if (targetDeviceIds.isEmpty) {
      _showMessage('Pilih minimal satu device untuk Flash Sale');
      return;
    }

    final dayLabels = <int, String>{
      1: 'Sen',
      2: 'Sel',
      3: 'Rab',
      4: 'Kam',
      5: 'Jum',
      6: 'Sab',
      0: 'Min',
    };
    final selectedDays = <int>{..._flashSaleScheduleDays};
    final startController = TextEditingController(
      text: _flashSaleScheduleStartController.text,
    );
    final endController = TextEditingController(
      text: _flashSaleScheduleEndController.text,
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('Jadwalkan Flash Sale'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Atur hari dan jam tayang. Countdown mengikuti nilai Flash Sale.',
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: dayLabels.entries.map((entry) {
                          final selected = selectedDays.contains(entry.key);
                          return FilterChip(
                            label: Text(entry.value),
                            selected: selected,
                            onSelected: (value) {
                              setLocalState(() {
                                if (value) {
                                  selectedDays.add(entry.key);
                                } else {
                                  selectedDays.remove(entry.key);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: startController,
                              decoration: const InputDecoration(
                                labelText: 'Jam mulai (HH:MM)',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: endController,
                              decoration: const InputDecoration(
                                labelText: 'Jam selesai (HH:MM)',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Simpan Jadwal'),
                ),
              ],
            );
          },
        );
      },
    );
    if (confirmed != true) return;

    _flashSaleScheduleStartController.text = startController.text;
    _flashSaleScheduleEndController.text = endController.text;
    _flashSaleScheduleDays
      ..clear()
      ..addAll(selectedDays);

    final startTime = _formatHms(_flashSaleScheduleStartController.text);
    final endTime = _formatHms(_flashSaleScheduleEndController.text);
    if (startTime.isEmpty || endTime.isEmpty) {
      _showMessage('Format waktu harus HH:MM atau HH:MM:SS');
      return;
    }
    if (_flashSaleScheduleDays.isEmpty) {
      _showMessage('Pilih minimal satu hari jadwal');
      return;
    }

    setState(() => _flashSaleBusy = true);
    try {
      final note = _flashSaleNoteFromInput();
      final countdownSec = _flashSaleCountdownFromInput() ?? 0;
      final productsJson = _flashSaleProductsJson();
      final daysCsv = _flashSaleScheduleDays.toList()..sort();
      final failed = <String>[];
      for (final deviceId in targetDeviceIds) {
        try {
          await _api.upsertFlashSaleSchedule(
            deviceId: deviceId,
            note: note,
            countdownSec: countdownSec,
            productsJson: productsJson,
            scheduleDaysCsv: daysCsv.join(','),
            startTime: startTime,
            endTime: endTime,
          );
        } catch (_) {
          failed.add(deviceId);
        }
      }
      if (failed.isEmpty) {
        _showMessage('Flash Sale berhasil dijadwalkan');
      } else {
        _showMessage(
          'Sebagian jadwal gagal. Device gagal: ${failed.join(', ')}',
        );
      }
      await _refreshNowPlayingForSelectedDevices();
    } catch (e) {
      _showMessage(e.toString());
    } finally {
      if (mounted) setState(() => _flashSaleBusy = false);
    }
  }

  Future<void> _disableFlashSaleForTargets() async {
    if (_flashSaleBusy) return;
    final targetDeviceIds = _flashSaleTargetDeviceIds();
    if (targetDeviceIds.isEmpty) {
      _showMessage('Pilih minimal satu device untuk menonaktifkan Flash Sale');
      return;
    }
    setState(() => _flashSaleBusy = true);
    try {
      final failed = <String>[];
      for (final deviceId in targetDeviceIds) {
        try {
          await _api.disableFlashSale(deviceId);
        } catch (_) {
          failed.add(deviceId);
        }
      }
      if (failed.isEmpty) {
        _showMessage('Flash Sale dinonaktifkan di semua device terpilih');
      } else {
        _showMessage('Sebagian gagal menonaktifkan Flash Sale: ${failed.join(', ')}');
      }
    } finally {
      if (mounted) setState(() => _flashSaleBusy = false);
    }
  }

  Future<void> _deleteFlashSalePlaylist(_PlaylistTemplate template) async {
    if (_flashSaleCleanupBusy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Hapus Flash Sale'),
          content: Text(
            'Hapus playlist "${template.name}" di device "${template.deviceName}"?',
          ),
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

    setState(() => _flashSaleCleanupBusy = true);
    try {
      await _api.deletePlaylist(template.playlistId);
      _showMessage('Flash Sale dihapus');
      await _loadPlaylistLibrary();
      await _refreshNowPlayingForSelectedDevices();
    } catch (e) {
      _showMessage(e.toString());
    } finally {
      if (mounted) setState(() => _flashSaleCleanupBusy = false);
    }
  }

  Future<void> _deleteSelectedFlashSalePlaylists() async {
    if (_flashSaleCleanupBusy) return;
    if (_selectedFlashSalePlaylistIds.isEmpty) {
      _showMessage('Pilih minimal satu playlist Flash Sale');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Hapus Flash Sale Terpilih'),
          content: Text(
            'Hapus ${_selectedFlashSalePlaylistIds.length} playlist Flash Sale yang dipilih?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Hapus Semua'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    setState(() => _flashSaleCleanupBusy = true);
    try {
      var deleted = 0;
      final failed = <String>[];
      final ids = _selectedFlashSalePlaylistIds.toList();
      for (final playlistId in ids) {
        try {
          await _api.deletePlaylist(playlistId);
          deleted += 1;
        } catch (_) {
          failed.add(playlistId);
        }
      }
      _selectedFlashSalePlaylistIds.clear();
      await _loadPlaylistLibrary();
      await _refreshNowPlayingForSelectedDevices();
      if (failed.isEmpty) {
        _showMessage('$deleted Flash Sale berhasil dihapus');
      } else {
        _showMessage('$deleted Flash Sale dihapus, gagal ${failed.length}');
      }
    } catch (e) {
      _showMessage(e.toString());
    } finally {
      if (mounted) setState(() => _flashSaleCleanupBusy = false);
    }
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
          _showMessage(
            'Tipe file tidak dikenali: ${file.uri.pathSegments.last}',
          );
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
    final controller = TextEditingController(
      text: 'Playlist-${DateTime.now().millisecondsSinceEpoch}',
    );
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
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Create'),
            ),
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
        final isVideo =
            media != null &&
            (media.type == 'video' || _isVideoPath(media.path));
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
      await _loadPlaylistLibrary();
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<_AppliedPlaylistTarget> _applyTemplateToDevice({
    required _PlaylistTemplate template,
    required String targetDeviceId,
    bool createIfMissing = false,
    bool markAsFlashSale = false,
    String? flashNote,
    int? flashCountdownSec,
    String? flashItemsJson,
  }) async {
    final templateNameNormalized = _normalizedText(template.name);
    final screens = await _api.listScreensForDevice(targetDeviceId);
    if (screens.isEmpty) {
      throw Exception('Device $targetDeviceId tidak punya screen');
    }
    String? foundScreenId;
    String? foundPlaylistId;

    // Same-device apply: prioritise exact playlist id match across all screens.
    if (template.deviceId == targetDeviceId) {
      for (final screen in screens) {
        final targetPlaylists = await _api.listPlaylists(screen.id);
        for (final playlist in targetPlaylists) {
          if (playlist.id == template.playlistId) {
            foundScreenId = screen.id;
            foundPlaylistId = playlist.id;
            break;
          }
        }
        if (foundPlaylistId != null) break;
      }
    }

    // Cross-device apply: match by playlist name across all screens.
    if (foundPlaylistId == null) {
      final targetName = templateNameNormalized;
      for (final screen in screens) {
        final targetPlaylists = await _api.listPlaylists(screen.id);
        for (final playlist in targetPlaylists) {
          if (_normalizedText(playlist.name) == targetName) {
            foundScreenId = screen.id;
            foundPlaylistId = playlist.id;
            break;
          }
        }
        if (foundPlaylistId != null) break;
      }
    }

    if (foundScreenId == null || foundPlaylistId == null) {
      if (!createIfMissing) {
        throw Exception(
          'Playlist "${template.name}" belum ada di device target.',
        );
      }
      final targetScreen = screens.first;
      final created = await _api.createPlaylist(
        targetScreen.id,
        template.name,
        isFlashSale: markAsFlashSale || template.isFlashSale,
      );
      final sourceItems = await _api.listPlaylistItems(template.playlistId);
      var nextOrder = 1;
      for (final item in sourceItems) {
        await _api.addPlaylistItem(
          playlistId: created.id,
          mediaId: item.mediaId,
          order: nextOrder,
          durationSec: item.durationSec,
        );
        nextOrder += 1;
      }
      foundScreenId = targetScreen.id;
      foundPlaylistId = created.id;
    }

    if (markAsFlashSale) {
      final normalizedFlashNote = (flashNote ?? template.flashNote).trim();
      final normalizedFlashItems =
          (flashItemsJson ?? template.flashItemsJson).trim();
      await _api.updatePlaylistFlashSale(foundPlaylistId, true);
      await _api.updatePlaylistFlashMeta(
        foundPlaylistId,
        note: normalizedFlashNote,
        countdownSec:
            flashCountdownSec ??
            ((template.flashCountdownSec ?? 0) > 0
                ? template.flashCountdownSec
                : 0),
        flashItemsJson: normalizedFlashItems,
      );
    }

    await _api.updateScreenSettings(
      screenId: foundScreenId,
      activePlaylistId: foundPlaylistId,
    );
    return _AppliedPlaylistTarget(
      screenId: foundScreenId,
      playlistId: foundPlaylistId,
    );
  }

  Future<void> _applyPerDevicePlaylistAssignments() async {
    if (_selectedDeviceIds.isEmpty) {
      _showMessage('Pilih minimal satu device');
      return;
    }
    try {
      final failed = <String>[];
      for (final deviceId in _selectedDeviceIds) {
        final templateId = _devicePlaylistSelection[deviceId];
        if (templateId == null || templateId.isEmpty) continue;
        _PlaylistTemplate? template;
        for (final item in _playlistLibrary) {
          if (item.playlistId == templateId) {
            template = item;
            break;
          }
        }
        if (template == null) continue;
        try {
          await _applyTemplateToDevice(
            template: template,
            targetDeviceId: deviceId,
          );
        } catch (_) {
          failed.add(deviceId);
        }
      }
      if (failed.isEmpty) {
        _showMessage(
          'Playlist per device berhasil diterapkan. Grid tidak berubah.',
        );
      } else {
        _showMessage(
          'Sebagian gagal. Playlist dengan nama yang sama belum ada di: ${failed.join(', ')}',
        );
      }
      await _loadPlaylistLibrary();
      await _refreshNowPlayingForSelectedDevices();
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  List<_PlaylistTemplate> _playlistsForDevice(String deviceId) {
    return _playlistLibrary.where((p) => p.deviceId == deviceId).toList();
  }

  List<String> _bulkPlaylistNameOptions() {
    final names = <String>{};
    for (final deviceId in _selectedDeviceIds) {
      final playlists = _playlistsForDevice(deviceId);
      for (final playlist in playlists) {
        final value = playlist.name.trim();
        if (value.isNotEmpty) names.add(value);
      }
    }
    final result = names.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return result;
  }

  Future<void> _applySamePlaylistToSelectedDevices() async {
    if (_selectedDeviceIds.isEmpty) {
      _showMessage('Pilih minimal satu device');
      return;
    }
    final playlistName = (_bulkPlaylistName ?? '').trim();
    if (playlistName.isEmpty) {
      _showMessage('Pilih playlist yang akan diterapkan');
      return;
    }

    _PlaylistTemplate? sourceTemplate;
    for (final item in _playlistLibrary) {
      if (_normalizedText(item.name) == _normalizedText(playlistName)) {
        sourceTemplate = item;
        break;
      }
    }
    if (sourceTemplate == null) {
      _showMessage('Playlist sumber tidak ditemukan');
      return;
    }

    final failed = <String>[];
    for (final deviceId in _selectedDeviceIds) {
      try {
        await _applyTemplateToDevice(
          template: sourceTemplate,
          targetDeviceId: deviceId,
          createIfMissing: true,
        );
      } catch (_) {
        failed.add(deviceId);
      }
    }

    await _loadPlaylistLibrary();
    await _refreshNowPlayingForSelectedDevices();

    if (failed.isEmpty) {
      _showMessage(
        'Playlist "$playlistName" berhasil diterapkan ke semua device terpilih.',
      );
    } else {
      _showMessage(
        'Sebagian gagal menerapkan "$playlistName". Device gagal: ${failed.join(', ')}',
      );
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

    if (confirm != true) return;

    try {
      await _api.deleteMedia(media.id);
      _showMessage('Media dihapus');
      await _refresh();
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  String _absoluteUrl(String path) {
    if (path.startsWith('http')) return path;
    return Uri.parse(_baseUrlController.text.trim()).resolve(path).toString();
  }

  String _gridPresetLabel(String preset) {
    switch (preset) {
      case '1x1':
        return 'Full Screen (1x1)';
      case '1x2':
        return 'Side by Side (1x2)';
      case '2x1':
        return 'Top & Bottom (2x1)';
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

  int _sanitizeTransitionDuration(int? value) {
    final raw = value ?? 1;
    if (raw < 0) return 0;
    if (raw > 30) return 30;
    return raw;
  }

  List<_GridPreviewItem> _gridItemsForCellFromSource(
    List<_GridPreviewItem> source,
    int cellIndex,
    int cellCount,
  ) {
    if (source.isEmpty) return const [];
    if (cellCount <= 1) return source;
    final total = source.length;
    final base = total ~/ cellCount;
    final extra = total % cellCount;
    final take = base + (cellIndex < extra ? 1 : 0);
    if (take <= 0) return const [];
    final start = (cellIndex * base) + (cellIndex < extra ? cellIndex : extra);
    final end = start + take;
    if (start < 0 || start >= total || end > total) return const [];
    return source.sublist(start, end);
  }

  Widget _buildGridCellMosaic(List<_GridPreviewItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = items.length;
        final cols = math.max(1, math.sqrt(count).ceil());
        final rows = (count / cols).ceil();
        const spacing = 3.0;
        final totalHSpace = (cols - 1) * spacing;
        final totalVSpace = (rows - 1) * spacing;
        final tileWidth = ((constraints.maxWidth - totalHSpace) / cols).clamp(
          14.0,
          constraints.maxWidth,
        );
        final tileHeight = ((constraints.maxHeight - totalVSpace) / rows).clamp(
          14.0,
          constraints.maxHeight,
        );

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var i = 0; i < items.length; i++)
              Tooltip(
                message: '${i + 1}. ${items[i].label}',
                child: SizedBox(
                  width: tileWidth,
                  height: tileHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (items[i].type.toLowerCase() == 'video')
                          const Center(
                            child: Icon(
                              Icons.play_circle_fill_rounded,
                              color: Colors.white70,
                              size: 18,
                            ),
                          )
                        else
                          Image.network(
                            _absoluteUrl(items[i].path),
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Center(
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    color: Colors.white70,
                                    size: 14,
                                  ),
                                ),
                          ),
                        Positioned(
                          top: 1,
                          left: 1,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 3,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildFullscreenGridPreview(List<_GridPreviewItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    final item = items.first;
    final isVideo = item.type.toLowerCase() == 'video';
    return Stack(
      fit: StackFit.expand,
      children: [
        if (isVideo)
          const Center(
            child: Icon(
              Icons.play_circle_fill_rounded,
              color: Colors.white70,
              size: 42,
            ),
          )
        else
          Image.network(
            _absoluteUrl(item.path),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Icon(Icons.broken_image_outlined, color: Colors.white70),
            ),
          ),
        Positioned(
          left: 6,
          right: 6,
          bottom: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        if (items.length > 1)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF0369A1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${items.length} konten',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }

  List<String> _gridPresetOptionsForOrientation(String orientation) {
    if (orientation == 'landscape') {
      return const [
        '1x1',
        '1x2',
        '1x3',
        '1x4',
        '2x2',
        '2x3',
        '2x4',
        '3x3',
        '3x4',
        '4x4',
      ];
    }
    return const [
      '1x1',
      '2x1',
      '3x1',
      '4x1',
      '2x2',
      '3x2',
      '4x2',
      '3x3',
      '4x3',
      '4x4',
    ];
  }

  Future<void> _loadGridPreviewForDevice(String deviceId) async {
    setState(() => _gridTargetLoading = true);
    try {
      final config = await _api.fetchDeviceConfigRaw(deviceId);
      final rawScreens = (config['screens'] as List<dynamic>? ?? const []);
      String orientation = 'portrait';
      for (final device in _devices) {
        if (device.id == deviceId) {
          orientation = (device.orientation == 'landscape')
              ? 'landscape'
              : 'portrait';
          break;
        }
      }
      String nextGrid = '1x1';
      var nextTransition = 1;
      if (rawScreens.isNotEmpty && rawScreens.first is Map) {
        final first = rawScreens.first as Map;
        final foundGrid = (first['grid_preset'] ?? '').toString().trim();
        if (foundGrid.isNotEmpty) {
          nextGrid = foundGrid;
        }
        nextTransition = _sanitizeTransitionDuration(
          (first['transition_duration_sec'] as num?)?.toInt(),
        );
      }
      final allowed = _gridPresetOptionsForOrientation(orientation);
      if (!allowed.contains(nextGrid)) {
        nextGrid = allowed.first;
      }

      final playlistId = _resolvePlaylistIdFromConfig(config);
      final rawPlaylists = (config['playlists'] as List<dynamic>? ?? const []);
      final rawMedia = (config['media'] as List<dynamic>? ?? const []);
      final mediaMap = <String, Map<String, dynamic>>{};
      for (final entry in rawMedia) {
        if (entry is Map) {
          final map = Map<String, dynamic>.from(entry.cast<String, dynamic>());
          mediaMap['${map['id']}'] = map;
        }
      }
      final previewItems = <_GridPreviewItem>[];
      if (playlistId != null && playlistId.isNotEmpty) {
        for (final entry in rawPlaylists) {
          if (entry is! Map) continue;
          final map = Map<String, dynamic>.from(entry.cast<String, dynamic>());
          if ('${map['id']}' != playlistId) continue;
          final items =
              (map['items'] as List<dynamic>? ?? const [])
                  .whereType<Map>()
                  .map(
                    (e) => Map<String, dynamic>.from(e.cast<String, dynamic>()),
                  )
                  .toList()
                ..sort(
                  (a, b) => ((a['order'] as num?)?.toInt() ?? 0).compareTo(
                    (b['order'] as num?)?.toInt() ?? 0,
                  ),
                );
          for (final item in items) {
            final mediaId = '${item['media_id']}';
            final media = mediaMap[mediaId];
            if (media == null) continue;
            previewItems.add(
              _GridPreviewItem(
                mediaId: mediaId,
                type: (media['type'] ?? 'image').toString(),
                path: (media['path'] ?? '').toString(),
                label: (media['name'] ?? mediaId).toString(),
              ),
            );
          }
          break;
        }
      }

      if (!mounted) return;
      setState(() {
        _gridTargetDeviceId = deviceId;
        _gridTargetPreset = nextGrid;
        _gridTargetTransitionDuration = nextTransition;
        _gridTargetPreviewItems = previewItems;
      });
    } catch (e) {
      _showMessage(e.toString());
    } finally {
      if (mounted) setState(() => _gridTargetLoading = false);
    }
  }

  Future<void> _setGridPresetForDevice(
    String deviceId,
    String preset,
    int transitionDurationSec,
  ) async {
    try {
      final screens = await _api.listScreensForDevice(deviceId);
      if (screens.isEmpty) {
        _showMessage('Device tidak memiliki screen');
        return;
      }
      final targetScreen = screens.first;
      final sanitizedDuration = _sanitizeTransitionDuration(
        transitionDurationSec,
      );
      await _api.updateScreenSettings(
        screenId: targetScreen.id,
        gridPreset: preset,
        transitionDurationSec: sanitizedDuration,
      );
      _screenGridPresets[targetScreen.id] = preset;
      _screenTransitionDurations[targetScreen.id] = sanitizedDuration;
      var targetName = deviceId;
      for (final device in _devices) {
        if (device.id == deviceId) {
          targetName = device.name;
          break;
        }
      }
      _showMessage(
        'Grid $preset dan transisi ${sanitizedDuration}s diterapkan ke $targetName',
      );
      await _refreshNowPlayingForSelectedDevices();
      await _loadGridPreviewForDevice(deviceId);
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  void _previewMedia(MediaInfo media) {
    final url = _absoluteUrl(media.path);
    final isVideo = media.type == 'video' || _isVideoPath(media.path);
    final isImage = media.type == 'image' || _isImagePath(media.path);

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog.fullscreen(
          child: Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              children: [
                Positioned.fill(
                  child: Center(
                    child: isVideo
                        ? _VideoPreview(url: url)
                        : isImage
                        ? Image.network(url, fit: BoxFit.contain)
                        : const Text(
                            'Unknown media type',
                            style: TextStyle(color: Colors.white),
                          ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 80,
                  top: 16,
                  child: Text(
                    media.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 30,
                    ),
                    tooltip: 'Close',
                  ),
                ),
              ],
            ),
          ),
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
                    });
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Done'),
            ),
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
      withGrid['desktop_transition_settings'] = _screenTransitionDurations;
      String? path;
      try {
        path = await FilePicker.platform
            .saveFile(
              dialogTitle: 'Save config',
              fileName: 'signage_config_$deviceId.json',
            )
            .timeout(const Duration(seconds: 25));
      } on TimeoutException {
        _showMessage('Dialog save timeout. Coba lagi.');
        return;
      } on PlatformException catch (e) {
        _showMessage('Save dialog error: ${e.message ?? e.code}');
        return;
      }
      if (path == null) return;
      final file = File(path);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(withGrid),
      );
      _showMessage('Export berhasil');
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<void> _setDeviceOrientation(
    DeviceInfo device,
    String orientation,
  ) async {
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
          content: Text(
            'Yakin ingin hapus ${selectedIds.length} device terpilih?',
          ),
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
    final compactTop = MediaQuery.sizeOf(context).width < 1060;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Content Control',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
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
              isScrollable: true,
              tabs: const [
                Tab(text: 'Media'),
                Tab(text: 'Buat Playlist'),
                Tab(text: 'Kelola Playlist'),
                Tab(text: 'Flash Sale'),
                Tab(text: 'Kelola Penayangan'),
                Tab(text: 'Kelola Grid'),
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
                  child: compactTop
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _baseUrlController,
                              decoration: const InputDecoration(
                                labelText: 'Base URL',
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _apiKeyController,
                              decoration: const InputDecoration(
                                labelText: 'API Key (opsional)',
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ElevatedButton(
                                  onPressed: _refreshing ? null : _refresh,
                                  child: const Text('Refresh'),
                                ),
                                ElevatedButton(
                                  onPressed: _exportConfig,
                                  child: const Text('Export'),
                                ),
                              ],
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _baseUrlController,
                                decoration: const InputDecoration(
                                  labelText: 'Base URL',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 180,
                              child: TextField(
                                controller: _apiKeyController,
                                decoration: const InputDecoration(
                                  labelText: 'API Key (opsional)',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _refreshing ? null : _refresh,
                              child: const Text('Refresh'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _exportConfig,
                              child: const Text('Export'),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: _autoRefresh,
                            onChanged: _setAutoRefresh,
                          ),
                          const Text('Auto refresh (30s)'),
                        ],
                      ),
                      if (_lastRefreshAt != null)
                        Text('Last: ${_lastRefreshAt!.toLocal()}'),
                      if (_refreshing)
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text('Refreshing...'),
                          ],
                        ),
                      if (!_refreshing && _lastError != null)
                        SizedBox(
                          width: compactTop
                              ? MediaQuery.sizeOf(context).width - 90
                              : 420,
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
                        _playlistManageTab(),
                        _flashSaleTab(),
                        _scheduleTab(),
                        _gridManagementTab(),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 920;
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropZone(
                onFiles: (files) =>
                    _setSelectedFilesWithFilter(files, source: 'drag drop'),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: _pickFile,
                    child: const Text('Pick File'),
                  ),
                  DropdownButton<String>(
                    value: _mediaType,
                    items: const [
                      DropdownMenuItem(value: 'auto', child: Text('Auto')),
                      DropdownMenuItem(value: 'image', child: Text('Image')),
                      DropdownMenuItem(value: 'video', child: Text('Video')),
                    ],
                    onChanged: (v) => setState(() => _mediaType = v ?? 'auto'),
                  ),
                  SizedBox(
                    width: compact ? 160 : 120,
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Durasi (detik)',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => _durationSec = int.tryParse(v) ?? 10,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _upload,
                    child: const Text('Upload'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              compact
                  ? Column(
                      children: [
                        TextField(
                          decoration: const InputDecoration(
                            labelText: 'Cari media di server (nama/path)',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onSubmitted: (value) {
                            _mediaServerQuery = value;
                            _refresh();
                          },
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            DropdownButton<String>(
                              value: _mediaServerType,
                              items: const [
                                DropdownMenuItem(
                                  value: 'all',
                                  child: Text('All'),
                                ),
                                DropdownMenuItem(
                                  value: 'image',
                                  child: Text('Image'),
                                ),
                                DropdownMenuItem(
                                  value: 'video',
                                  child: Text('Video'),
                                ),
                              ],
                              onChanged: (value) {
                                setState(
                                  () => _mediaServerType = value ?? 'all',
                                );
                                _refresh();
                              },
                            ),
                            OutlinedButton.icon(
                              onPressed: _refreshing ? null : _refresh,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Apply Filter'),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Row(
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
                            DropdownMenuItem(
                              value: 'image',
                              child: Text('Image'),
                            ),
                            DropdownMenuItem(
                              value: 'video',
                              child: Text('Video'),
                            ),
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
                Text(
                  'Selected files: ${_selectedFiles.map((f) => f.uri.pathSegments.last).join(', ')}',
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  Text('Media loaded: ${_media.length} / $_mediaTotal'),
                  if (_mediaOffset < _mediaTotal)
                    OutlinedButton(
                      onPressed: _mediaPageLoading ? null : _loadMoreMedia,
                      child: Text(
                        _mediaPageLoading ? 'Loading...' : 'Load More',
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: _media.length,
                  itemBuilder: (context, i) {
                    final m = _media[i];
                    final inferredType = _isVideoPath(m.path)
                        ? 'video'
                        : _isImagePath(m.path)
                        ? 'image'
                        : m.type;
                    return ListTile(
                      title: Text(m.name),
                      subtitle: Text('$inferredType | ${m.path}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () => _previewMedia(m),
                            child: const Text('Preview'),
                          ),
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
      },
    );
  }

  Widget _playlistTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 980;
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF7DD3FC)),
                ),
                child: const Text(
                  'Menu ini khusus untuk MENYUSUN playlist (pilih media, urutkan, atur durasi, lalu simpan jadi playlist baru).',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: _createPlaylistForSelectedScreen,
                    child: const Text('Simpan Sebagai Playlist Baru'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Playlist tersedia pada screen aktif: ${_playlists.length}',
                style: const TextStyle(color: Color(0xFF475569)),
              ),
              const SizedBox(height: 12),
              const Text(
                'Pilih media untuk playlist, atur durasi, dan urutan:',
              ),
              const SizedBox(height: 8),
              compact
                  ? Column(
                      children: [
                        TextField(
                          decoration: const InputDecoration(
                            labelText: 'Cari media (nama/path)',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (value) =>
                              setState(() => _playlistMediaQuery = value),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'all', label: Text('Semua')),
                              ButtonSegment(
                                value: 'image',
                                label: Text('Gambar'),
                              ),
                              ButtonSegment(
                                value: 'video',
                                label: Text('Video'),
                              ),
                            ],
                            selected: {_playlistMediaFilter},
                            onSelectionChanged: (value) {
                              final selected = value.isNotEmpty
                                  ? value.first
                                  : 'all';
                              setState(() => _playlistMediaFilter = selected);
                            },
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Cari media (nama/path)',
                              prefixIcon: Icon(Icons.search),
                            ),
                            onChanged: (value) =>
                                setState(() => _playlistMediaQuery = value),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'all', label: Text('Semua')),
                            ButtonSegment(
                              value: 'image',
                              label: Text('Gambar'),
                            ),
                            ButtonSegment(value: 'video', label: Text('Video')),
                          ],
                          selected: {_playlistMediaFilter},
                          onSelectionChanged: (value) {
                            final selected = value.isNotEmpty
                                ? value.first
                                : 'all';
                            setState(() => _playlistMediaFilter = selected);
                          },
                        ),
                      ],
                    ),
              const SizedBox(height: 8),
              Expanded(
                child: compact
                    ? Column(
                        children: [
                          Expanded(child: _playlistMediaSelectionList()),
                          const SizedBox(height: 12),
                          Expanded(child: _playlistSelectedReorderList()),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: _playlistMediaSelectionList()),
                          const SizedBox(width: 12),
                          Expanded(child: _playlistSelectedReorderList()),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _playlistMediaSelectionList() {
    return Builder(
      builder: (context) {
        final filteredMedia = _filteredMediaForPlaylist();
        if (filteredMedia.isEmpty) {
          return const Center(
            child: Text('Media tidak ditemukan untuk filter ini'),
          );
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
                          _mediaDurations[m.id] =
                              _mediaDurations[m.id] ?? _durationSec;
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
    );
  }

  Widget _playlistSelectedReorderList() {
    return ReorderableListView(
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
    );
  }

  Widget _playlistManageTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF86EFAC)),
            ),
            child: const Text(
              'Menu ini khusus playlist dari Buat Playlist: tambah media, ubah urutan, hapus media, rename playlist, hapus playlist.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Kelola playlist dari screen aktif',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _playlists.any((p) => p.id == _managePlaylistId)
                      ? _managePlaylistId
                      : null,
                  hint: const Text('Pilih playlist'),
                  items: _playlists
                      .map(
                        (p) =>
                            DropdownMenuItem(value: p.id, child: Text(p.name)),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() => _managePlaylistId = value);
                    _loadManagePlaylistData();
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _managePlaylistId == null
                    ? null
                    : _loadManagePlaylistData,
                child: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _managePlaylistNameController,
            enabled: _managePlaylistId != null,
            decoration: const InputDecoration(labelText: 'Nama playlist'),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton(
                onPressed: (_managePlaylistId == null || !_managePlaylistDirty)
                    ? null
                    : _updateManagedPlaylist,
                child: const Text('Update Playlist'),
              ),
              ElevatedButton(
                onPressed: _managePlaylistId == null
                    ? null
                    : _renameManagedPlaylist,
                child: const Text('Update Nama Playlist'),
              ),
              ElevatedButton(
                onPressed: _manageSelectedItemIds.isEmpty
                    ? null
                    : _deleteManagedPlaylistItems,
                child: const Text('Hapus Media Terpilih'),
              ),
              ElevatedButton(
                onPressed: _managePlaylistId == null
                    ? null
                    : _deleteManagedPlaylist,
                child: const Text('Hapus Playlist'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _media.any((m) => m.id == _manageAddMediaId)
                      ? _manageAddMediaId
                      : null,
                  hint: const Text('Pilih media untuk ditambah'),
                  items: _media
                      .map(
                        (m) =>
                            DropdownMenuItem(value: m.id, child: Text(m.name)),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _manageAddMediaId = value),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _manageAddDurationController,
                  decoration: const InputDecoration(labelText: 'Durasi'),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _managePlaylistId == null
                    ? null
                    : _addMediaToManagedPlaylist,
                child: const Text('Tambah Media'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_managePlaylistLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_managePlaylistId == null)
            const Expanded(
              child: Center(child: Text('Pilih playlist untuk dikelola')),
            )
          else
            Expanded(
              child: ReorderableListView.builder(
                onReorder: _reorderManagedPlaylistItems,
                itemCount: _managePlaylistItems.length,
                buildDefaultDragHandles: false,
                itemBuilder: (context, i) {
                  final item = _managePlaylistItems[i];
                  final checked = _manageSelectedItemIds.contains(item.itemId);
                  return Container(
                    key: ValueKey(item.itemId),
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white,
                    ),
                    child: ListTile(
                      leading: Checkbox(
                        value: checked,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _manageSelectedItemIds.add(item.itemId);
                            } else {
                              _manageSelectedItemIds.remove(item.itemId);
                            }
                          });
                        },
                      ),
                      title: Text('${i + 1}. ${item.mediaName}'),
                      subtitle: Text(
                        '${item.mediaType} | durasi: ${item.durationSec ?? '-'}',
                      ),
                      trailing: ReorderableDragStartListener(
                        index: i,
                        child: const Icon(Icons.drag_handle),
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

  Widget _flashSaleTab() {
    final landscapeDevices = _flashSaleLandscapeDevices();
    final landscapeDeviceIds = landscapeDevices.map((d) => d.id).toSet();
    _flashSaleDeviceIds.removeWhere(
      (deviceId) => !landscapeDeviceIds.contains(deviceId),
    );

    return Padding(
      padding: const EdgeInsets.all(12),
      child: ListView(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDA4AF)),
            ),
            child: const Text(
              'Alur Flash Sale baru: isi note + countdown + produk+media, pilih device target, lalu tayangkan sekarang atau jadwalkan.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF93C5FD)),
            ),
            child: const Text(
              'Info: saat Flash Sale aktif di mobile, tampilan otomatis fullscreen (grid 1x1).',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF6EE7B7)),
            ),
            child: const Text(
              'Auto stop aktif: setelah countdown selesai, overlay Flash Sale mobile otomatis nonaktif.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _flashSaleNoteController,
            decoration: const InputDecoration(
              labelText: 'Note Flash Sale (running text)',
              hintText:
                  'Contoh: Promo berlaku selama stok tersedia. Maks 2 item/pelanggan.',
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          const Text(
            'Countdown Flash Sale (sinkron ke app mobile)',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _flashSaleCountdownController,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Countdown (detik)',
              hintText: 'Contoh: 600',
              helperText:
                  'Wajib diisi. Ini sumber countdown tunggal untuk sinkron ke app mobile.',
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._flashSaleCountdownPresetSeconds().map((seconds) {
                final selected =
                    int.tryParse(_flashSaleCountdownController.text.trim()) ==
                    seconds;
                return ChoiceChip(
                  label: Text(_flashSaleCountdownLabel(seconds)),
                  selected: selected,
                  onSelected: (_) {
                    setState(
                      () => _flashSaleCountdownController.text = seconds
                          .toString(),
                    );
                  },
                );
              }),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Produk Flash Sale',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _flashSaleProducts.add(
                      _FlashSaleProductDraft(
                        name: '',
                        brand: '',
                        normalPrice: '',
                        promoPrice: '',
                        stock: '',
                        mediaId: '',
                      ),
                    );
                    _resetFlashSaleMediaCheckStatus();
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('Tambah Produk'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ..._flashSaleProducts.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name.trim().isEmpty
                          ? 'Produk ${index + 1} (belum diisi)'
                          : '${item.name} | ${item.brand} | Normal ${item.normalPrice} -> Promo ${item.promoPrice} | Stok ${item.stock} | Media ${_flashSaleMediaLabelById(item.mediaId)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => _editFlashSaleProduct(index),
                    child: const Text('Edit'),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Hapus produk',
                    onPressed: () {
                      setState(() {
                        if (_flashSaleProducts.length > 1) {
                          _flashSaleProducts.removeAt(index);
                          _resetFlashSaleMediaCheckStatus();
                        }
                      });
                    },
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Color(0xFFB91C1C),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
          const Text(
            'Pilih Device Target (Landscape / TV Android)',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          if (landscapeDevices.isEmpty)
            const Text(
              'Belum ada device landscape. Ubah orientation device ke landscape di menu Devices.',
              style: TextStyle(
                color: Color(0xFFB91C1C),
                fontWeight: FontWeight.w600,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: landscapeDevices.map((device) {
                final selected = _flashSaleDeviceIds.contains(device.id);
                return FilterChip(
                  label: Text(device.name),
                  selected: selected,
                  onSelected: (value) {
                    setState(() {
                      if (value) {
                        _flashSaleDeviceIds.add(device.id);
                      } else {
                        _flashSaleDeviceIds.remove(device.id);
                      }
                      _resetFlashSaleMediaCheckStatus();
                    });
                  },
                );
              }).toList(),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _flashSaleMediaCheckBusy
                    ? null
                    : _checkFlashSaleMediaSyncStatus,
                icon: const Icon(Icons.cloud_sync_outlined),
                label: Text(
                  _flashSaleMediaCheckBusy
                      ? 'Cek Sinkron...'
                      : 'Cek Sinkron Media Device',
                ),
              ),
              if (_flashSaleMediaCheckedAt != null)
                Chip(
                  label: Text(
                    'Dicek ${_flashSaleMediaCheckedAt!.hour.toString().padLeft(2, '0')}:${_flashSaleMediaCheckedAt!.minute.toString().padLeft(2, '0')}',
                  ),
                ),
            ],
          ),
          if (_flashSaleMissingMediaByDevice.isNotEmpty ||
              _flashSaleMediaErrorByDevice.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _flashSaleTargetDeviceIds().map((deviceId) {
                  final error = _flashSaleMediaErrorByDevice[deviceId];
                  final missing =
                      _flashSaleMissingMediaByDevice[deviceId] ?? const [];
                  final matched = _devices.where((d) => d.id == deviceId);
                  final title =
                      (matched.isEmpty ? deviceId : matched.first.name).trim();

                  if (error != null) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '$title: gagal cek sinkron (${error.split('\n').first})',
                        style: const TextStyle(
                          color: Color(0xFFB91C1C),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }
                  if (missing.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '$title: siap, media produk sudah terdaftar di config device',
                        style: const TextStyle(
                          color: Color(0xFF166534),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '$title: media belum terdaftar (${missing.join(', ')})',
                      style: const TextStyle(
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _flashSaleBusy ? null : _runFlashSaleNow,
                icon: const Icon(Icons.flash_on),
                label: Text(
                  _flashSaleBusy ? 'Memproses...' : 'Tayangkan Sekarang',
                ),
              ),
              OutlinedButton.icon(
                onPressed: _flashSaleBusy ? null : _openScheduleFlashSaleDialog,
                icon: const Icon(Icons.schedule),
                label: const Text('Jadwalkan Flashsale'),
              ),
              OutlinedButton.icon(
                onPressed: _flashSaleBusy ? null : _disableFlashSaleForTargets,
                icon: const Icon(Icons.flash_off),
                label: const Text('Nonaktifkan Flash Sale'),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _scheduleTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: ListView(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDBA74)),
            ),
            child: const Text(
              'Menu ini khusus untuk PENAYANGAN (pilih device, pilih playlist per device / massal, lalu apply grid dan apply tayang).',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Alur tayang: 1) Pilih playlist 2) Apply playlist 3) Pilih grid 4) Apply Grid',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          const Text(
            'Pilih Device',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ..._devices.map((device) {
                final selected = _selectedDeviceIds.contains(device.id);
                return FilterChip(
                  label: Text(device.name),
                  selected: selected,
                  onSelected: (value) {
                    setState(() {
                      if (value) {
                        _selectedDeviceIds.add(device.id);
                      } else {
                        _selectedDeviceIds.remove(device.id);
                      }
                    });
                    _loadScreens();
                  },
                );
              }),
              OutlinedButton(
                onPressed: _openDevicePicker,
                child: const Text('Pilih via popup'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Sedang Diputar',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          if (_selectedDeviceIds.isEmpty)
            const Text('Belum ada device dipilih')
          else
            ..._selectedDeviceIds.map((deviceId) {
              DeviceInfo? device;
              for (final item in _devices) {
                if (item.id == deviceId) {
                  device = item;
                  break;
                }
              }
              final playingName =
                  _deviceNowPlayingName[deviceId] ?? 'Loading...';
              final gridActive = _deviceGridPreset[deviceId] ?? '-';
              final gridKnown = RegExp(r'^\d+x\d+$').hasMatch(gridActive);
              final orientation = (device?.orientation == 'landscape')
                  ? 'landscape'
                  : 'portrait';
              final orientationIcon = orientation == 'landscape'
                  ? Icons.stay_current_landscape
                  : Icons.stay_current_portrait;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.play_circle_outline, size: 18),
                title: Row(
                  children: [
                    Icon(
                      orientationIcon,
                      size: 16,
                      color: const Color(0xFF334155),
                    ),
                    const SizedBox(width: 6),
                    Expanded(child: Text(device?.name ?? deviceId)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: gridKnown
                            ? const Color(0xFFD1FAE5)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: gridKnown
                              ? const Color(0xFF34D399)
                              : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Text(
                        'GRID $gridActive',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: gridKnown
                              ? const Color(0xFF065F46)
                              : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Text('Now playing: $playingName'),
              );
            }),
          const SizedBox(height: 10),
          const Text(
            'Atur Playlist yang Diputar per Device',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE0F2FE), Color(0xFFF0F9FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: const Text(
              'Playlist bisa diterapkan ke banyak device. Jika playlist belum ada di device target, sistem akan membuat salinan otomatis.',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF0C4A6E),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (_selectedDeviceIds.isEmpty)
            const Text('Pilih device dulu untuk assign playlist berbeda')
          else
            ..._selectedDeviceIds.map((deviceId) {
              DeviceInfo? device;
              for (final item in _devices) {
                if (item.id == deviceId) {
                  device = item;
                  break;
                }
              }
              final devicePlaylists = _playlistsForDevice(deviceId);
              final selected = _devicePlaylistSelection[deviceId];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 190,
                      child: Text(
                        device?.name ?? deviceId,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value:
                            devicePlaylists.any((p) => p.playlistId == selected)
                            ? selected
                            : null,
                        hint: const Text('Pilih playlist device ini'),
                        items: devicePlaylists
                            .map(
                              (p) => DropdownMenuItem(
                                value: p.playlistId,
                                child: Text(
                                  p.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(
                            () => _devicePlaylistSelection[deviceId] = value,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final options = _bulkPlaylistNameOptions();
              final selected = options.contains(_bulkPlaylistName)
                  ? _bulkPlaylistName
                  : null;
              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFFCF6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.groups_2_outlined,
                      size: 18,
                      color: Color(0xFF166534),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: selected,
                        hint: const Text(
                          'Pilih 1 playlist untuk semua device terpilih',
                        ),
                        items: options
                            .map(
                              (name) => DropdownMenuItem(
                                value: name,
                                child: Text(name),
                              ),
                            )
                            .toList(),
                        onChanged: _selectedDeviceIds.isEmpty
                            ? null
                            : (value) =>
                                  setState(() => _bulkPlaylistName = value),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed:
                          (_selectedDeviceIds.isEmpty || selected == null)
                          ? null
                          : _applySamePlaylistToSelectedDevices,
                      child: const Text('Apply ke Semua Device Terpilih'),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selectedDeviceIds.isEmpty
                  ? null
                  : _applyPerDevicePlaylistAssignments,
              icon: const Icon(Icons.playlist_add_check_circle_outlined),
              label: const Text('Apply Playlist per Device'),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Pengaturan grid dipisah ke menu Kelola Grid agar tidak tercampur dengan apply playlist.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _tabController.animateTo(5),
                  child: const Text('Buka Kelola Grid'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _gridManagementTab() {
    DeviceInfo? targetDevice;
    for (final device in _devices) {
      if (device.id == _gridTargetDeviceId) {
        targetDevice = device;
        break;
      }
    }
    final orientation = (targetDevice?.orientation == 'landscape')
        ? 'landscape'
        : 'portrait';
    final orientationIcon = orientation == 'landscape'
        ? Icons.stay_current_landscape
        : Icons.stay_current_portrait;
    final allowedPresets = _gridPresetOptionsForOrientation(orientation);
    if (!allowedPresets.contains(_gridTargetPreset)) {
      _gridTargetPreset = allowedPresets.first;
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: ListView(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: const Text(
              'Kelola Grid terpisah dari playlist. Pilih 1 device, pilih preset sesuai orientasi device, lalu Apply Grid.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _devices.any((d) => d.id == _gridTargetDeviceId)
                      ? _gridTargetDeviceId
                      : null,
                  hint: const Text('Pilih device'),
                  items: _devices
                      .map(
                        (d) => DropdownMenuItem(
                          value: d.id,
                          child: Text(
                            '${d.name} (${d.orientation ?? 'portrait'})',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) async {
                    if (value == null) return;
                    await _loadGridPreviewForDevice(value);
                  },
                ),
              ),
              const SizedBox(width: 8),
              if (targetDevice != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(orientationIcon, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        orientation.toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            orientation == 'landscape'
                ? 'Preset landscape (kolom >= baris)'
                : 'Preset portrait (baris >= kolom)',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: allowedPresets.map((preset) {
              final selected = _gridTargetPreset == preset;
              return ChoiceChip(
                label: Text(_gridPresetLabel(preset)),
                selected: selected,
                onSelected: (_) => setState(() => _gridTargetPreset = preset),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('Durasi transisi'),
              const SizedBox(width: 10),
              IconButton(
                tooltip: 'Kurangi',
                onPressed: () {
                  setState(() {
                    _gridTargetTransitionDuration = _sanitizeTransitionDuration(
                      _gridTargetTransitionDuration - 1,
                    );
                  });
                },
                icon: const Icon(Icons.remove_circle_outline),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  '${_gridTargetTransitionDuration}s',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Tambah',
                onPressed: () {
                  setState(() {
                    _gridTargetTransitionDuration = _sanitizeTransitionDuration(
                      _gridTargetTransitionDuration + 1,
                    );
                  });
                },
                icon: const Icon(Icons.add_circle_outline),
              ),
              Expanded(
                child: Slider(
                  value: _gridTargetTransitionDuration.toDouble(),
                  min: 0,
                  max: 30,
                  divisions: 30,
                  label: '${_gridTargetTransitionDuration}s',
                  onChanged: (value) {
                    setState(() {
                      _gridTargetTransitionDuration = value.round();
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ElevatedButton(
            onPressed: (_gridTargetDeviceId == null || _gridTargetLoading)
                ? null
                : () => _setGridPresetForDevice(
                    _gridTargetDeviceId!,
                    _gridTargetPreset,
                    _gridTargetTransitionDuration,
                  ),
            child: Text(
              _gridTargetLoading ? 'Loading...' : 'Apply Grid ke Device Ini',
            ),
          ),
          const SizedBox(height: 12),
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
                Text(
                  'Preview ${_gridRows(_gridTargetPreset)}x${_gridCols(_gridTargetPreset)}',
                ),
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    final rows = _gridRows(_gridTargetPreset).clamp(1, 4);
                    final cols = _gridCols(_gridTargetPreset).clamp(1, 4);
                    final cellCount = rows * cols;
                    final targetAspect = orientation == 'landscape'
                        ? (16 / 9)
                        : (9 / 16);
                    final maxWidth = MediaQuery.sizeOf(context).width - 120;
                    final previewWidth = math.min(maxWidth, 560.0);
                    final previewHeight = previewWidth / targetAspect;
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: previewWidth,
                        height: previewHeight,
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: cellCount,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: cols,
                                mainAxisSpacing: 6,
                                crossAxisSpacing: 6,
                              ),
                          itemBuilder: (context, i) {
                            final cellNo = i + 1;
                            final cellItems = _gridItemsForCellFromSource(
                              _gridTargetPreviewItems,
                              i,
                              cellCount,
                            );
                            final hasData = cellItems.isNotEmpty;
                            return Container(
                              decoration: BoxDecoration(
                                color: hasData ? Colors.black : Colors.white,
                                border: Border.all(
                                  color: const Color(0xFFBAE6FD),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: _gridTargetLoading
                                  ? const Center(
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : (!hasData
                                        ? Center(
                                            child: Text(
                                              'Cell $cellNo',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF075985),
                                              ),
                                            ),
                                          )
                                        : Padding(
                                            padding: const EdgeInsets.all(4),
                                            child: cellCount == 1
                                                ? _buildFullscreenGridPreview(
                                                    cellItems,
                                                  )
                                                : _buildGridCellMosaic(
                                                    cellItems,
                                                  ),
                                          )),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
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
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Total: ${_devices.length} | Selected: ${_selectedDeviceIds.length}',
              ),
              ElevatedButton(
                onPressed: _selectedDeviceIds.isEmpty
                    ? null
                    : _deleteSelectedDevices,
                child: const Text('Hapus Device Terpilih'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_devices.isEmpty) const Text('Belum ada device terdaftar.'),
          Expanded(
            child: ListView.builder(
              itemCount: _devices.length,
              itemBuilder: (context, i) {
                final d = _devices[i];
                final selected = _selectedDeviceIds.contains(d.id);
                final lastSeen = d.lastSeen;
                final isOnline = d.status.toLowerCase() == 'online';
                final status = isOnline ? 'online' : 'offline';
                final statusColor = isOnline
                    ? const Color(0xFF15803D)
                    : const Color(0xFFB91C1C);
                final orientation = (d.orientation == 'landscape')
                    ? 'landscape'
                    : 'portrait';
                final orientationIcon = orientation == 'landscape'
                    ? Icons.stay_current_landscape
                    : Icons.stay_current_portrait;
                return CheckboxListTile(
                  value: selected,
                  title: Row(
                    children: [
                      Icon(orientationIcon, size: 18),
                      const SizedBox(width: 6),
                      Expanded(child: Text(d.name)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
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
                  subtitle: Text(
                    '${d.id} | $orientation | last: ${lastSeen ?? '-'}',
                  ),
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
  final bool isFlashSale;
  final String flashNote;
  final int? flashCountdownSec;
  final String flashItemsJson;

  _PlaylistTemplate({
    required this.playlistId,
    required this.name,
    required this.deviceId,
    required this.deviceName,
    required this.isFlashSale,
    required this.flashNote,
    required this.flashCountdownSec,
    required this.flashItemsJson,
  });
}

class _FlashSaleProductDraft {
  final String name;
  final String brand;
  final String normalPrice;
  final String promoPrice;
  final String stock;
  final String mediaId;

  const _FlashSaleProductDraft({
    required this.name,
    required this.brand,
    required this.normalPrice,
    required this.promoPrice,
    required this.stock,
    required this.mediaId,
  });

  Map<String, String> toJson() {
    return {
      'name': name,
      'brand': brand,
      'normal_price': normalPrice,
      'promo_price': promoPrice,
      'stock': stock,
      'media_id': mediaId,
    };
  }
}

class _AppliedPlaylistTarget {
  final String screenId;
  final String playlistId;

  _AppliedPlaylistTarget({required this.screenId, required this.playlistId});
}

class _GridPreviewItem {
  final String mediaId;
  final String type;
  final String path;
  final String label;

  _GridPreviewItem({
    required this.mediaId,
    required this.type,
    required this.path,
    required this.label,
  });
}

class _ManagePlaylistItem {
  final String itemId;
  final String mediaId;
  final int order;
  final int? durationSec;
  final String mediaName;
  final String mediaType;

  _ManagePlaylistItem({
    required this.itemId,
    required this.mediaId,
    required this.order,
    required this.durationSec,
    required this.mediaName,
    required this.mediaType,
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
