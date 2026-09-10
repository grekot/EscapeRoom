import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../domain/game_spec.dart';
import 'chroma_key.dart';
import '../ai_errors.dart';
import '../image_generator.dart';

/// Common style suffix so every illustration in a game looks consistent.
const illustrationStyle =
    'Digital storybook illustration for a family escape-room game, wide '
    'establishing shot of the room, soft painterly shading, rich atmospheric '
    'lighting, slightly stylized proportions, cozy but mysterious mood. '
    'No people, no text, no letters, no numbers, no signs, no UI elements. '
    'Leave clean wall/floor surfaces where devices could sit.';

/// Suffix for sprite generation: flat key colour so the app can cut it out.
const spriteStyle =
    'A single game prop sprite, centred, fully visible, painterly storybook '
    'style with soft shading, isolated on a completely flat, solid, uniform '
    'pure magenta background (#FF00FF). No shadow on the background, no text, '
    'no other objects, no frame.';

class ArtistResult {
  const ArtistResult(this.spec, this.failures);
  final GameSpec spec;

  /// Stage titles whose image could not be generated, with the reason.
  final Map<String, String> failures;
}

/// Generates one illustration per stage and stores it under
/// `<documents>/images/<gameId>/<stageId>.png`.
class SceneArtist {
  SceneArtist(this.generator, {Directory? root}) : _root = root;

  final ImageGenerator generator;
  final Directory? _root;

  Future<Directory> _dir(String gameId) async {
    final base = _root ?? await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}${Platform.pathSeparator}images${Platform.pathSeparator}$gameId');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<ArtistResult> illustrate(
    GameSpec spec, {
    void Function(String status)? onStatus,
    bool force = false,
  }) async {
    final dir = await _dir(spec.id);
    final stages = <GameStage>[];
    final failures = <String, String>{};
    for (var i = 0; i < spec.stages.length; i++) {
      final st = spec.stages[i];
      final scene = st.scene;
      final hasScene = (scene.imagePath != null && File(scene.imagePath!).existsSync()) ||
          scene.imageAsset != null;
      if (!force && hasScene) {
        final props = await _sprites(st, dir, onStatus, failures, force: force);
        stages.add(st.copyWith(scene: scene.copyWith(props: props)));
        continue;
      }
      final prompt = scene.imagePrompt.trim().isEmpty
          ? 'Interior of a ${scene.backdrop.replaceAll('_', ' ')} for the scene "${st.title}".'
          : scene.imagePrompt.trim();
      onStatus?.call('Maluję scenę ${i + 1}/${spec.stages.length}: ${st.title}…');
      try {
        final bytes = await generator.generate('$prompt\n\n$illustrationStyle');
        final f = File('${dir.path}${Platform.pathSeparator}${_safe(st.id)}.png');
        await f.writeAsBytes(bytes, flush: true);
        final props = await _sprites(st, dir, onStatus, failures, force: force);
        stages.add(st.copyWith(scene: scene.copyWith(imagePath: f.path, props: props)));
      } on AiException catch (e) {
        failures[st.title] = e.userMessage;
        stages.add(st);
        if (e.kind == AiErrorKind.noApiKey || e.kind == AiErrorKind.unauthorized) {
          // No point trying the remaining stages.
          stages.addAll(spec.stages.skip(i + 1));
          break;
        }
      } catch (e) {
        failures[st.title] = e.toString();
        stages.add(st);
      }
    }
    return ArtistResult(spec.copyWith(stages: stages), failures);
  }

  /// Generates cut-out sprites for `custom` props that lack one.
  Future<List<SceneProp>> _sprites(
    GameStage st,
    Directory dir,
    void Function(String status)? onStatus,
    Map<String, String> failures, {
    required bool force,
  }) async {
    final out = <SceneProp>[];
    for (var k = 0; k < st.scene.props.length; k++) {
      final p = st.scene.props[k];
      final has = (p.spritePath != null && File(p.spritePath!).existsSync()) ||
          p.spriteAsset != null;
      if (!p.isCustom || (p.spritePrompt ?? '').trim().isEmpty || (has && !force)) {
        out.add(p);
        continue;
      }
      onStatus?.call('Rysuję rekwizyt: ${p.label ?? p.spritePrompt}…');
      try {
        final raw = await generator.generate('${p.spritePrompt!.trim()}\n\n$spriteStyle',
            aspectRatio: '1:1');
        final cut = ChromaKey.cutOut(raw);
        final f = File('${dir.path}${Platform.pathSeparator}${_safe(st.id)}_prop$k.png');
        await f.writeAsBytes(cut, flush: true);
        out.add(p.copyWith(spritePath: f.path));
      } on AiException catch (e) {
        failures['${st.title} / rekwizyt'] = e.userMessage;
        out.add(p);
      } catch (e) {
        failures['${st.title} / rekwizyt'] = e.toString();
        out.add(p);
      }
    }
    return out;
  }

  static String _safe(String id) => id.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');

  /// Deletes generated images of a game.
  Future<void> deleteImages(String gameId) async {
    final base = _root ?? await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}${Platform.pathSeparator}images${Platform.pathSeparator}$gameId');
    if (await d.exists()) await d.delete(recursive: true);
  }
}
