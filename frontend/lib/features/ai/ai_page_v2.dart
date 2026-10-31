import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/services/ai_engine.dart';
import '../../core/services/auth_store.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/glass_card.dart';

/// Page IA — Assistant intelligent PHARMA+
class AIPageV2 extends StatefulWidget {
  const AIPageV2({super.key});

  @override
  State<AIPageV2> createState() => _AIPageV2State();
}

class _AIPageV2State extends State<AIPageV2> {
  late final PharmaAIAssistant _assistant;
  final _controller = TextEditingController();
  final _messages = <AIMessage>[];
  bool _sending = false;
  AIContext? _context;

  @override
  void initState() {
    super.initState();
    final auth = AuthStore.instance;
    _context = AIContext(
      pharmacyId: auth.user?.pharmacyId ?? '',
      userId: auth.user?.id ?? '',
      permissions: auth.permissions,
      locale: auth.locale,
    );
    _assistant = PharmaAIAssistant(_context!);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    
    setState(() {
      _messages.add(AIMessage(role: 'user', content: text));
      _sending = true;
      _controller.clear();
    });

    final response = await _assistant.ask(text);
    
    if (mounted) {
      setState(() {
        _messages.add(AIMessage(role: 'assistant', content: response.text));
        _sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AuthStore>().locale;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: const ShellBackButton(),
        title: Text(S.t('pharmaAi', locale)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () => setState(() => _messages.clear()),
            tooltip: 'Effacer la conversation',
          ),
        ],
      ),
      body: Column(children: [
        Expanded(child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _messages.length,
          itemBuilder: (_, i) {
            final m = _messages[i];
            return Align(
              alignment: m.role == 'user' ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: m.role == 'user' ? AppColors.pharmaGold : AppColors.pharmaSurface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(m.content, style: TextStyle(
                  color: m.role == 'user' ? Colors.black : Colors.white,
                )),
              ),
            );
          },
        )),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(child: TextField(
              controller: _controller,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: S.t('aiAssistant', locale),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            )),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _sending ? null : _send,
              icon: _sending 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
            ),
          ]),
        ),
      ]),
    );
  }
}