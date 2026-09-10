import 'package:flutter/material.dart';

import '../../../domain/game_save.dart';

/// Conversation with the game master (transcript + input).
Future<void> showGmChatSheet(
  BuildContext context, {
  required List<GmMessage> Function() history,
  required Future<void> Function(String) onSend,
  required bool liveGm,
  required Color accent,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: const Color(0xFF0F172A),
    builder: (ctx) => _GmChat(
        history: history, onSend: onSend, liveGm: liveGm, accent: accent),
  );
}

class _GmChat extends StatefulWidget {
  const _GmChat({
    required this.history,
    required this.onSend,
    required this.liveGm,
    required this.accent,
  });

  final List<GmMessage> Function() history;
  final Future<void> Function(String) onSend;
  final bool liveGm;
  final Color accent;

  @override
  State<_GmChat> createState() => _GmChatState();
}

class _GmChatState extends State<_GmChat> {
  final _c = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _c.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = _c.text.trim();
    if (t.isEmpty || _sending) return;
    _c.clear();
    setState(() => _sending = true);
    await widget.onSend(t);
    if (!mounted) return;
    setState(() => _sending = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final msgs = widget.history().where((m) => m.role != 'event').toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.record_voice_over, color: widget.accent),
                  const SizedBox(width: 8),
                  Text('Rozmowa z Mistrzem Gry',
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
            if (!widget.liveGm)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  'Mistrz Gry na żywo jest wyłączony (brak klucza API lub opcja w ustawieniach). Odpowiedzi będą ogólne.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.amber),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: msgs.length,
                itemBuilder: (_, i) {
                  final m = msgs[i];
                  final me = m.role == 'player';
                  return Align(
                    alignment: me ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      constraints: const BoxConstraints(maxWidth: 300),
                      decoration: BoxDecoration(
                        color: me
                            ? widget.accent.withValues(alpha: 0.2)
                            : const Color(0xFF1B2638),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(m.text),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _c,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                          hintText: 'Zapytaj Mistrza Gry…'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
