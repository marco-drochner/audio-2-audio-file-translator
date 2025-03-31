import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class MergeHelper {
  String status = "No files selected";

  /// Merges MP3 audios in list [audioStreams] for use 
  /// for use aws polly outputs with 8000 Hz and 32 kbps.
  /// 
  /// Returns a Uint8List of the merged MP3.
  static Future<Uint8List> mergeMp3s(List<Uint8List> audioStreams) async {
    List<int> mergedData = [];

    for (Uint8List audioStream in audioStreams) {
      List<int> mp3Frames = extractMp3Frames(audioStream);
      mergedData.addAll(mp3Frames);
    }

    return Uint8List.fromList(mergedData);
  }

  static List<int> extractMp3Frames(List<int> bytes) {
    List<int> mp3Frames = [];
    int i = 0;

    while (i < bytes.length - 1) {
      if (bytes[i] == 0xFF && (bytes[i + 1] & 0xE0) == 0xE0) {
        // Found an MP3 frame header
        int frameSize = estimateFrameSize(bytes, i);
        if (frameSize > 0 && i + frameSize <= bytes.length) {
          mp3Frames.addAll(bytes.sublist(i, i + frameSize));
          i += frameSize;
        } else {
          break;
        }
      } else {
        i++;
      }
    }

    return mp3Frames;
  }

  static int estimateFrameSize(List<int> bytes, int index) {
    if (index + 4 > bytes.length) return -1;

    const int bitrate = 32000; // Fixed bitrate of 32 kbps
    const int sampleRate = 8000; // Fixed sample rate of 8000 Hz

    int padding = (bytes[index + 2] >> 1) & 0x01;

    return ((144 * bitrate) ~/ sampleRate) + padding;
  }
}