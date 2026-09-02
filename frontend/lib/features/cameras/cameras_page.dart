import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/services/api_client.dart';
import '../../core/services/auth_store.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/glass_card.dart';

class CamerasPage extends StatefulWidget {
  const CamerasPage({super.key});

  @override
  State<CamerasPage> createState() => _CamerasPageState();
}

class _CamerasPageState extends State<CamerasPage> {
  List<dynamic> _cameras = [];
  bool _loading = true;
  String? _error;
  String? _busyId;

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
    final result =
        await ApiClient.instance.get<List<dynamic>>('/cameras');
    if (!mounted) return;
    if (!result.success) {
      setState(() {
        _loading = false;
        _error = result.error?.readableMessage ?? 'Erreur';
      });
      return;
    }
    setState(() {
      _cameras = result.data ?? [];
      _loading = false;
    });
  }

  Future<void> _toggleRecording(dynamic camera) async {
    setState(() => _busyId = '${camera['id']}');
    final isRecording = camera['status'] == 'recording';
    final result = await ApiClient.instance.post<Map<String, dynamic>>(
        '/cameras/${camera['id']}/recordings/${isRecording ? 'stop' : 'start'}');
    if (!mounted) return;
    if (result.success) {
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error?.readableMessage ?? 'Erreur')));
    }
    setState(() => _busyId = null);
  }

  Future<void> _addCamera() async {
    final name = TextEditingController();
    final location = TextEditingController();
    final streamUrl = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        final locale = context.watch<AuthStore>().locale;
        return AlertDialog(
          title: Text(S.t('addCamera', locale)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration:
                    InputDecoration(labelText: S.t('cameraName', locale)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: location,
                decoration:
                    InputDecoration(labelText: S.t('cameraLocation', locale)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: streamUrl,
                decoration:
                    InputDecoration(labelText: S.t('cameraStream', locale)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(S.t('cancel', locale)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(S.t('save', locale)),
            ),
          ],
        );
      },
    );
    if (saved != true) return;
    final body = <String, dynamic>{
      'name': name.text.trim(),
      'location': location.text.trim(),
      'stream_url': streamUrl.text.trim().isEmpty
          ? null
          : streamUrl.text.trim(),
    };
    if (body['name'] == null || (body['name'] as String).isEmpty) return;
    final result = await ApiClient.instance
        .post<Map<String, dynamic>>('/cameras', body: body);
    if (!mounted) return;
    if (result.success) {
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error?.readableMessage ?? 'Erreur')));
    }
  }

  Future<void> _deleteCamera(dynamic camera) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.t('delete', locale)),
        content: Text('${camera['name']}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(S.t('cancel', locale)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: Text(S.t('delete', locale)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final result =
        await ApiClient.instance.delete<Map<String, dynamic>>(
            '/cameras/${camera['id']}');
    if (!mounted) return;
    if (result.success) {
      await _load();
    }
  }

  String get locale => context.watch<AuthStore>().locale;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.t('cameras', locale)),
        actions: [
          IconButton(
            tooltip: S.t('addCamera', locale),
            onPressed: _addCamera,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_outlined,
                  size: 56, color: AppColors.warning),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: Text(S.t('retry', locale)),
              ),
            ],
          ),
        ),
      );
    }
    if (_cameras.isEmpty) {
      return Center(child: Text(S.t('noCameras', locale)));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: _cameras.length,
        itemBuilder: (context, i) => _CameraCard(
          camera: _cameras[i] as Map<String, dynamic>,
          busy: _busyId == _cameras[i]['id'],
          onToggle: () => _toggleRecording(_cameras[i]),
          onDelete: () => _deleteCamera(_cameras[i]),
        ),
      ),
    );
  }
}

class _CameraCard extends StatelessWidget {
  final Map<String, dynamic> camera;
  final bool busy;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _CameraCard({
    required this.camera,
    required this.busy,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = '${camera['status']}';
    final recording = status == 'recording';
    final online = status == 'online';
    final (Color color, String label) = recording
        ? (AppColors.danger, S.t('cameraRecording', locale))
        : online
            ? (AppColors.success, S.t('cameraOnline', locale))
            : (AppColors.warning, S.t('cameraOffline', locale));

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: recording
                  ? const LinearGradient(colors: [
                      Color(0xFFC62828),
                      Color(0xFF8E0000),
                    ])
                  : online
                      ? AppColors.turquoiseGradient
                      : const LinearGradient(colors: [
                          Color(0xFF455A64),
                          Color(0xFF263238),
                        ]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  recording ? Icons.radio_button_checked : Icons.videocam,
                  color: Colors.white,
                  size: 30,
                ),
                if (recording)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${camera['name']}',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
                if (camera['location'] != null)
                  Text(
                    '${camera['location']}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: recording
                ? S.t('stopRecording', locale)
                : S.t('startRecording', locale),
            onPressed: busy ? null : onToggle,
            icon: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    recording
                        ? Icons.stop_circle_outlined
                        : Icons.fiber_manual_record,
                    color: recording ? AppColors.danger : AppColors.success,
                  ),
          ),
          IconButton(
            tooltip: S.t('delete', locale),
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}
