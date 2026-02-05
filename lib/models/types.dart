class DeviceInfo {
  final String id;
  final String name;
  final String? location;
  final String status;

  DeviceInfo({required this.id, required this.name, this.location, required this.status});

  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      id: json['id'],
      name: json['name'] ?? '',
      location: json['location'],
      status: json['status'] ?? 'unknown',
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

class ScreenInfo {
  final String id;
  final String name;

  ScreenInfo({required this.id, required this.name});
}

class PlaylistInfo {
  final String id;
  final String name;

  PlaylistInfo({required this.id, required this.name});
}
