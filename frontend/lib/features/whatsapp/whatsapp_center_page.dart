import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/services/auth_store.dart';
import '../../core/services/whatsapp_service.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/shared/app_search_field.dart';

/// Centre de communication WhatsApp
class WhatsAppCenterPage extends StatefulWidget {
  const WhatsAppCenterPage({super.key});

  @override
  State<WhatsAppCenterPage> createState() => _WhatsAppCenterPageState();
}

class _WhatsAppCenterPageState extends State<WhatsAppCenterPage> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<WhatsAppConversation> _conversations = [];
  bool _loading = true;
  String? _error;
  WhatsAppService? _whatsappService;
  String _activeTab = 'conversations';

  static const _tabs = [
    ('conversations', Icons.chat_bubble_outline, 'conversations'),
    ('templates', Icons.description_outlined, 'templates'),
    ('campaigns', Icons.campaign_outlined, 'campaigns'),
    ('settings', Icons.settings_outlined, 'whatsappSettings'),
  ];

  @override
  void initState() {
    super.initState();
    _initWhatsApp();
    _loadConversations();
  }

  Future<void> _initWhatsApp() async {
    // Initialiser le service WhatsApp avec la config depuis l'API
    try {
      final configResult = await ApiClient.instance.get('/whatsapp/config');
      if (configResult.success && configResult.data != null) {
        final config = configResult.data;
        _whatsappService = WhatsAppService(WhatsAppConfig(
          phoneNumberId: config['phone_number_id'],
          accessToken: config['access_token'],
          businessAccountId: config['business_account_id'],
          webhookVerifyToken: config['webhook_verify_token'],
        ));
      }
    } catch (e) {
      debugPrint('WhatsApp init error: $e');
    }
  }

  Future<void> _loadConversations() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await ApiClient.instance.get('/whatsapp/conversations', query: {
        'limit': 50,
        if (_search.text.trim().isNotEmpty) 'q': _search.text.trim(),
      });
      if (!mounted) return;
      if (!r.success) {
        setState(() {
          _loading = false;
          _error = r.error?.readableMessage ?? 'Erreur';
        });
        return;
      }
      setState(() {
        _conversations = (r.data as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(WhatsAppConversation.fromJson)
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _loadConversations());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _openChat(WhatsAppConversation conv) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => WhatsAppChatPage(conversation: conv, whatsappService: _whatsappService),
    ));
  }

  void _showTemplateDialog() {
    // Dialogue de création/édition template
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: const ShellBackButton(),
        title: Text(S.t('whatsappCenter', locale)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.pharmaGold),
            onPressed: _loadConversations,
            tooltip: S.t('refresh', locale),
          ),
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.pharmaGold),
            onPressed: _showNewConversationDialog,
            tooltip: S.t('newConversation', locale),
          ),
        ],
      ),
      body: Column(children: [
        // Onglets
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: SegmentedButton<String>(
            segments: [
              for (final (key, icon, label) in _tabs)
                ButtonSegment(
                  value: key,
                  icon: Icon(icon, size: 18),
                  label: Text(S.t(label, locale)),
                ),
            ],
            selected: {_activeTab},
            onSelectionChanged: (sel) => setState(() => _activeTab = sel.first),
          ),
        ),
        // Barre de recherche
        Padding(
          padding: const EdgeInsets.all(12),
          child: AppSearchField(
            controller: _search,
            hint: S.t('search', locale),
            showFilterButton: false,
            debounceDuration: Duration.zero,
            onChanged: _onSearchChanged,
          ),
        ),
        // Contenu
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!))
                  : _conversations.isEmpty
                      ? _EmptyState(onAdd: _showNewConversationDialog, locale: locale)
                      : RefreshIndicator(
                          onRefresh: _loadConversations,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                            itemCount: _conversations.length,
                            itemBuilder: (context, i) {
                              final conv = _conversations[i];
                              return _ConversationTile(
                                conversation: conv,
                                onTap: () => _openChat(conv),
                              );
                            },
                          ),
                        ),
        ),
      ]),
    );
  }

  void _showNewConversationDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(S.t('newConversation', context.read<AuthStore>().locale)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              decoration: InputDecoration(labelText: 'Numéro WhatsApp'),
              keyboardType: TextInputType.phone,
              onFieldSubmitted: (v) {
                Navigator.pop(context);
                // Créer nouvelle conversation
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ],
      ),
    );
  }
}

/// Modèle de conversation WhatsApp
class WhatsAppConversation {
  final String id;
  final String contactName;
  final String contactPhone;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final bool isGroup;
  final String? avatarUrl;
  final String status; // active, closed, pending

  const WhatsAppConversation({
    required this.id,
    required this.contactName,
    required this.contactPhone,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.isGroup = false,
    this.avatarUrl,
    this.status = 'active',
  });

  factory WhatsAppConversation.fromJson(Map<String, dynamic> json) {
    return WhatsAppConversation(
      id: json['id']?.toString() ?? '',
      contactName: json['contact_name']?.toString() ?? '',
      contactPhone: json['contact_phone']?.toString() ?? '',
      lastMessage: json['last_message']?.toString(),
      lastMessageTime: json['last_message_time'] != null 
          ? DateTime.tryParse(json['last_message_time']) : null,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      isGroup: json['is_group'] == true,
      avatarUrl: json['avatar_url']?.toString(),
      status: json['status']?.toString() ?? 'active',
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  final String locale;
  const _EmptyState({required this.onAdd, required this.locale});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.chat_bubble_outline, size: 64, color: AppColors.warning),
          const SizedBox(height: 16),
          Text(S.t('noConversations', locale),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(S.t('addFirstConversation', locale),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          GradientButton(label: 'Nouvelle conversation', icon: Icons.add, onPressed: onAdd),
        ]),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final WhatsAppConversation conversation;
  final VoidCallback onTap;
  const _ConversationTile({required this.conversation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        radius: BorderRadius.circular(16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        onTap: onTap,
        child: Row(children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            backgroundImage: conversation.avatarUrl != null ? NetworkImage(conversation.avatarUrl!) : null,
            child: conversation.avatarUrl == null
                ? Text(
                    conversation.contactName.isNotEmpty
                        ? conversation.contactName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppColors.pharmaGold,
                        fontSize: 18),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(conversation.contactName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                    conversation.lastMessage ?? 'Aucun message',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (conversation.lastMessageTime != null)
                  Text(
                    _formatTime(conversation.lastMessageTime!),
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                if (conversation.unreadCount > 0)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.pharmaGold,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      conversation.unreadCount > 99 ? '99+' : conversation.unreadCount.toString(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900),
                    ),
                  ),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}j';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}min';
    return 'maintenant';
  }
}