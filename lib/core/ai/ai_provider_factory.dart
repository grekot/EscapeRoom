import '../storage/settings_repository.dart';
import 'ai_provider.dart';
import 'anthropic_provider.dart';
import 'gemini_provider.dart';

/// Builds the active provider from settings + stored keys.
/// Returns null when the active vendor has no key.
AiProvider? buildAiProvider(Settings s,
    {required String anthropicKey, required String geminiKey}) {
  switch (s.vendor) {
    case AiVendor.anthropic:
      if (anthropicKey.trim().isEmpty) return null;
      return AnthropicProvider(apiKey: anthropicKey, model: s.anthropicModel);
    case AiVendor.gemini:
      if (geminiKey.trim().isEmpty) return null;
      return GeminiProvider(apiKey: geminiKey, model: s.geminiModel);
  }
}
