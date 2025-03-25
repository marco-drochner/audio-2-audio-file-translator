import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class Transcriber {
  static late final String elevateAIKey;
  static bool _isInitialized = false;

  static Future<void> initializeFields() async {
    if (_isInitialized) return;
    await dotenv.load();
    elevateAIKey = dotenv.env["ELEVATE_AI_KEY"] ?? (throw Exception("ELEVATE_AI_KEY not found in environment variables"));
    _isInitialized = true;
  }

  static Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initializeFields();
    }
  }

  static Future<String> createElevateInteraction() async {
    await _ensureInitialized();
    final body = jsonEncode({
      'type': 'audio',
      'languageTag': 'en-us',
      'vertical': 'default',
      'audioTranscriptionMode': 'highAccuracy',
      'includeAiResults': true,
    });

    final headers = {
      'Content-Type': 'application/json',
      'X-API-Token': elevateAIKey,
    };

    final response = await http.post(
      Uri.parse('https://api.elevateai.com/v1/interactions'),
      headers: headers,
      body: body,
    );
    final responseString = response.body;
    if (response.statusCode == 201 || response.statusCode == 200) {
      final identifier = responseString.substring(26, responseString.length - 2);
      return identifier;
    } else {
      if (kDebugMode) {
        print("Error http reason phrase:");
        print(response.reasonPhrase);
      }
      throw Exception('Failed to create interaction');
    }
  }

  static Future<String> upload(String filePath, String interactionID) async {
    await _ensureInitialized();
    var uri = Uri.parse('https://api.elevateai.com/v1/interactions/$interactionID/upload');
    
    var request = http.MultipartRequest('POST', uri)
      ..headers['X-API-Token'] = elevateAIKey
      ..files.add(await http.MultipartFile.fromPath(
        'file',
        filePath,
        contentType: MediaType('audio', 'mp3'),
      ));
    
    var response = await request.send();
    var responseBody = await response.stream.bytesToString();
    return responseBody;
  }

  static Future<void> deleteInteraction(String interactionID) async {
    await _ensureInitialized();
    var uri = Uri.parse('https://api.elevateai.com/v1/interactions/$interactionID');
    await http.delete(uri, headers: {'X-API-Token':elevateAIKey});
  }
  
  static Future<void> waitForProcessingElevateAI(String interactionID) async {
    await _ensureInitialized();
    var uri = Uri.parse('https://api.elevateai.com/v1/interactions/$interactionID/status');
    // In case its a short audio, wait less time the first time. Then assume it's longer to avoid 
    int quickChecksBeforeLongerWait = 3;
    while (true) {
      http.Response response = await http.get(uri, headers: {'X-API-Token':elevateAIKey});
      
      if (jsonDecode(response.body)['status'] == "processed") {
        return;
      } else { //wait a few seconds
        if (quickChecksBeforeLongerWait > 0) {
          quickChecksBeforeLongerWait--;
          await Future.delayed(const Duration(seconds: 3));
        } else {
          await Future.delayed(const Duration(seconds: 15));
        }
      }
    }
  }

  /// Retrieves and splits the transcription into segments based on the specified maximum character limit per segment.
  /// 
  /// The `maxCharPerSegSoftLimit` parameter defines the maximum length of each string in the returned list.
  /// However, if an individual ElevateAI transcription "phrase" is longer than this limit, the string may exceed
  /// the limit because phrases are treated atomically.
  /// 
  /// - Parameters:
  ///   - interactionID: Elevate AI transcription from which to retrieve text.
  ///   - maxCharPerSegSoftLimit: The maximum number of characters allowed per segment.
  /// 
  /// - Returns: A list of strings where each string is a segment of the original text, with lengths
  ///   not exceeding `maxCharPerSegSoftLimit` unless a single phrase is longer than the limit.
  static Future<List<String>> extractText(String interactionID, {int maxCharsPerSegSoftLimit = 3000}) async {
    await _ensureInitialized();
    var uri = Uri.parse('https://api.elevateai.com/v1/interactions/$interactionID/transcripts/punctuated');
    http.Response response = await http.get(uri, headers: {'X-API-Token':elevateAIKey});
    // response.body = raw json;
    List<dynamic> segs = jsonDecode(response.body)["sentenceSegments"];
    List<String> partsOfTask = [];
    List<String> aPartOfTask = [];
    int partLength = 0;
    for (int i = 0; i < segs.length; i++) {
      String phrase = segs[i]["phrase"];
       if (phrase.length + partLength > maxCharsPerSegSoftLimit && partLength > 0) {
        partsOfTask.add(aPartOfTask.join(" "));
        partLength = 0;
        aPartOfTask = [];
      }
      aPartOfTask.add(phrase);
      partLength += phrase.length;
      if (i + 1 == segs.length) {
        partsOfTask.add(aPartOfTask.join(" "));
       }
    }
    return partsOfTask;
  }

  /// Transcribes the given audio file to text using the specified language model.
  ///
  /// This function takes an audio file as input and processes it to generate
  /// a text transcription. The transcription is performed using a language model
  /// specified by the user. The function returns the transcribed text as a string.
  ///
  /// Parameters:
  /// - `fileName`: The path to the audio file that needs to be transcribed.
  /// - `languageModel`: The language model to be used for transcription. This
  ///   parameter is optional and defaults to a standard model if not provided.
  ///
  /// Returns:
  /// - A `String` containing the transcribed text.
  ///
  /// Throws:
  /// - `FileNotFoundException` if the specified audio file does not exist.
  /// - `TranscriptionException` if an error occurs during the transcription process.
  static Future<List<String>> transcribe(String filePath, {int maxCharsPerSegSoftLimit = 3000}) async {
    await _ensureInitialized();
    final interactionID = await createElevateInteraction();
    await upload(filePath, interactionID);
    await waitForProcessingElevateAI(interactionID);
    final parts = await extractText(interactionID, maxCharsPerSegSoftLimit: maxCharsPerSegSoftLimit);
    await deleteInteraction(interactionID);
    return parts;
  }
}