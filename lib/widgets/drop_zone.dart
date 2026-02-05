import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

class DropZone extends StatelessWidget {
  final void Function(List<File> files) onFiles;

  const DropZone({super.key, required this.onFiles});

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragDone: (detail) {
        if (detail.files.isEmpty) return;
        final files = detail.files.map((f) => File(f.path)).toList();
        onFiles(files);
      },
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blueGrey, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text('Drag & drop media files here', style: TextStyle(fontSize: 14)),
        ),
      ),
    );
  }
}
