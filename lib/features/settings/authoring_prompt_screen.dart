import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/platform/native_share.dart';

/// Shows the copy-paste prompt for external AI chats and the format reference.
class AuthoringPromptScreen extends StatelessWidget {
  const AuthoringPromptScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Scenariusz z innego AI'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Prompt do wklejenia'),
            Tab(text: 'Opis formatu'),
          ]),
        ),
        body: const TabBarView(children: [
          _AssetText(
            asset: 'assets/docs/AI_AUTHORING_PROMPT.md',
            intro:
                'Skopiuj poniższy tekst, uzupełnij PARAMETRY i wklej w dowolnym czacie AI (ChatGPT, Claude, Gemini…). Otrzymany plik Markdown zaimportuj w „Nowa gra → Import scenariusza” (plik albo wklejony tekst).',
            shareSubject: 'Prompt: scenariusz escape room',
          ),
          _AssetText(
            asset: 'assets/docs/SCENARIO_FORMAT.md',
            intro: 'Pełny opis formatu escape-room-scenario/1 (Markdown i JSON).',
            shareSubject: 'Format scenariusza escape room',
          ),
        ]),
      ),
    );
  }
}

class _AssetText extends StatelessWidget {
  const _AssetText({
    required this.asset,
    required this.intro,
    required this.shareSubject,
  });

  final String asset;
  final String intro;
  final String shareSubject;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: DefaultAssetBundle.of(context).loadString(asset),
      builder: (context, snap) {
        final text = snap.data;
        if (text == null) return const Center(child: CircularProgressIndicator());
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(intro, style: const TextStyle(color: Colors.white70)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: text));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Skopiowano do schowka.')));
                        }
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Kopiuj'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final ok = await NativeShare.text(text, subject: shareSubject);
                        if (!ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('Udostępnianie niedostępne – użyj „Kopiuj”.')));
                        }
                      },
                      icon: const Icon(Icons.share),
                      label: const Text('Udostępnij'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  text,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5, height: 1.4),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
