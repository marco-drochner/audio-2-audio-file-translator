import 'backend.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Mp3MergerScreen(),
    );
  }
}

class Mp3MergerScreen extends StatefulWidget {
  @override
  _Mp3MergerScreenState createState() => _Mp3MergerScreenState();
}

class _Mp3MergerScreenState extends State<Mp3MergerScreen> {
  String status = "No files selected";
  bool _isButtonEnabled = false;
  String _outputFileName = "";
  Future<void> doTranscriplationToSpeech(String outputFileName) async {
    // Request storage permission to create output file
    if (await Permission.storage.request().isDenied) {
      setState(() => status = "Permission Denied!");
      return;
    }
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory == null) {
      setState(() => status = "No directory selected");
      return;
    }
    File outputFile = File("$selectedDirectory/$outputFileName.mp3");

    // The audio to transcribe, translate, t2s
    String inputPath = await pickMP3File();

    Backend.doIt(inputPath, outputFile);
  }

  Future<String> pickMP3File() async {
    FilePickerResult? audioFile = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3'],
      allowMultiple: false,
    );

    if (audioFile == null) {
      setState(() => status = "No files selected");
      throw Exception("No files selected");
    } else if (audioFile.paths[0] == null) {
      setState(() => status = "File selection error");
      throw Exception("File selection error");
    }
    return audioFile.paths[0]!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("MP3 Merger")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
            children: [
            Text(status, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            TextField(
              onChanged: (value) {
              setState(() {
                _isButtonEnabled = value.trim().isNotEmpty;
                _outputFileName = value.trim();
              });
              },
              decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: "Enter output file name",
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isButtonEnabled
                ? () {
                  doTranscriplationToSpeech(_outputFileName);
                }
                : null,
              child: const Text("Translate audio"),
            ),
          ],
        ),
      ),
    );
  }
}
