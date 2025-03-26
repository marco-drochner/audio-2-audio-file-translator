import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class MergeHelper {
  String status = "No files selected";

  /// Merges multiple MP3 audios in list [audioStreams] in order into one.
  /// 
  /// All mp3 files in [auidoStreams] must have the same sample rate and bitrate.
  /// 
  /// Returns a Uint8List of the merged MP3 audios.
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

    int bitrateIndex = (bytes[index + 2] >> 4) & 0x0F;
    int sampleRateIndex = (bytes[index + 2] >> 2) & 0x03;

    const List<int> bitrates = [
      0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0
    ];
    const List<int> sampleRates = [44100, 48000, 32000, 0];

    if (bitrateIndex == 0x0F || sampleRateIndex == 0x03) return -1;

    int bitrate = bitrates[bitrateIndex] * 1000;
    int sampleRate = sampleRates[sampleRateIndex];
    int padding = (bytes[index + 2] >> 1) & 0x01;

    return ((144 * bitrate) ~/ sampleRate) + padding;
  }
}