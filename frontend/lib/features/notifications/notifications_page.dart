import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/services/api_client.dart';
import '../../core/services/auth_store.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/glass_card.dart';

/// Boîte de réception des alertes et messages attribués à l'utilisateur.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _markingAll = false;
  String? _error;

  int get _unreadCount =>
      _items.where((item) => item['read_at'] == null).length;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ApiClient.instance
        .get<Map<String, dynamic>>('/notifications', query: {'limit': 100});
    if (!mounted) return;
    if (!result.success) {
      setState(() {
        _loading = false;
        _error = result.error?.message;
      });
      return;
    }
    setState(() {
      _items = (result.data?['items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      _loading = false;
    });
  }

  Future<void> _markRead(Map<String, dynamic> item) async {
    if (item['read_at'] != null) return;
    final id = item['id'] as String?;
    if (id == null) return;
    setState(() => item['read_at'] = DateTime.now().toIso8601String());
    final result = await ApiClient.instance.post('/notifications/$id/read');
    if (!result.success && mounted) {
      setState(() => item['read_at'] = null);
    }
  }

  Future<void> _markAllRead() async {
    if (_markingAll || _unreadCount == 0) return;
    setState(() => _markingAll = true);
    final result = await ApiClient.instance.post('/notifications/read-all');
    if (!mounted) return;
    if (result.success) {
      setState(() {
        for (final item in _items) {
          item['read_at'] ??= DateTime.now().toIso8601String();
        }
      });
    }
    setState(() => _markingAll = false);
  }

  IconData _icon(String type) => switch (type) {
        'stock' || 'low_stock' || 'expiring' => Icons.inventory_2_outlined,
        'sale' || 'payment' => Icons.payments_outlined,
        'warning' || 'alert' => Icons.warning_amber_rounded,
        _ => Icons.notifications_outlined,
      };

  Color _color(String type) => switch (type) {
        'warning' || 'alert' || 'low_stock' => AppColors.warning,
        'expiring' => AppColors.danger,
        'sale' || 'payment' => AppColors.success,
        _ => AppColors.info,
      };

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    return Scaffold(
      appBar: AppBar(
        title: Text(S.t('notifications', locale)),
        actions: [
          if (_unreadCount > 0)
            TextButton.icon(
              onPressed: _markingAll ? null : _markAllRead,
              icon: _markingAll
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.done_all),
              label: Text(S.t('markAllRead', locale)),
            ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _items.isEmpty
                  ? Center(child: Text(S.t('noNotifications', locale)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final unread = item['read_at'] == null;
                          final type = '${item['type'] ?? 'system'}';
                          final color = _color(type);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GlassCard(
                              radius: BorderRadius.circular(16),
                              padding: const EdgeInsets.all(12),
                              onTap: () => _markRead(item),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(_icon(type), color: color),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('${item['title'] ?? '—'}',
                                            style: TextStyle(
                                              fontWeight: unread
                                                  ? FontWeight.w800
                                                  : FontWeight.w600,
                                            )),
                                        if (item['message'] != null) ...[
                                          const SizedBox(height: 2),
                                          Text('${item['message']}',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey)),
                                        ],
                                        const SizedBox(height: 5),
                                        Text(
                                            Fmt.dateTime(DateTime.tryParse(
                                                '${item['created_at']}')),
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                  if (unread)
                                    Container(
                                      width: 9,
                                      height: 9,
                                      margin: const EdgeInsets.only(top: 5),
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
