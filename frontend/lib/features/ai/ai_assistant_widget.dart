/// ============================================================
/// AI ASSISTANT WIDGET (moved from ai_engine.dart)
/// ============================================================
// library ai_assistant_widget;

import 'package:flutter/material.dart';

import '../../core/services/ai_engine.dart';
import '../../core/theme/colors.dart';

class AIAssistantWidget extends StatefulWidget {
  final AIContext context;
  const AIAssistantWidget({super.key, required this.context});

  @override
  State<AIAssistantWidget> createState() => _AIAssistantWidgetState();
}

class _AIAssistantWidgetState extends State<AIAssistantWidget> {
  late final PharmaAIAssistant _assistant;
  final _controller = TextEditingController();
  final _messages = <AIMessage>[];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _assistant = PharmaAIAssistant(widget.context);
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
    return Column(children: [
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
              hintText: 'Posez votre question...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          )),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _sending ? null : _send,
            icon: _sending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
          ),
        ]),
      ),
    ]);
  }
}