import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/create/create_screen.dart';
import '../features/create/generation_screen.dart';
import '../features/create/scenario_preview_screen.dart';
import '../features/game/game_screen.dart';
import '../features/game/victory_screen.dart';
import '../features/library/library_screen.dart';
import '../features/settings/authoring_prompt_screen.dart';
import '../features/settings/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const LibraryScreen()),
      GoRoute(path: '/create', builder: (_, _) => const CreateScreen()),
      GoRoute(
        path: '/generating',
        builder: (_, state) =>
            GenerationScreen(job: state.extra as GenerationJob),
      ),
      GoRoute(
        path: '/scenario/:id',
        builder: (_, state) =>
            ScenarioPreviewScreen(scenarioId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/game/:saveId',
        builder: (_, state) =>
            GameScreen(saveId: state.pathParameters['saveId']!),
      ),
      GoRoute(
        path: '/victory/:saveId',
        builder: (_, state) =>
            VictoryScreen(saveId: state.pathParameters['saveId']!),
      ),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(
          path: '/settings/authoring',
          builder: (_, _) => const AuthoringPromptScreen()),
    ],
  );
});
