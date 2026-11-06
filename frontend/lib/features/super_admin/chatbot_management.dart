/// ========================================================================
/// PHARMA+ — SUPER ADMIN : CHATBOT IA
/// ========================================================================
/// Chatbot intelligent avec réponses automatiques et transfert humain.
/// ========================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/auth_store.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/shared/app_search_field.dart';

class ChatbotManagementPage extends StatefulWidget {
  const ChatbotManagementPage({super.key});

  @override
  State<ChatbotManagementPage> createState() => _ChatbotManagementPageState();
}

class _ChatbotManagementPageState extends State<ChatbotManagementPage> {
  final _controller = TextEditingController();
  final _messages = <Map<String, String>>[];
  bool _sending = false;
  List<Map<String, dynamic>> _conversations = [];
  bool _loading = true;
  String? _selectedConversationId;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    setState(() => _loading = true);
    try {
      final r = await ApiClient.instance.get('/whatsapp/conversations', query: {'limit': 20});
      if (!mounted) return;
      setState(() {
        _conversations = (r.success ? r.data : [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList() as List<Map<String, dynamic>>;
        if (_conversations.isNotEmpty) _selectedConversationId = _conversations.first['id'] as String?;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending || _selectedConversationId == null) return;
    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _sending = true;
      _controller.clear();
    });
    try {
      final r = await ApiClient.instance.post('/chatbot/message', body: {
        'conversationId': _selectedConversationId,
        'message': text,
      });
      if (!mounted) return;
      setState(() => _sending = false);
      if (r.success && r.data != null) {
        final d = r.data as Map;
        _messages.add({'role': 'bot', 'text': d['response']?.toString() ?? 'Réponse'});
        if (d['transferToHuman'] == true) {
          _messages.add({'role': 'bot', 'text': 'Transfert vers un opérateur humain en cours...'});
        }
      } else {
        _messages.add({'role': 'bot', 'text': r.error?.readableMessage ?? 'Erreur'});
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _messages.add({'role': 'bot', 'text': e.toString()});
      });
    }
  }

  Future<void> _transferToHuman() async {
    if (_selectedConversationId == null) return;
    final r = await ApiClient.instance.post('/chatbot/transfer', body: {
      'conversationId': _selectedConversationId,
    });
    if (!mounted) return;
    if (r.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transféré vers un opérateur humain')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(r.error?.readableMessage ?? 'Erreur')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.read<AuthStore>().locale;
    return Scaffold(
      backgroundColor: _kSuperAdminDark,
      appBar: AppBar(
        backgroundColor: _kSuperAdminDark.withValues(alpha: 0.95),
        elevation: 0,
        leading: const ShellBackButton(),
        title: const Text('Chatbot IA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        actions: [
          if (_selectedConversationId != null)
            GradientButton(
              label: 'Transfert humain',
              icon: Icons.person,
              onPressed: _transferToHuman,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kSuperAdminGold))
          : Column(
              children: [
                // Sélecteur de conversation
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedConversationId,
                          decoration: InputDecoration(
                            labelText: 'Conversation',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          items: _conversations.map((c) => DropdownMenuItem(
                            value: c['id'] as String?,
                            child: Text('${c['contactName'] ?? 'Contact'} (${c['contactPhone'] ?? ''})'),
                          )).toList(),
                          onChanged: (v) => setState(() => _selectedConversationId = v),
                        ),
                      ),
                    ],
                  ),
                ),
                // Zone de chat
                Expanded(
                  child: _messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.smart_toy, color: _kSuperAdminGold.withValues(alpha: 0.3), size: 64),
                              const SizedBox(height: 16),
                              Text('Sélectionnez une conversation pour discuter avec le chatbot',
                                  style: TextStyle(color: Colors.white60)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _messages.length,
                          itemBuilder: (_, i) {
                            final m = _messages[i];
                            final isUser = m['role'] == 'user';
                            return Align(
                              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isUser ? _kSuperAdminGold : Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  m['text'] ?? '',
                                  style: TextStyle(color: isUser ? Color(0xFF03100D) : Colors.white),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                // Saisie
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: InputDecoration(
                            hintText: 'Écrivez votre message...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GradientButton(
                        label: 'Envoyer',
                        icon: Icons.send,
                        onPressed: _sending ? null : _send,
                        loading: _sending,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// ──────────────────────────────────────────────────────────────────────
// THÈME
// ──────────────────────────────────────────────────────────────────────
const Color _kSuperAdminDark = Color(0xFF03100D);
const Color _kSuperAdminSurface = Color(0xFF0A1E15);
const Color _kSuperAdminGold = Color(0xFFD9B45C);
const Color _kSuperAdminAccent = Color(0xFF2FB563);

class ShellBackButton extends StatelessWidget {
  const ShellBackButton({super.key});
  @override
  Widget build(BuildContext context) {
    return IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white70), onPressed: () => Navigator.of(context).pop());
  }
}
