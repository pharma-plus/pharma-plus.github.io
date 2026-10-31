/// ============================================================
/// MODÈLES WHATSAPP PARTAGÉS
/// ============================================================

/// Type de message WhatsApp
enum WhatsAppMessageType {
  text,
  image,
  document,
  video,
  audio,
  sticker,
  template,
  interactive,
  location,
  contacts,
  reaction,
}

/// Conversation WhatsApp
class WhatsAppConversation {
  final String id;
  final String contactName;
  final String contactPhone;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final bool isGroup;
  final String? avatarUrl;
  final String status;

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

/// Message WhatsApp pour l'UI
class WhatsAppMessageUI {
  final String id;
  final String text;
  final bool isMe;
  final DateTime time;
  final String? mediaUrl;
  final WhatsAppMessageType? mediaType;
  final String status;

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