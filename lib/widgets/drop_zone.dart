import 'dart:io';
import 'package:flutter/material.dart';

class DropZone extends StatelessWidget {
  final void Function(List<File> files) onFiles;

  const DropZone({super.key, required this.onFiles});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blueGrey, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Text(
          'Upload via tombol Pick File',
          style: TextStyle(fontSize: 14),
        ),
      ),
    );
  }
}
