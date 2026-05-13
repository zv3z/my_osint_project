import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/scan_result.dart';
import '../services/api_service.dart';
import '../widgets/glass_card.dart';

class AiTab extends StatefulWidget {
  final ScanResult result;
  const AiTab({super.key, required this.result});

  @override
  State<AiTab> createState() => _AiTabState();
}

class _AiTabState extends State<AiTab> {
  String _analysis    = '';
  bool   _loadingAi   = false;
  bool   _loadingChat = false;
  final  _chatCtrl    = TextEditingController();
  final  _scrollCtrl  = ScrollController();
  final  List<_Msg>   _messages = [];

  @override
  void initState() {
    super.initState();
    _loadAnalysis();
  }

  @override
  void dispose() {
    _chatCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAnalysis() async {
    setState(() => _loadingAi = true);
    try {
      final lang = context.read<AppState>().lang;
      final a = await ApiService.analyze(widget.result.target, lang: lang);
      setState(() { _analysis = a; _loadingAi = false; });
    } catch (e) {
      setState(() {
        _analysis = 'Error loading analysis. Make sure TitanAI is configured.';
        _loadingAi = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final msg = _chatCtrl.text.trim();
    if (msg.isEmpty || _loadingChat) return;

    _chatCtrl.clear();
    HapticFeedback.lightImpact();
    setState(() {
      _messages.add(_Msg(role: 'user', content: msg));
      _loadingChat = true;
    });
    _scrollToBottom();

    try {
      final lang = context.read<AppState>().lang;
      final reply = await ApiService.chat(
        msg,
        widget.result.target,
        widget.result.ttype,
        widget.result.results,
        _analysis,
        lang: lang,
      );
      setState(() {
        _messages.add(_Msg(role: 'ai', content: reply));
        _loadingChat = false;
      });
    } catch (_) {
      setState(() {
        _messages.add(_Msg(role: 'ai', content: 'Error: Could not reach TitanAI'));
        _loadingChat = false;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _scrollCtrl,
            padding: const EdgeInsets.all(16),
            children: [
              // Analysis card
              GlassCard(
                backgroundColor: const Color(0x0D6366F1),
                borderColor: const Color(0x256366F1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [TitanTheme.indigo, TitanTheme.cyan]),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.psychology,
                              color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Text('TitanAI Analysis',
                            style: GoogleFonts.spaceGrotesk(
                                fontSize: 15, fontWeight: FontWeight.w700,
                                color: TitanTheme.textPrimary)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.refresh_outlined,
                              size: 18, color: TitanTheme.textMuted),
                          onPressed: _loadAnalysis,
                          tooltip: 'Re-analyze',
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_outlined,
                              size: 18, color: TitanTheme.textMuted),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _analysis));
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Copied!')));
                          },
                          tooltip: 'Copy',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (_loadingAi)
                      const Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(color: TitanTheme.indigo),
                            SizedBox(height: 10),
                            Text('Analyzing with Gemini...',
                                style: TextStyle(
                                    color: TitanTheme.textMuted, fontSize: 13)),
                          ],
                        ),
                      )
                    else
                      Text(
                        _analysis,
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          color: TitanTheme.textSecondary,
                          height: 1.7,
                        ),
                      ),
                  ],
                ),
              ),

              // Chat history
              if (_messages.isNotEmpty) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text('CHAT',
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 11, fontWeight: FontWeight.w600,
                            color: TitanTheme.textMuted, letterSpacing: 0.1)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _messages.clear()),
                      child: Text('Clear',
                          style: TextStyle(
                              fontSize: 12, color: TitanTheme.red.withAlpha(178))),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._messages.map((m) => _buildChatBubble(m)),
                if (_loadingChat)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [TitanTheme.indigo, TitanTheme.cyan]),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.psychology,
                              color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 10),
                        const SizedBox(
                          width: 40, height: 20,
                          child: LinearProgressIndicator(
                              color: TitanTheme.indigo,
                              backgroundColor: Color(0x1A6366F1)),
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 80),
            ],
          ),
        ),

        // Chat input
        Container(
          padding: EdgeInsets.fromLTRB(
              16, 10, 16, MediaQuery.of(context).viewInsets.bottom + 16),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: TitanTheme.borderColor)),
            color: TitanTheme.bgPrimary,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatCtrl,
                  enabled: !_loadingChat && !_loadingAi,
                  decoration: const InputDecoration(
                    hintText: 'Ask TitanAI...',
                    prefixIcon: Icon(Icons.chat_bubble_outline,
                        size: 18, color: TitanTheme.textMuted),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _loadingChat ? null : _sendMessage,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(50, 50),
                  padding: EdgeInsets.zero,
                  backgroundColor: TitanTheme.indigo,
                ),
                child: _loadingChat
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send_rounded, size: 18),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChatBubble(_Msg m) {
    final isUser = m.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [TitanTheme.indigo, TitanTheme.cyan]),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(Icons.psychology, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? TitanTheme.indigo.withAlpha(38)
                    : TitanTheme.bgCard,
                borderRadius: BorderRadius.only(
                  topLeft:     const Radius.circular(16),
                  topRight:    const Radius.circular(16),
                  bottomLeft:  Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: Border.all(
                  color: isUser
                      ? TitanTheme.indigo.withAlpha(76)
                      : TitanTheme.borderColor,
                ),
              ),
              child: Text(
                m.content,
                style: GoogleFonts.inter(
                    fontSize: 13.5,
                    color: TitanTheme.textPrimary,
                    height: 1.5),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _Msg {
  final String role;
  final String content;
  _Msg({required this.role, required this.content});
}
