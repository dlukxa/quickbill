import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../models/ai_message.dart';
import '../../services/ai/ai_engine_service.dart';
import '../../providers/branch_provider.dart';
import '../../config/theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../generated/l10n/app_localizations.dart';

class AIAssistantScreen extends ConsumerStatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  ConsumerState<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends ConsumerState<AIAssistantScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<AIMessage> _messages = [];
  bool _isLoading = false;

  List<String> get _suggestedQueries {
    final l10n = AppLocalizations.of(context)!;
    return [
      l10n.aiQuerySalesToday,
      l10n.aiQueryLowStock,
      l10n.aiQueryInventory,
    ];
  }

  @override
  void initState() {
    super.initState();
    AIEngineService.instance.addListener(_onEngineStateChanged);
  }

  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _messages.add(AIMessage(
        text: AppLocalizations.of(context)!.aiWelcomeMessage,
        isUser: false,
      ));
      _initialized = true;
    }
  }

  @override
  void dispose() {
    AIEngineService.instance.removeListener(_onEngineStateChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onEngineStateChanged() {
    if (mounted) setState(() {});
  }



  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage(String query) async {
    final branchId = ref.read(currentBranchIdProvider);
    if (query.trim().isEmpty) return;
    setState(() {
      _messages.add(AIMessage(text: query, isUser: true));
      _isLoading = true;
    });
    _messageController.clear();
    _scrollToBottom();

    // Pass history EXCLUDING the message we just added
    final history = _messages.sublist(0, _messages.length - 1);
    
    // Create a placeholder message for the AI response
    final aiMessageIndex = _messages.length;
    setState(() {
      _messages.add(AIMessage(text: AppLocalizations.of(context)!.aiThinkingMessage, isUser: false));
    });

    try {
      final stream = AIEngineService.instance.processQueryStream(query, branchId, history: history);
      
      bool isFirst = true;
      await for (final chunk in stream) {
        if (mounted) {
          setState(() {
            if (isFirst) {
              _messages[aiMessageIndex] = AIMessage(text: chunk, isUser: false);
              isFirst = false;
            } else {
              _messages[aiMessageIndex] = AIMessage(text: chunk, isUser: false);
            }
            _isLoading = false; 
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages[aiMessageIndex] = AIMessage(text: "${AppLocalizations.of(context)!.aiErrorPrefix}$e", isUser: false);
          _isLoading = false;
        });
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Flexible(
              child: Text(
                AppLocalizations.of(context)!.aiScreenTitle,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  letterSpacing: -0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Text(
                'Cloud AI Active',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10, 
                  fontWeight: FontWeight.w800, 
                  color: Colors.amber,
                ),
              ),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        actions: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Icon(Icons.verified, color: Colors.amber),
          ),
        ],
      ),
      body: Column(
        children: [
          // Suggestions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _suggestedQueries
                    .map((query) => Padding(
                          padding: const EdgeInsets.only(right: 10.0),
                          child: OutlinedButton(
                            onPressed: () => _sendMessage(query),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.05),
                              side: BorderSide(color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            child: Text(
                              query, 
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13, 
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),

          const Divider(height: 1),

          // Chat messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),

          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context)!.aiThinkingStatus,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),

          // Input Navbar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    if (!context.isDark)
                      BoxShadow(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                        blurRadius: 24,
                        spreadRadius: 4,
                        offset: const Offset(0, 8),
                      ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: context.borderColor.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15, 
                          color: context.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(context)!.aiMessageHint,
                          hintStyle: TextStyle(color: context.subText, fontSize: 15),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onSubmitted: _sendMessage,
                      ),
                    ),
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.primaryGreen, AppTheme.darkGreen],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(30),
                          onTap: () => _sendMessage(_messageController.text),
                          child: const Padding(
                            padding: EdgeInsets.all(10.0),
                            child: Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(AIMessage msg) {
    final isUser = msg.isUser;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.auto_awesome, size: 16, color: AppTheme.primaryPurple),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              decoration: BoxDecoration(
                color: isUser ? null : context.cardColor,
                gradient: isUser ? AppTheme.primaryGradient : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(24),
                  topRight: const Radius.circular(24),
                  bottomLeft: Radius.circular(isUser ? 24 : 6),
                  bottomRight: Radius.circular(isUser ? 6 : 24),
                ),
                border: isUser ? null : Border.all(color: context.borderColor.withValues(alpha: 0.8)),
              ),
              child: isUser
                  ? Text(
                      msg.text,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white, 
                        height: 1.5, 
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  : MarkdownBody(
                      data: msg.text,
                      styleSheet: MarkdownStyleSheet(
                        pPadding: const EdgeInsets.only(bottom: 8),
                        p: GoogleFonts.plusJakartaSans(
                          color: context.onSurface, 
                          fontSize: 15, 
                          height: 1.6,
                        ),
                        strong: GoogleFonts.plusJakartaSans(
                          color: context.onSurface, 
                          fontWeight: FontWeight.bold, 
                          fontSize: 15,
                        ),
                        em: TextStyle(color: context.subText, fontStyle: FontStyle.italic),
                        listBullet: const TextStyle(color: AppTheme.primaryPurple, fontSize: 15, fontWeight: FontWeight.bold),
                        listIndent: 24,
                      ),
                      shrinkWrap: true,
                    ),
            ),
          ),
          if (isUser) ...[
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person, size: 16, color: AppTheme.primaryGreen),
            ),
          ],
        ],
      ),
    );
  }
}
