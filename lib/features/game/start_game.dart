import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/game_save.dart';
import '../../domain/game_spec.dart';

/// Creates a fresh save for [spec] and returns its id.
Future<String> startGame(WidgetRef ref, GameSpec spec) async {
  final save = GameSave.start(
    id: newId(),
    gameSpecId: spec.id,
    stageCount: spec.stages.length,
  );
  await ref.read(saveRepoProvider).save(save);
  ref.invalidate(libraryProvider);
  return save.id;
}
