// ignore_for_file: avoid_print, prefer_const_constructors, prefer_const_declarations
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';

void main() async {
  final apiKey = Platform.environment['GEMINI_API_KEY'] ?? '';
  if (apiKey.isEmpty) {
    print('Please set GEMINI_API_KEY environment variable to test.');
    return;
  }
  final dio = Dio();
  
  final imagePath = 'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png';
  final imageFile = File(imagePath);
  if (!imageFile.existsSync()) {
    print('Image not found at $imagePath');
    return;
  }
  
  final base64Image = base64Encode(imageFile.readAsBytesSync());
  
  // Test Gemini 2.5 Flash
  print('Sending image to gemini-2.5-flash...');
  var stopwatch = Stopwatch()..start();
  try {
    final response = await dio.post(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
      data: {
        'contents': [
          {
            'parts': [
              {
                'text': 'Describe this image briefly.'
              },
              {
                'inlineData': {
                  'mimeType': 'image/png',
                  'data': base64Image
                }
              }
            ]
          }
        ]
      },
    );
    stopwatch.stop();
    print('Gemini 2.5 Flash took: ${stopwatch.elapsedMilliseconds} ms');
    final text = response.data['candidates']?[0]?['content']?['parts']?[0]?['text'];
    print('Response: $text');
  } catch (e) {
    print('Gemini 2.5 Flash failed: $e');
  }

  // Test Gemma 4 26B
  print('\nSending image to gemma-4-26b-a4b-it...');
  stopwatch = Stopwatch()..start();
  try {
    final response = await dio.post(
      'https://generativelanguage.googleapis.com/v1beta/models/gemma-4-26b-a4b-it:generateContent?key=$apiKey',
      data: {
        'contents': [
          {
            'parts': [
              {
                'text': 'Describe this image briefly.'
              },
              {
                'inlineData': {
                  'mimeType': 'image/png',
                  'data': base64Image
                }
              }
            ]
          }
        ]
      },
    );
    stopwatch.stop();
    print('Gemma 4 took: ${stopwatch.elapsedMilliseconds} ms');
    final text = response.data['candidates']?[0]?['content']?['parts']?[0]?['text'];
    print('Response: $text');
  } catch (e) {
    print('Gemma 4 failed: $e');
  }
}
