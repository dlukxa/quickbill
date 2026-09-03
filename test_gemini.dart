import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';

void main() async {
  final dio = Dio();
  final apiKey = Platform.environment['GEMINI_API_KEY'] ?? '';
  if (apiKey.isEmpty) {
    print('Please set GEMINI_API_KEY environment variable to test.');
    return;
  }
  final url = 'https://generativelanguage.googleapis.com/v1beta/models/gemma-4-26b-a4b-it:streamGenerateContent?key=$apiKey&alt=sse';
  
  try {
    final response = await dio.post(
      url,
      options: Options(responseType: ResponseType.stream),
      data: {
        'systemInstruction': {
          'parts': [
            {'text': 'You are a helpful POS assistant. Answer clearly.'}
          ]
        },
        'contents': [
          {
            'parts': [
              {'text': 'Hello'}
            ]
          }
        ]
      },
    );
    
    print('Status: ${response.statusCode}');
  } on DioException catch (e) {
    print('Dio Error: ${e.response?.statusCode}');
    
    // We need to decode the stream since we requested ResponseType.stream
    if (e.response?.data is ResponseBody) {
      final stream = (e.response?.data as ResponseBody).stream;
      final bytes = await stream.expand((e) => e).toList();
      print('Body: ${utf8.decode(bytes)}');
    } else {
      print('Body: ${e.response?.data}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
