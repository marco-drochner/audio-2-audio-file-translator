import 'package:flutter_test/flutter_test.dart';
import 'package:audio_2_audio_file_translator/transcriber.dart';
import 'package:audio_2_audio_file_translator/backend.dart';
import 'package:yaml/yaml.dart';
import 'dart:io';

void main() {
  group('Transcription and Translation Tests', () {
    test('Short Speech Transcription', () async {
      final List<String> transcription = await Transcriber.transcribe("./test/test_samples/short_speech.mp3", maxCharsPerSegSoftLimit: 50);
      final List<String> expectedTranscription = await loadTranscriptionList("./test/test_samples/short_transcription_list.yaml");
      expect(transcription, expectedTranscription);
    });

    test('Short Speech Translation', () async {
      final List<String> transcription = await loadTranscriptionList("./test/test_samples/short_transcription_list.yaml");
      final String joinedTranscription = transcription.join(" ");
      final String translation = await Backend.translate(joinedTranscription);
      final String expectedTranslation = await loadTranslation("./test/test_samples/short_translation.txt");
      expect(translation, expectedTranslation);
    });
  });
}

Future<List<String>> loadTranscriptionList(String filePath) async {
  final file = File(filePath);
  if (await file.exists()) {
    final yamlString = await file.readAsString();
    final yamlList = loadYaml(yamlString) as YamlList;
    return List<String>.from(yamlList);
  } else {
    throw Exception("File not found");
  }
}

Future<String> loadTranslation(String filePath) async {
  final file = File(filePath);
  if (await file.exists()) {
    return await file.readAsString();
  } else {
    throw Exception("File not found");
  }
}