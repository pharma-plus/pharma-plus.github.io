import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/services/auth_store.dart';
import '../../core/services/whatsapp_service.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/glass_card.dart';
import '../shell/shell_nav.dart';
import 'models.dart';

/// Page de chat WhatsApp individuelle
class WhatsAppChatPage extends StatefulWidget {
  final WhatsAppConversation conversation;
  final WhatsAppService? whatsappService;

  const WhatsAppChatPage({
    super.key,
    required this.conversation,
    this.whatsappService,
  });

  @override
  State<WhatsAppChatPage> createState() => _WhatsAppChatPageState();
}

class _WhatsAppChatPageState extends State<WhatsAppChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<WhatsAppMessageUI> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() => _loading = true);
    try {
      final r = await ApiClient.instance.get(
        '/whatsapp/conversations/${widget.conversation.id}/messages',
        query: {'limit': 50},
      );
      if (!mounted) return;
      if (r.success) {
        setState(() {
          _messages = (r.data as List? ?? [])
              .whereType<Map<String, dynamic>>()
              .map(WhatsAppMessageUI.fromJson)
              .toList();
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && !_loading) _loadMessages();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _sending = true;
      _controller.clear();
    });

    try {
      final result = widget.whatsappService?.sendTextMessage(
        to: widget.conversation.contactPhone,
        body: text,
      ) ?? await ApiClient.instance.post(
        '/whatsapp/conversations/${widget.conversation.id}/messages',
        body: {'text': text},
      );

      if (mounted) {
        if (result is WhatsAppSendResult && result.success) {
          _loadMessages();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(result.error ?? 'Erreur envoi'),
            backgroundColor: AppColors.danger,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: AppColors.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.image, color: AppColors.pharmaGold),
            title: const Text('Photo / Vidéo'),
            onTap: () => _sendMedia('image'),
          ),
          ListTile(
            leading: const Icon(Icons.insert_drive_file, color: AppColors.pharmaGold),
            title: const Text('Document'),
            onTap: () => _sendMedia('document'),
          ),
          ListTile(
            leading: const Icon(Icons.videocam, color: AppColors.pharmaGold),
            title: const Text('Vidéo'),
            onTap: () => _sendMedia('video'),
          ),
          ListTile(
            leading: const Icon(Icons.location_on, color: AppColors.pharmaGold),
            title: const Text('Localisation'),
            onTap: () => _sendLocation(),
          ),
          ListTile(
            leading: const Icon(Icons.contact_page, color: AppColors.pharmaGold),
            title: const Text('Contact'),
            onTap: () => _sendContact(),
          ),
        ]),
      ),
    );
  }

  Future<void> _sendMedia(String type) async {
    Navigator.pop(context);
    // TODO: Implémenter picker média
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Envoi $type - à implémenter'),
    ));
  }

  Future<void> _sendLocation() async {
    Navigator.pop(context);
    // TODO: Implémenter envoi localisation
  }

  Future<void> _sendContact() async {
    Navigator.pop(context);
    // TODO: Implémenter envoi contact
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: const ShellBackButton(),
        title: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              widget.conversation.contactName.isNotEmpty
                  ? widget.conversation.contactName[0].toUpperCase()
                  : '?',
              style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.pharmaGold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.conversation.contactName,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                    widget.conversation.status == 'active' ? 'En ligne' : widget.conversation.status,
                    style: TextStyle(fontSize: 11, color: widget.conversation.status == 'active' ? AppColors.success : Colors.grey),
                  ),
              ],
            ),
          ),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.videocam_outlined), onPressed: () {}),
          IconButton(icon: const Icon(Icons.call_outlined), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) => _MessageBubble(message: _messages[i]),
                ),
        ),
        // Barre de saisie
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.pharmaSurface : Colors.white,
            border: Border(top: BorderSide(color: AppColors.dividerDark)),
          ),
          child: SafeArea(
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.attach_file, color: AppColors.pharmaGold),
                onPressed: _showAttachmentOptions,
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: 'Message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: isDark ? AppColors.pharmaSurface : Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                icon: _sending 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send, color: Colors.white),
                onPressed: _sending ? null : _sendMessage,
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Modèle message UI
class WhatsAppMessageUI {
  final String id;
  final String text;
  final bool isMe;
  final DateTime time;
  final String? mediaUrl;
  final WhatsAppMessageType? mediaType;
  final String status; // sent, delivered, read

  const WhatsAppMessageUI({
    required this.id,
    required this.text,
    required this.isMe,
    required this.time,
    this.mediaUrl,
    this.mediaType,
    this.status = 'sent',
  });

  factory WhatsAppMessageUI.fromJson(Map<String, dynamic> json) {
    return WhatsAppMessageUI(
      id: json['id']?.toString() ?? '',
      text: json['text']?.toString() ?? json['body']?.toString() ?? '',
      isMe: json['from_me'] == true || json['is_me'] == true,
      time: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp']) ?? DateTime.now()
          : DateTime.now(),
      mediaUrl: json['media_url']?.toString(),
      mediaType: json['media_type'] != null 
          ? WhatsAppMessageType.values.byName(json['media_type'])
          : null,
      status: json['status']?.toString() ?? 'sent',
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final WhatsAppMessageUI message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? AppColors.pharmaGold : (isDark ? AppColors.pharmaSurface : Colors.white),
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.text.isNotEmpty)
              Text(message.text,
                  style: TextStyle(
                      color: isMe ? Colors.black : Colors.white,
                      fontSize: 14,
                      height: 1.4),
                  ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    '${message.time.hour.toString().padLeft(2, '0')}:${message.time.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                        fontSize: 10,
                        color: isMe ? Colors.black54 : Colors.white60)),
                if (message.isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.status == 'read'
                        ? Icons.done_all
                        : message.status == 'delivered'
                            ? Icons.done_all
                            : Icons.done,
                    size: 14,
                    color: message.status == 'read'
                        ? Colors.blue
                        : (isMe ? Colors.black54 : Colors.white60),
                  ),
                ],
              ],
            ),
          ],
        ),
      );
  }
}