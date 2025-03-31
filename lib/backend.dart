import 'transcriber.dart';
import 'merge_helper.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aws_polly_api/polly-2016-06-10.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Backend {
  static late final SharedPreferences prefs;
  static late final String deepLAuthKey;
  static late final String bytescaleKey;
  static late final String bytescaleAccID;
  static late final String awsAccessKey;
  static late final String awsSecretKey;
  static final Engine _voiceEngine = Engine.standard;
  static final VoiceId _voiceID = VoiceId.miguel;
  static late final String applicationDocumentsDirectoryPath;
  static Function(bool)? onProcessingStateChange;
  static late final Polly polly;
  static bool _isInitialized = false;

  static Future<void> initializeFields() async {
    if (_isInitialized) return;
      await dotenv.load();
      deepLAuthKey = dotenv.env["DEEPL_AUTH_KEY"] ?? (throw Exception("DEEPL_AUTH_KEY not found in environment variables"));
      bytescaleKey = dotenv.env["BYTESCALE_KEY"] ?? (throw Exception("BYTESCALE_KEY not found in environment variables"));
      bytescaleAccID = dotenv.env["BYTESCALE_ACCOUNT_ID"] ?? (throw Exception("BYTESCALE_ACCOUNT_ID not found in environment variables"));
      awsAccessKey = dotenv.env["AWS_ACCESS_KEY"] ?? (throw Exception("AWS_ACCESS_KEY not found in environment variables"));
      awsSecretKey = dotenv.env["AWS_SECRET_KEY"] ?? (throw Exception("AWS_SECRET_KEY not found in environment variables"));
      // applicationDocumentsDirectoryPath = (await getApplicationDocumentsDirectory()).path;!!!???
      final credentials = AwsClientCredentials(
        accessKey: awsAccessKey,
        secretKey: awsSecretKey,
      );
      const region = 'us-east-2';
      polly = Polly(
        credentials: credentials,
        region: region,
      );
    _isInitialized = true;
  }

  static Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initializeFields();
    }
  }

  // Function to translate text
  static Future<String> translate(String engText) async {
    await _ensureInitialized();
    final url = Uri.parse('https://api-free.deepl.com/v2/translate');
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'DeepL-Auth-Key $deepLAuthKey',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'text': engText,
        'source_lang': 'EN',
        'target_lang': 'ES',
      },
    );
    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      final inLatin1 = responseData['translations'][0]['text'];
      return utf8.decode(latin1.encode(inLatin1));
    } else {
      if (kDebugMode) {
        print("DeepL translation status code:");
        print(response.statusCode);
        print(response.reasonPhrase);
      }
      throw Exception('Failed to translate text');
    }
  }

  static Future<Uint8List> toSpeech(String text) async {
    await _ensureInitialized();
    try {
      // Call the synthesize speech API
       SynthesizeSpeechOutput result = await polly.synthesizeSpeech(
        languageCode: LanguageCode.esUs,
        outputFormat: OutputFormat.mp3,
        sampleRate: '8000',
        text: text,// text
        textType: TextType.text,
        voiceId: _voiceID,
        engine: _voiceEngine,
      );
      return result.audioStream!;
    } catch (e) {
      if (kDebugMode) {
        print('Error synthesizing speech: $e');
      }
      throw ErrorDescription('Error synthesizing speech: $e');
    }
  }

  static Future<String> chooseFileAndGetPath() async {
    await _ensureInitialized();
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['mp3']);
    if (result == null) {
      throw Error();
    } else if (result.files.first.path == null) {
        throw Error();
    } else {
      return result.files.first.path!;
    }
  }

  static Future<void> doIt(String sourceAudioPath, File outputFile) async {
    await _ensureInitialized();
    onProcessingStateChange?.call(true);
    // English to Spanish!!!???
    List<String> transcriptionSegments = await Transcriber.transcribe(sourceAudioPath, maxCharsPerSegSoftLimit: 10);
    List<Uint8List> speechStreams = [];
    for (int i = 0; i < transcriptionSegments.length; i++) {
      // THIS SHOULD BE DONE IN PARALLEL
      String segment = transcriptionSegments[i];
      String translation = await translate(segment);
      Uint8List speechStream = await toSpeech(translation);
      speechStreams.add(speechStream);
    }
    // When all the speech streams are ready, merge them
    Uint8List mergedBytes = await MergeHelper.mergeMp3s(speechStreams);
    outputFile.writeAsBytesSync(mergedBytes);
    if (kDebugMode) {
      print("Done. Output file path: ${outputFile.path}");
    }
    onProcessingStateChange?.call(false);
  }
}