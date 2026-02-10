class DeviceInfo {
  final String id;
  final String name;
  final String? location;
  final String status;
  final DateTime? lastSeen;
  final String? orientation;

  DeviceInfo({required this.id, required this.name, this.location, required this.status, this.lastSeen, this.orientation});

  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      id: json['id'],
      name: json['name'] ?? '',
      location: json['location'],
      status: json['status'] ?? 'unknown',
      lastSeen: json['last_seen'] != null ? DateTime.tryParse(json['last_seen']) : null,
      orientation: json['orientation'],
    );
  }
}

class MediaInfo {
  final String id;
  final String name;
  final String type;
  final String path;
  final int? durationSec;

  MediaInfo({required this.id, required this.name, required this.type, required this.path, this.durationSec});

  factory MediaInfo.fromJson(Map<String, dynamic> json) {
    return MediaInfo(
      id: json['id'],
      name: json['name'] ?? '',
      type: json['type'] ?? 'image',
      path: json['path'] ?? '',
      durationSec: json['duration_sec'],
    );
  }
}

class MediaPageInfo {
  final List<MediaInfo> items;
  final int total;
  final int offset;
  final int limit;

  MediaPageInfo({
    required this.items,
    required this.total,
    required this.offset,
    required this.limit,
  });
}

class ScreenInfo {
  final String id;
  final String name;
  final String? activePlaylistId;
  final String? gridPreset;

  ScreenInfo({required this.id, required this.name, this.activePlaylistId, this.gridPreset});
}

class PlaylistInfo {
  final String id;
  final String name;

  PlaylistInfo({required this.id, required this.name});
}

class PlaylistItemInfo {
  final String id;
  final String playlistId;
  final String mediaId;
  final int order;
  final int? durationSec;
  final bool enabled;

  PlaylistItemInfo({
    required this.id,
    required this.playlistId,
    required this.mediaId,
    required this.order,
    this.durationSec,
    required this.enabled,
  });

  factory PlaylistItemInfo.fromJson(Map<String, dynamic> json) {
    return PlaylistItemInfo(
      id: '${json['id']}',
      playlistId: '${json['playlist_id']}',
      mediaId: '${json['media_id']}',
      order: (json['order'] as num?)?.toInt() ?? 0,
      durationSec: (json['duration_sec'] as num?)?.toInt(),
      enabled: json['enabled'] == null ? true : json['enabled'] == true,
    );
  }
}

class ScheduleInfo {
  final String id;
  final String screenId;
  final String playlistId;
  final int dayOfWeek;
  final String startTime;
  final String endTime;

  ScheduleInfo({
    required this.id,
    required this.screenId,
    required this.playlistId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  });

  factory ScheduleInfo.fromJson(Map<String, dynamic> json) {
    return ScheduleInfo(
      id: '${json['id']}',
      screenId: '${json['screen_id']}',
      playlistId: '${json['playlist_id']}',
      dayOfWeek: json['day_of_week'] ?? 0,
      startTime: (json['start_time'] ?? '').toString(),
      endTime: (json['end_time'] ?? '').toString(),
    );
  }
}
