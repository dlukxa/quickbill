import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'orchestrator.dart';
import 'response_synthesizer.dart';
import 'agents/base_agent.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/ai_message.dart';
import '../remote_config_service.dart';

class AIEngineService extends ChangeNotifier {
  static final AIEngineService _instance = AIEngineService._internal();
  static AIEngineService get instance => _instance;
  AIEngineService._internal();

  final _orchestrator = AIOrchestrator();
  final _synthesizer  = ResponseSynthesizer();

  // ─── Gemma Initialisation ──────────────────────────────────────────────────

  // Local flutter_gemma model is replaced by Cloud API for much better Sinhala/Tamil support
  bool get isGemmaLoaded => true; 
  bool get isInitializing => false;
  String? get lastError => null;

  Future<void> initGemmaIfAvailable() async {
    // Cloud API is always available, no download needed
  }

  void resetGemmaState() {
    // No-op for cloud
  }

  // ─── Main Entry Point ──────────────────────────────────────────────────────

  /// Multi-Agentic RAG pipeline:
  /// 1. Orchestrator analyses query → selects agents
  /// 2. Agents run in parallel     → each fetches its data domain
  /// 3. Synthesizer merges results → direct answer OR combined context
  /// 4. Gemma InsightsAgent        → advice/insights on synthesized data
  Stream<String> processQueryStream(
    String query,
    int branchId, {
    List<AIMessage> history = const [],
  }) async* {
    debugPrint('🚀 Multi-Agent Query: "$query"');

    try {
      await initGemmaIfAvailable();
      
      final context = AgentContext(
        userQuery: query, 
        branchId: branchId,
        history: history,
      );
      final prefs = await SharedPreferences.getInstance();
      String langCode = prefs.getString('language_code') ?? 'en';

      // Auto-detect Sinhala or Tamil script in query to reply in that language
      if (RegExp(r'[\u0D80-\u0DFF]').hasMatch(query)) {
        langCode = 'si';
      } else if (RegExp(r'[\u0B80-\u0BFF]').hasMatch(query)) {
        langCode = 'ta';
      }

      final isEnglish = langCode == 'en';

      // Step 1: Orchestrator selects agents
      final plan = _orchestrator.plan(query, history: history);
      
      // If language isn't English, we force Gemma to translate everything
      final needsGemma = plan.needsGemmaInsights || !isEnglish;
      
      debugPrint('📋 Plan: [${plan.agents.map((a) => a.name).join(', ')}]'
          ' | needsGemma=$needsGemma (lang: $langCode)');

      // Step 2: Run all selected agents in parallel
      final results = await _orchestrator.run(plan, context);

      // Step 3: Synthesizer tries to build a direct factual answer (only if english + simple query)
      final directAnswer = _synthesizer.buildDirectAnswer(results, query);

      if (directAnswer != null && !needsGemma) {
        debugPrint('✅ Direct answer — no LLM needed.');
        yield directAnswer;
        return;
      }

      // Step 4: Merge all agent data and pass to Gemma for insights or translation
      final combinedData = _synthesizer.synthesize(results);

      if (true) {
        // Advanced Mode: Always use Cloud AI for non-direct lookups
        yield* _askGemmaWithContext(query, combinedData ?? '', langCode, history: history);
      } else if (combinedData != null) {
        // Lite Mode: Context-based queries
        yield combinedData;
      } else {
        // Lite Mode: Greeting / general query fallback
        yield 'Hello! I am your QuickBill AI assistant.\n\n'
            'I can help you analyze your shop data. Try asking me:\n'
            '• **What are my sales today?**\n'
            '• **Are any items low on stock?**\n'
            '• **How much have we spent on expenses?**\n'
            '• **Who are my top debtors?**\n\n'
            '_Tip: Download the Advanced Model using the cloud icon in the top right for business advice, custom insights, and multi-language support!_';
      }
    } catch (e) {
      debugPrint('❌ Multi-Agent Error: $e');
      yield 'There was an error processing your request. Please try again.';
    }
  }

  // ─── InsightsAgent (Cloud API via Remote Config) ───────────────────────────

  Stream<String> _askGemmaWithContext(
    String query, 
    String combinedData, 
    String langCode, {
    List<AIMessage> history = const [],
  }) async* {
    try {
      final apiKey = RemoteConfigService.instance.geminiApiKey;
      if (apiKey.isEmpty) {
        debugPrint('⚠️ Remote Config gemini_api_key is empty. Falling back to local data.');
        if (combinedData.trim().isNotEmpty) {
          yield combinedData;
        } else {
          yield 'Hello! I am your QuickBill AI assistant.\n\n'
              'I can help you analyze your shop data. Try asking me:\n'
              '• **What are my sales today?**\n'
              '• **Are any items low on stock?**\n'
              '• **How much have we spent on expenses?**\n'
              '• **Who are my top debtors?**';
        }
        return;
      }

      debugPrint('🤖 InsightsAgent: invoking Cloud API (Lang: $langCode, History: ${history.length})...');
      final prompt = StringBuffer();
      
      // Inject History (Last 3 messages to keep context lean)
      if (history.isNotEmpty) {
        prompt.writeln('Previous conversation:');
        final recentHistory = history.length > 4 ? history.sublist(history.length - 4) : history;
        for (var msg in recentHistory) {
          prompt.writeln('${msg.isUser ? "Owner" : "AI"}: ${msg.text}');
        }
        prompt.writeln('---');
      }

      if (combinedData.trim().isNotEmpty) {
        prompt.writeln('Shop data:\n$combinedData\n');
        prompt.writeln('If the question asks for facts, just summarize the data cleanly.');
        if (query.toLowerCase().contains('improve') || query.contains('how') || query.contains('tip')) {
          prompt.writeln('Give 2-3 specific actionable tips based on the shop data above.');
        }
      } else {
        prompt.writeln('You are a helpful POS AI business assistant. Respond to the owner\'s greeting or general question naturally, professionally, and briefly.');
      }
      
      prompt.writeln('\nOwner question: $query');
      
      if (langCode == 'si') {
        prompt.writeln('CRITICAL INSTRUCTION: YOU MUST REPLY STRICTLY IN THE SINHALA (සිංහල) LANGUAGE ONLY. Do NOT use English.');
      } else if (langCode == 'ta') {
        prompt.writeln('CRITICAL INSTRUCTION: YOU MUST REPLY STRICTLY IN THE TAMIL (தமிழ்) LANGUAGE ONLY. Do NOT use English.');
      }

      // We use Dio to stream response from Cloud
      final dio = Dio();
      final response = await dio.post(
        'https://generativelanguage.googleapis.com/v1beta/models/gemma-4-26b-a4b-it:streamGenerateContent?key=$apiKey&alt=sse',
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
                {'text': prompt.toString()}
              ]
            }
          ]
        },
      );

      String fullResponse = '';
      bool gotFirst = false;

      final stream = response.data.stream as Stream<List<int>>;
      await for (final chunk in stream) {
        final decodedChunk = utf8.decode(chunk);
        
        // Very basic SSE parsing
        final lines = decodedChunk.split('\n');
        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final dataStr = line.substring(6).trim();
            if (dataStr.isNotEmpty) {
              try {
                final jsonChunk = jsonDecode(dataStr);
                final candidates = jsonChunk['candidates'] as List?;
                if (candidates != null && candidates.isNotEmpty) {
                  final parts = candidates.first['content']?['parts'] as List?;
                  if (parts != null) {
                    for (final p in parts) {
                      if (p['thought'] != true) {
                        final text = p['text'] as String?;
                        if (text != null && text.isNotEmpty) {
                          fullResponse += text;
                          if (!gotFirst) {
                            debugPrint('📥 InsightsAgent: first token received.');
                            gotFirst = true;
                          }
                          yield fullResponse;
                        }
                      }
                    }
                  }
                }
              } catch (e) {
                // Ignore parse errors on partial chunks
              }
            }
          }
        }
      }

      if (fullResponse.trim().isEmpty) {
        if (combinedData.trim().isNotEmpty) {
          yield combinedData;
        } else {
          yield '**Tips to grow your business:**\n'
              '• Keep your best-selling items well-stocked.\n'
              '• Review your daily sales report to spot trends.\n'
              '• Offer promotions on slow-moving stock.';
        }
      }
    } catch (e) {
      debugPrint('⚠️ InsightsAgent error: $e');
      if (e is DioException) {
        String errorDetail = '';
        try {
          if (e.response?.data is ResponseBody) {
            final stream = (e.response?.data as ResponseBody).stream;
            final bytes = await stream.expand((e) => e).toList();
            final bodyStr = utf8.decode(bytes);
            final jsonErr = jsonDecode(bodyStr);
            errorDetail = jsonErr['error']?['message']?.toString() ?? bodyStr;
          } else {
            errorDetail = e.response?.data?.toString() ?? e.message ?? '';
          }
        } catch (_) {
          errorDetail = e.message ?? '';
        }

        if (e.response?.statusCode == 429 || errorDetail.contains('prepayment') || errorDetail.contains('RESOURCE_EXHAUSTED')) {
          debugPrint('⚠️ AI Quota / Prepayment alert: $errorDetail');
          if (combinedData.trim().isNotEmpty) {
            yield '$combinedData\n\n*(Note: Cloud AI quota is currently resting; displaying accurate local shop data).*';
          } else {
            yield 'Hello! I am your QuickBill AI Assistant.\n\n'
                'I can help you review your business metrics right now. Try asking:\n'
                '• **What are my sales today?**\n'
                '• **Are any items low on stock?**\n'
                '• **Who owes money?**';
          }
          return;
        }

        yield '**AI Notice:** Unable to reach cloud AI (${e.response?.statusCode ?? 'Offline'}).\n\n'
            '${combinedData.isNotEmpty ? combinedData : 'Please verify your internet connection or Google AI Studio project status.'}';
      } else {
        if (combinedData.trim().isNotEmpty) {
          yield combinedData;
        } else {
          yield '**Notice:** $e';
        }
      }
    }
  }

  // ─── Compatibility ─────────────────────────────────────────────────────────

  Future<String> processQuery(String query, int branchId,
      {List<AIMessage> history = const []}) async {
    String last = '';
    await for (final val in processQueryStream(query, branchId, history: history)) {
      last = val;
    }
    return last;
  }

  /// Sends a direct prompt text to the Cloud AI and returns the completed text response.
  Future<String> askGemmaDirect(String promptText) async {
    final apiKey = RemoteConfigService.instance.geminiApiKey;
    if (apiKey.isEmpty) {
      throw Exception('Gemini API key is not configured in Remote Config.');
    }

    final dio = Dio();
    final response = await dio.post(
      'https://generativelanguage.googleapis.com/v1beta/models/gemma-4-26b-a4b-it:generateContent?key=$apiKey',
      data: {
        'contents': [
          {
            'parts': [
              {'text': promptText}
            ]
          }
        ]
      },
    );

    final data = response.data;
    final candidates = data['candidates'] as List?;
    if (candidates != null && candidates.isNotEmpty) {
      final parts = candidates.first['content']?['parts'] as List?;
      if (parts != null) {
        String result = '';
        for (final p in parts) {
          if (p['thought'] != true) {
             final text = p['text'] as String?;
             if (text != null) result += text;
          }
        }
        return result;
      }
    }
    return '';
  }
}
