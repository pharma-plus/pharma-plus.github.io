/// ============================================================
/// WHATSAPP BUSINESS API SERVICE
/// Integration with Meta WhatsApp Business Cloud API
/// ============================================================

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../core/services/api_client.dart';
import '../../core/services/auth_store.dart';

/// Configuration WhatsApp Business API
class WhatsAppConfig {
  final String phoneNumberId;
  final String accessToken;
  final String businessAccountId;
  final String webhookVerifyToken;
  final String apiVersion;

  const WhatsAppConfig({
    required this.phoneNumberId,
    required this.accessToken,
    required this.businessAccountId,
    required this.webhookVerifyToken,
    this.apiVersion = 'v18.0',
  });

  String get baseUrl => 'https://graph.facebook.com/$apiVersion/$phoneNumberId';
  String get messagesUrl => '$baseUrl/messages';
  String get templatesUrl => '$baseUrl/message_templates';
  String get mediaUrl => '$baseUrl/media';
  String get webhookUrl => '$baseUrl/webhooks';
}

/// Message WhatsApp sortant
class WhatsAppMessage {
  final String to; // Format: 2126XXXXXXXX (Maroc)
  final WhatsAppMessageType type;
  final dynamic content;
  final String? contextMessageId; // Pour réponses
  final Map<String, dynamic>? metadata;

  const WhatsAppMessage({
    required this.to,
    required this.type,
    required this.content,
    this.contextMessageId,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'messaging_product': 'whatsapp',
      'to': to,
      'type': type.name,
    };
    
    if (contextMessageId != null) {
      json['context'] = {'message_id': contextMessageId};
    }
    
    switch (type) {
      case WhatsAppMessageType.text:
        json['text'] = {'body': content as String};
        break;
      case WhatsAppMessageType.image:
      case WhatsAppMessageType.document:
      case WhatsAppMessageType.video:
      case WhatsAppMessageType.audio:
      case WhatsAppMessageType.sticker:
        json[type.name] = content;
        break;
      case WhatsAppMessageType.template:
        json['template'] = content;
        break;
      case WhatsAppMessageType.interactive:
        json['interactive'] = content;
        break;
      case WhatsAppMessageType.location:
        json['location'] = content;
        break;
      case WhatsAppMessageType.contacts:
        json['contacts'] = content;
        break;
      case WhatsAppMessageType.reaction:
        json['reaction'] = content;
        break;
    }
    
    return json;
  }
}

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

/// Template WhatsApp
class WhatsAppTemplate {
  final String name;
  final String language; // ex: 'fr', 'ar', 'en'
  final WhatsAppTemplateCategory category;
  final List<WhatsAppTemplateComponent> components;
  final String? status;
  final String? id;

  const WhatsAppTemplate({
    required this.name,
    required this.language,
    required this.category,
    required this.components,
    this.status,
    this.id,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'language': language,
    'category': category.name,
    'components': components.map((c) => c.toJson()).toList(),
  };

  factory WhatsAppTemplate.fromJson(Map<String, dynamic> json) {
    return WhatsAppTemplate(
      name: json['name'],
      language: json['language'],
      category: WhatsAppTemplateCategory.values.byName(json['category']),
      components: (json['components'] as List)
          .map((c) => WhatsAppTemplateComponent.fromJson(c))
          .toList(),
      status: json['status'],
      id: json['id'],
    );
  }
}

enum WhatsAppTemplateCategory {
  marketing,
  utility,
  authentication,
}

class WhatsAppTemplateComponent {
  final WhatsAppComponentType type;
  final Map<String, dynamic> content;

  const WhatsAppTemplateComponent({
    required this.type,
    required this.content,
  });

  Map<String, dynamic> toJson() => {
    'type': type.name,
    ...content,
  };

  factory WhatsAppTemplateComponent.fromJson(Map<String, dynamic> json) {
    return WhatsAppTemplateComponent(
      type: WhatsAppComponentType.values.byName(json['type']),
      content: Map<String, dynamic>.from(json)
        ..remove('type'),
    );
  }
}

enum WhatsAppComponentType {
  header,
  body,
  footer,
  buttons,
}

/// Template button
class WhatsAppTemplateButton {
  final String type; // 'quick_reply', 'url', 'phone_number', 'copy_code', 'catalog', 'mpm'
  final String text;
  final String? url;
  final String? phoneNumber;
  final String? payload;
  final String? example;

  const WhatsAppTemplateButton({
    required this.type,
    required this.text,
    this.url,
    this.phoneNumber,
    this.payload,
    this.example,
  });

  Map<String, dynamic> toJson() {
    final json = {'type': type, 'text': text};
    if (url != null) json['url'] = url;
    if (phoneNumber != null) json['phone_number'] = phoneNumber;
    if (payload != null) json['payload'] = payload;
    if (example != null) json['example'] = example;
    return json;
  }
}

/// Réponse d'envoi de message
class WhatsAppSendResult {
  final bool success;
  final String? messageId;
  final String? error;
  final int? statusCode;

  const WhatsAppSendResult({
    required this.success,
    this.messageId,
    this.error,
    this.statusCode,
  });
}

/// Service WhatsApp Business API
class WhatsAppService {
  final WhatsAppConfig _config;
  final http.Client _httpClient;
  
  // Cache des templates
  final Map<String, WhatsAppTemplate> _templateCache = {};
  DateTime? _templatesLastFetched;

  WhatsAppService(this._config) : _httpClient = http.Client();

  /// Headers communs
  Map<String, String> get _headers => {
    'Authorization': 'Bearer ${_config.accessToken}',
    'Content-Type': 'application/json',
  };

  /// Envoie un message texte simple
  Future<WhatsAppSendResult> sendTextMessage({
    required String to,
    required String body,
    String? contextMessageId,
  }) async {
    final message = WhatsAppMessage(
      to: _normalizePhoneNumber(to),
      type: WhatsAppMessageType.text,
      content: body,
      contextMessageId: contextMessageId,
    );
    return _sendMessage(message);
  }

  /// Envoie un message template
  Future<WhatsAppSendResult> sendTemplateMessage({
    required String to,
    required String templateName,
    required String languageCode,
    required List<dynamic> components, // paramètres du template
  }) async {
    final message = WhatsAppMessage(
      to: _normalizePhoneNumber(to),
      type: WhatsAppMessageType.template,
      content: {
        'name': templateName,
        'language': {'code': languageCode},
        'components': components,
      },
    );
    return _sendMessage(message);
  }

  /// Envoie un message média (image, document, vidéo, audio)
  Future<WhatsAppSendResult> sendMediaMessage({
    required String to,
    required WhatsAppMessageType type,
    required String mediaId,
    String? caption,
    String? filename,
  }) async {
    final content = <String, dynamic>{'id': mediaId};
    if (caption != null) content['caption'] = caption;
    if (filename != null) content['filename'] = filename;

    final message = WhatsAppMessage(
      to: _normalizePhoneNumber(to),
      type: type,
      content: content,
    );
    return _sendMessage(message);
  }

  /// Envoie un message interactif (boutons, liste)
  Future<WhatsAppSendResult> sendInteractiveMessage({
    required String to,
    required String headerText,
    required String bodyText,
    required String footerText,
    required List<WhatsAppInteractiveButton> buttons,
  }) async {
    final message = WhatsAppMessage(
      to: _normalizePhoneNumber(to),
      type: WhatsAppMessageType.interactive,
      content: {
        'type': 'button',
        'header': {'type': 'text', 'text': headerText},
        'body': {'text': bodyText},
        'footer': {'text': footerText},
        'action': {
          'buttons': buttons.map((b) => b.toJson()).toList(),
        },
      },
    );
    return _sendMessage(message);
  }

  /// Envoie une liste interactive
  Future<WhatsAppSendResult> sendListMessage({
    required String to,
    required String headerText,
    required String bodyText,
    required String footerText,
    required String buttonText,
    required List<WhatsAppListSection> sections,
  }) async {
    final message = WhatsAppMessage(
      to: _normalizePhoneNumber(to),
      type: WhatsAppMessageType.interactive,
      content: {
        'type': 'list',
        'header': {'type': 'text', 'text': headerText},
        'body': {'text': bodyText},
        'footer': {'text': footerText},
        'action': {
          'button': buttonText,
          'sections': sections.map((s) => s.toJson()).toList(),
        },
      },
    );
    return _sendMessage(message);
  }

  /// Envoie une réaction à un message
  Future<WhatsAppSendResult> sendReaction({
    required String to,
    required String messageId,
    required String emoji,
  }) async {
    final message = WhatsAppMessage(
      to: _normalizePhoneNumber(to),
      type: WhatsAppMessageType.reaction,
      content: {
        'message_id': messageId,
        'emoji': emoji,
      },
    );
    return _sendMessage(message);
  }

  /// Marque un message comme lu
  Future<WhatsAppSendResult> markAsRead(String messageId) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('${_config.baseUrl}/messages'),
        headers: _headers,
        body: jsonEncode({
          'messaging_product': 'whatsapp',
          'status': 'read',
          'message_id': messageId,
        }),
      );
      return _parseSendResult(response);
    } catch (e) {
      return WhatsAppSendResult(success: false, error: e.toString());
    }
  }

  /// Envoie bas niveau
  Future<WhatsAppSendResult> _sendMessage(WhatsAppMessage message) async {
    try {
      final response = await _httpClient.post(
        Uri.parse(_config.messagesUrl),
        headers: _headers,
        body: jsonEncode(message.toJson()),
      );
      return _parseSendResult(response);
    } catch (e) {
      return WhatsAppSendResult(success: false, error: e.toString());
    }
  }

  WhatsAppSendResult _parseSendResult(http.Response response) {
    final data = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return WhatsAppSendResult(
        success: true,
        messageId: data['messages']?.first['id'],
        statusCode: response.statusCode,
      );
    }
    return WhatsAppSendResult(
      success: false,
      error: data['error']?['message'] ?? 'Erreur inconnue',
      statusCode: response.statusCode,
    );
  }

  /// Normalise un numéro de téléphone (format international sans +)
  String _normalizePhoneNumber(String phone) {
    var normalized = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (normalized.startsWith('0')) {
      normalized = '212${normalized.substring(1)}'; // Maroc
    } else if (!normalized.startsWith('212')) {
      normalized = '212$normalized';
    }
    return normalized;
  }

  // ============ GESTION DES TEMPLATES ============

  /// Récupère tous les templates
  Future<List<WhatsAppTemplate>> getTemplates({bool forceRefresh = false}) async {
    if (!forceRefresh && 
        _templatesLastFetched != null && 
        DateTime.now().difference(_templatesLastFetched!) < const Duration(hours: 1) &&
        _templateCache.isNotEmpty) {
      return _templateCache.values.toList();
    }

    try {
      final response = await _httpClient.get(
        Uri.parse('${_config.templatesUrl}?fields=name,language,category,components,status,id'),
        headers: _headers,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        final templates = (data['data'] as List?)
            ?.map((t) => WhatsAppTemplate.fromJson(t))
            .toList() ?? [];
        
        _templateCache.clear();
        for (final t in templates) {
          _templateCache[t.name] = t;
        }
        _templatesLastFetched = DateTime.now();
        return templates;
      }
      throw Exception('Erreur récupération templates: ${response.body}');
    } catch (e) {
      throw Exception('Erreur templates: $e');
    }
  }

  /// Crée un nouveau template
  Future<WhatsAppTemplate> createTemplate(WhatsAppTemplate template) async {
    final response = await _httpClient.post(
      Uri.parse(_config.templatesUrl),
      headers: _headers,
      body: jsonEncode(template.toJson()),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body);
      final template = WhatsAppTemplate.fromJson({...jsonDecode(jsonEncode(template.toJson())), 'id': data['id']});
      _templateCache[template.name] = template;
      return template;
    }
    throw Exception('Erreur création template: ${response.body}');
  }

  /// Supprime un template
  Future<bool> deleteTemplate(String templateName) async {
    final template = _templateCache[templateName];
    if (template == null || template.id == null) return false;

    final response = await _httpClient.delete(
      Uri.parse('${_config.templatesUrl}/${template.id}'),
      headers: _headers,
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      _templateCache.remove(templateName);
      return true;
    }
    return false;
  }

  // ============ WEBHOOK ============

  /// Vérifie la signature du webhook (sécurité)
  bool verifyWebhookSignature(String payload, String signature) {
    // Implémentation HMAC SHA256 avec l'app secret
    // Pour l'instant, on retourne true (à implémenter avec crypto)
    return true;
  }

  /// Traite un webhook entrant
  Future<WhatsAppWebhookEvent?> processWebhook(Map<String, dynamic> body) async {
    try {
      final entry = body['entry']?.first;
      final changes = entry?['changes']?.first;
      final value = changes?['value'];
      
      if (value == null) return null;

      // Messages reçus
      final messages = value['messages'] as List?;
      if (messages != null && messages.isNotEmpty) {
        return WhatsAppWebhookEvent(
          type: WhatsAppWebhookEventType.message,
          messages: messages.map((m) => WhatsAppIncomingMessage.fromJson(m)).toList(),
          contacts: (value['contacts'] as List?)
              ?.map((c) => WhatsAppContact.fromJson(c))
              .toList(),
        );
      }

      // Statuts de message
      final statuses = value['statuses'] as List?;
      if (statuses != null && statuses.isNotEmpty) {
        return WhatsAppWebhookEvent(
          type: WhatsAppWebhookEventType.status,
          statuses: statuses.map((s) => WhatsAppStatus.fromJson(s)).toList(),
        );
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Récupère un media (image, document, etc.)
  Future<WhatsAppMedia?> getMedia(String mediaId) async {
    try {
      final response = await _httpClient.get(
        Uri.parse('${_config.mediaUrl}/$mediaId'),
        headers: _headers,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return WhatsAppMedia.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Télécharge le contenu d'un media
  Future<Uint8List?> downloadMedia(String mediaUrl) async {
    try {
      final response = await _httpClient.get(
        Uri.parse(mediaUrl),
        headers: {'Authorization': 'Bearer ${_config.accessToken}'},
      );
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  void dispose() {
    _httpClient.close();
  }
}

// ============ MODÈLES WEBHOOK ============

enum WhatsAppWebhookEventType {
  message,
  status,
}

class WhatsAppWebhookEvent {
  final WhatsAppWebhookEventType type;
  final List<WhatsAppIncomingMessage>? messages;
  final List<WhatsAppStatus>? statuses;
  final List<WhatsAppContact>? contacts;

  const WhatsAppWebhookEvent({
    required this.type,
    this.messages,
    this.statuses,
    this.contacts,
  });
}

class WhatsAppIncomingMessage {
  final String id;
  final String from;
  final DateTime timestamp;
  final WhatsAppMessageType type;
  final dynamic content; // Selon le type
  final Map<String, dynamic>? context;
  final WhatsAppContact? contact;

  const WhatsAppIncomingMessage({
    required this.id,
    required this.from,
    required this.timestamp,
    required this.type,
    required this.content,
    this.context,
    this.contact,
  });

  factory WhatsAppIncomingMessage.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String;
    final type = WhatsAppMessageType.values.byName(typeStr);
    
    dynamic content;
    switch (type) {
      case WhatsAppMessageType.text:
        content = json['text']['body'];
        break;
      case WhatsAppMessageType.image:
      case WhatsAppMessageType.document:
      case WhatsAppMessageType.video:
      case WhatsAppMessageType.audio:
      case WhatsAppMessageType.sticker:
        content = WhatsAppMedia.fromJson(json[typeStr]);
        break;
      case WhatsAppMessageType.location:
        content = json['location'];
        break;
      case WhatsAppMessageType.contacts:
        content = (json['contacts'] as List)
            .map((c) => WhatsAppContact.fromJson(c))
            .toList();
        break;
      case WhatsAppMessageType.interactive:
        content = json['interactive'];
        break;
      case WhatsAppMessageType.reaction:
        content = json['reaction'];
        break;
      default:
        content = json[typeStr];
    }

    return WhatsAppIncomingMessage(
      id: json['id'],
      from: json['from'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(int.parse(json['timestamp']) * 1000),
      type: type,
      content: content,
      context: json['context'],
      contact: json['contact'] != null ? WhatsAppContact.fromJson(json['contact']) : null,
    );
  }
}

class WhatsAppContact {
  final String waId;
  final String? name;
  final String? phone;

  const WhatsAppContact({
    required this.waId,
    this.name,
    this.phone,
  });

  factory WhatsAppContact.fromJson(Map<String, dynamic> json) {
    return WhatsAppContact(
      waId: json['wa_id'],
      name: json['profile']?['name'],
      phone: json['phone'],
    );
  }
}

class WhatsAppStatus {
  final String id;
  final String status; // sent, delivered, read, failed
  final DateTime timestamp;
  final String? recipientId;
  final String? conversationId;
  final String? errorCode;
  final String? errorTitle;
  final String? errorMessage;

  const WhatsAppStatus({
    required this.id,
    required this.status,
    required this.timestamp,
    this.recipientId,
    this.conversationId,
    this.errorCode,
    this.errorTitle,
    this.errorMessage,
  });

  factory WhatsAppStatus.fromJson(Map<String, dynamic> json) {
    return WhatsAppStatus(
      id: json['id'],
      status: json['status'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(int.parse(json['timestamp']) * 1000),
      recipientId: json['recipient_id'],
      conversationId: json['conversation']?['id'],
      errorCode: json['errors']?.first?['code'],
      errorTitle: json['errors']?.first?['title'],
      errorMessage: json['errors']?.first?['message'],
    );
  }
}

class WhatsAppMedia {
  final String id;
  final String mimeType;
  final String? sha256;
  final int? fileSize;
  final String? filename;
  final String url;

  const WhatsAppMedia({
    required this.id,
    required this.mimeType,
    this.sha256,
    this.fileSize,
    this.filename,
    required this.url,
  });

  factory WhatsAppMedia.fromJson(Map<String, dynamic> json) {
    return WhatsAppMedia(
      id: json['id'],
      mimeType: json['mime_type'],
      sha256: json['sha256'],
      fileSize: (json['file_size'] as num?)?.toInt(),
      filename: json['filename'],
      url: json['url'],
    );
  }
}

// Bouton interactif
class WhatsAppInteractiveButton {
  final String type; // 'reply', 'url', 'call', 'copy_code'
  final String title;
  final String? url;
  final String? phoneNumber;
  final String? payload;

  const WhatsAppInteractiveButton({
    required this.type,
    required this.title,
    this.url,
    this.phoneNumber,
    this.payload,
  });

  Map<String, dynamic> toJson() {
    final json = {'type': type, 'title': title};
    if (url != null) json['url'] = url;
    if (phoneNumber != null) json['phone_number'] = phoneNumber;
    if (payload != null) json['payload'] = payload;
    return json;
  }
}

// Section de liste
class WhatsAppListSection {
  final String title;
  final List<WhatsAppListRow> rows;

  const WhatsAppListSection({
    required this.title,
    required this.rows,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'rows': rows.map((r) => r.toJson()).toList(),
  };
}

class WhatsAppListRow {
  final String id;
  final String title;
  final String? description;

  const WhatsAppListRow({
    required this.id,
    required this.title,
    this.description,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    if (description != null) 'description': description,
  };
}