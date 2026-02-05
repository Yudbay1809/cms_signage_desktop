import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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
    return MaterialApp(
      title: 'Content Control',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey)),
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
  final TextEditingController _baseUrlController = TextEditingController(text: 'http://127.0.0.1:8000');
  final TextEditingController _startTimeController = TextEditingController(text: '08:00:00');
  final TextEditingController _endTimeController = TextEditingController(text: '23:00:00');

  List<DeviceInfo> _devices = [];
  List<MediaInfo> _media = [];
  List<ScreenInfo> _screens = [];

  String? _selectedDeviceId;
  String? _selectedScreenId;
  List<File> _selectedFiles = [];
  String _mediaType = 'auto';
  int _durationSec = 10;
  int _scheduleDay = DateTime.now().weekday % 7;
  final List<String> _selectedMediaIds = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _refresh();
  }

  ApiService get _api => ApiService(_baseUrlController.text.trim());

  Future<void> _refresh() async {
    try {
      final devices = await _api.listDevices();
      final media = await _api.listMedia();
      setState(() {
        _devices = devices;
        _media = media;
        _selectedDeviceId ??= devices.isNotEmpty ? devices.first.id : null;
      });
      await _loadScreens();
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<void> _loadScreens() async {
    if (_selectedDeviceId == null) return;
    try {
      final screens = await _api.listScreensForDevice(_selectedDeviceId!);
      setState(() {
        _screens = screens;
        _selectedScreenId ??= screens.isNotEmpty ? screens.first.id : null;
      });
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null || result.files.isEmpty) return;
    final files = result.files.where((f) => f.path != null).map((f) => File(f.path!)).toList();
    if (files.isEmpty) return;
    setState(() => _selectedFiles = files);
  }

  String _inferType(File file) {
    final name = file.uri.pathSegments.last.toLowerCase();
    if (name.endsWith('.mp4') || name.endsWith('.mov') || name.endsWith('.mkv') || name.endsWith('.avi')) {
      return 'video';
    }
    return 'image';
  }

  Future<void> _upload() async {
    if (_selectedFiles.isEmpty) {
      _showMessage('Pilih file dulu');
      return;
    }
    try {
      for (final file in _selectedFiles) {
        final type = _mediaType == 'auto' ? _inferType(file) : _mediaType;
        await _api.uploadMedia(
          file: file,
          name: file.uri.pathSegments.last,
          type: type,
          durationSec: _durationSec,
        );
      }
      _showMessage('Upload berhasil');
      setState(() => _selectedFiles = []);
      await _refresh();
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<void> _createPlaylistAndSchedule() async {
    if (_selectedScreenId == null) {
      _showMessage('Pilih screen dulu');
      return;
    }
    if (_selectedMediaIds.isEmpty) {
      _showMessage('Pilih media untuk playlist');
      return;
    }
    try {
      final playlist = await _api.createPlaylist(_selectedScreenId!, 'Playlist-${DateTime.now().millisecondsSinceEpoch}');
      var order = 1;
      for (final mediaId in _selectedMediaIds) {
        await _api.addPlaylistItem(playlistId: playlist.id, mediaId: mediaId, order: order, durationSec: _durationSec);
        order += 1;
      }
      await _api.createSchedule(
        screenId: _selectedScreenId!,
        playlistId: playlist.id,
        dayOfWeek: _scheduleDay,
        startTime: _startTimeController.text.trim(),
        endTime: _endTimeController.text.trim(),
      );
      _showMessage('Playlist & schedule dibuat');
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  String _absoluteUrl(String path) {
    if (path.startsWith('http')) return path;
    return '${_baseUrlController.text.trim()}$path';
  }

  void _previewMedia(MediaInfo media) {
    showDialog(
      context: context,
      builder: (ctx) {
        final url = _absoluteUrl(media.path);
        return AlertDialog(
          title: Text(media.name),
          content: SizedBox(
            width: 420,
            height: 300,
            child: media.type == 'image'
                ? Image.network(url, fit: BoxFit.contain)
                : const Center(child: Text('Preview video di player')),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Content Control'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Media'),
            Tab(text: 'Playlists'),
            Tab(text: 'Schedule'),
            Tab(text: 'Devices'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
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
                DropdownButton<String>(
                  value: _selectedDeviceId,
                  hint: const Text('Device'),
                  items: _devices.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))).toList(),
                  onChanged: (v) async {
                    setState(() => _selectedDeviceId = v);
                    await _loadScreens();
                  },
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _refresh, child: const Text('Refresh')),
              ],
            ),
          ),
          Expanded(
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
        ],
      ),
    );
  }

  Widget _mediaTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropZone(onFiles: (files) => setState(() => _selectedFiles = files)),
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
          const SizedBox(height: 12),
          if (_selectedFiles.isNotEmpty)
            Text('Selected files: ${_selectedFiles.map((f) => f.uri.pathSegments.last).join(', ')}'),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: _media.length,
              itemBuilder: (context, i) {
                final m = _media[i];
                return ListTile(
                  title: Text(m.name),
                  subtitle: Text('${m.type} • ${m.path}'),
                  trailing: TextButton(onPressed: () => _previewMedia(m), child: const Text('Preview')),
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
              DropdownButton<String>(
                value: _selectedScreenId,
                hint: const Text('Screen'),
                items: _screens.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                onChanged: (v) => setState(() => _selectedScreenId = v),
              ),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _createPlaylistAndSchedule, child: const Text('Create Playlist')),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Pilih media untuk playlist, lalu atur urutan:'),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: _media.length,
                    itemBuilder: (context, i) {
                      final m = _media[i];
                      final selected = _selectedMediaIds.contains(m.id);
                      return CheckboxListTile(
                        value: selected,
                        title: Text(m.name),
                        subtitle: Text(m.type),
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedMediaIds.add(m.id);
                            } else {
                              _selectedMediaIds.remove(m.id);
                            }
                          });
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
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Atur jadwal default untuk playlist baru:'),
          const SizedBox(height: 8),
          Row(
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
              const SizedBox(width: 8),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _startTimeController,
                  decoration: const InputDecoration(labelText: 'Start (HH:MM:SS)'),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _endTimeController,
                  decoration: const InputDecoration(labelText: 'End (HH:MM:SS)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Jadwal ini dipakai saat klik "Create Playlist".'),
        ],
      ),
    );
  }

  Widget _devicesTab() {
    return ListView.builder(
      itemCount: _devices.length,
      itemBuilder: (context, i) {
        final d = _devices[i];
        return ListTile(
          title: Text(d.name),
          subtitle: Text('${d.id} • ${d.status}'),
        );
      },
    );
  }
}
