import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/services/api_client.dart';
import '../../core/services/auth_store.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/status_chip.dart';

/// Site web & blog : paramètres publics et articles.
class WebsitePage extends StatefulWidget {
  const WebsitePage({super.key});

  @override
  State<WebsitePage> createState() => _WebsitePageState();
}

class _WebsitePageState extends State<WebsitePage> {
  bool _loading = true;
  String? _error;

  final _heroTitle = TextEditingController();
  final _heroSubtitle = TextEditingController();
  final _about = TextEditingController();
  List<Map<String, dynamic>> _posts = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _heroTitle.dispose();
    _heroSubtitle.dispose();
    _about.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final results = await Future.wait([
      ApiClient.instance.get<Map<String, dynamic>>('/website/settings'),
      ApiClient.instance
          .get<List<dynamic>>('/website/blog/posts', query: {'limit': '100'}),
    ]);
    if (!mounted) return;
    if (!results[0].success) {
      setState(() {
        _loading = false;
        _error = results[0].error?.message;
      });
      return;
    }
    setState(() {
      final s =
          results[0].data as Map<String, dynamic>? ?? const <String, dynamic>{};
      _heroTitle.text = '${s['hero_title'] ?? ''}';
      _heroSubtitle.text = '${s['hero_subtitle'] ?? ''}';
      _about.text = '${s['about'] ?? ''}';
      _posts = (results[1].data as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      _loading = false;
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _saving = true);
    await ApiClient.instance.put('/website/settings', body: {
      'heroTitle':
          _heroTitle.text.trim().isEmpty ? null : _heroTitle.text.trim(),
      'heroSubtitle':
          _heroSubtitle.text.trim().isEmpty ? null : _heroSubtitle.text.trim(),
      'about': _about.text.trim().isEmpty ? null : _about.text.trim(),
    });
    if (!mounted) return;
    setState(() => _saving = false);
  }

  Future<void> _createPost() async {
    final locale = context.read<AuthStore>().locale;
    final title = TextEditingController();
    final excerpt = TextEditingController();
    final content = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.t('newPost', locale)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: title,
                decoration:
                    InputDecoration(labelText: S.t('postTitle', locale))),
            const SizedBox(height: 12),
            TextField(
                controller: excerpt,
                maxLines: 2,
                decoration:
                    InputDecoration(labelText: S.t('postExcerpt', locale))),
            const SizedBox(height: 12),
            TextField(
                controller: content,
                maxLines: 4,
                decoration:
                    InputDecoration(labelText: S.t('postContent', locale))),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(S.t('cancel', locale))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(S.t('save', locale))),
        ],
      ),
    );
    if (ok != true ||
        title.text.trim().isEmpty ||
        content.text.trim().isEmpty) {
      return;
    }
    await ApiClient.instance.post('/website/blog/posts', body: {
      'title': title.text.trim(),
      'excerpt': excerpt.text.trim().isEmpty ? null : excerpt.text.trim(),
      'content': content.text.trim(),
      'isPublished': true,
    });
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    return Scaffold(
      appBar: AppBar(
        title: Text(S.t('website', locale)),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    GlassCard(
                      radius: BorderRadius.circular(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(S.t('websiteSettings', locale),
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 12),
                          TextField(
                              controller: _heroTitle,
                              decoration: InputDecoration(
                                  labelText: S.t('heroTitle', locale))),
                          const SizedBox(height: 12),
                          TextField(
                              controller: _heroSubtitle,
                              maxLines: 2,
                              decoration: InputDecoration(
                                  labelText: S.t('heroSubtitle', locale))),
                          const SizedBox(height: 12),
                          TextField(
                              controller: _about,
                              maxLines: 4,
                              decoration: InputDecoration(
                                  labelText: S.t('about', locale))),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _saving ? null : _saveSettings,
                              icon: const Icon(Icons.save_outlined),
                              label: Text(S.t('save', locale)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                              '${S.t('posts', locale)} (${_posts.length})',
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w800)),
                        ),
                        FilledButton.icon(
                          onPressed: _createPost,
                          icon: const Icon(Icons.add),
                          label: Text(S.t('newPost', locale)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_posts.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(S.t('noPosts', locale)),
                        ),
                      )
                    else
                      ..._posts.map((p) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GlassCard(
                              radius: BorderRadius.circular(16),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('${p['title']}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w800)),
                                        Text(
                                            '${Fmt.shortDate(DateTime.tryParse('${p['created_at']}'))}'
                                            ' · ${p['is_published'] == true ? S.t('published', locale) : S.t('draft', locale)}',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                  StatusChip(
                                    label: p['is_published'] == true
                                        ? S.t('published', locale)
                                        : S.t('draft', locale),
                                    color: p['is_published'] == true
                                        ? const Color(0xFF2E7D32)
                                        : Colors.grey,
                                  ),
                                ],
                              ),
                            ),
                          )),
                  ],
                ),
    );
  }
}
