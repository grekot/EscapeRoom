import 'catalog.dart';
import 'json_utils.dart';
import 'puzzle.dart';

/// An object placed in a scene. Tapping it asks the game master to describe it.
class SceneObject {
  const SceneObject({
    required this.id,
    required this.label,
    required this.icon,
    required this.description,
    this.interactive = true,
    this.x,
    this.y,
    this.clue = '',
    this.requires = '',
    this.lockedText = '',
  });

  final String id;
  final String label;

  /// The concrete finding the player gets by examining the object (numbers,
  /// a rule, a cipher key…) – part of the stage's clue chain. Empty for the
  /// puzzle mechanism itself or a red herring.
  final String clue;

  /// Id of an object that must be examined first (clue chain); empty = none.
  final String requires;

  /// What the player sees while [requires] is not yet examined.
  final String lockedText;

  bool get hasClue => clue.trim().isNotEmpty;
  bool get isChained => requires.trim().isNotEmpty;

  /// Where the object sits on the illustration (0..1), for a tappable marker
  /// when no prop depicts it.
  final double? x;
  final double? y;

  bool get hasHotspot => x != null && y != null;

  /// One of [SceneIcons.all].
  final String icon;

  /// What the game master knows about it (may contain subtle hints).
  final String description;
  final bool interactive;

  factory SceneObject.fromJson(Map<String, dynamic> j, int index) =>
      SceneObject(
        id: jStrOrNull(j, 'id') ?? 'obj_$index',
        label: jStr(j, 'label'),
        icon: SceneIcons.normalize(jStrOrNull(j, 'icon')),
        description: jStr(j, 'description'),
        interactive: jBool(j, 'interactive', fallback: true),
        x: _unitOrNull(j['x']),
        y: _unitOrNull(j['y']),
        clue: jStr(j, 'clue').trim(),
        requires: (jStrOrNull(j, 'requires') ?? '').trim(),
        lockedText: jStr(j, 'lockedText').trim(),
      );

  static double? _unitOrNull(Object? v) {
    final d = v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');
    if (d == null || d < 0) return null;
    final n = d > 1.0 ? d / 100.0 : d;
    return n > 1.0 ? null : n;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'icon': icon,
        'description': description,
        'interactive': interactive,
        'x': x,
        'y': y,
        'clue': clue,
        'requires': requires,
        'lockedText': lockedText,
      };
}

/// An animated prop drawn by the app on top of the scene illustration.
class SceneProp {
  const SceneProp({
    required this.type,
    required this.x,
    required this.y,
    this.size = 0.18,
    this.objectId,
    this.label,
    this.reactsToSuccess = true,
    this.spritePrompt,
    this.spritePath,
    this.spriteAsset,
    this.animation = 'bob',
  });

  /// One of [PropTypes.all] keys. `custom` = AI-generated sprite.
  final String type;

  /// For `custom`: English description of the single object to draw.
  final String? spritePrompt;

  /// Generated sprite (PNG with alpha) on disk / bundled asset.
  final String? spritePath;
  final String? spriteAsset;

  /// One of [PropTypes.animations]; used by `custom` sprites.
  final String animation;

  bool get isCustom => type == 'custom';
  bool get hasSprite => spritePath != null || spriteAsset != null;

  /// Centre of the prop, relative to the scene (0..1).
  final double x;
  final double y;

  /// Width relative to scene width (0.06..0.6).
  final double size;

  /// Tapping the prop inspects this scene object (optional).
  final String? objectId;
  final String? label;

  /// Switch to the "activated" animation once the stage is solved.
  final bool reactsToSuccess;

  factory SceneProp.fromJson(Map<String, dynamic> j) => SceneProp(
        type: PropTypes.normalize(jStrOrNull(j, 'type')),
        x: _unit(j['x'], 0.5),
        y: _unit(j['y'], 0.5),
        size: _unit(j['size'], 0.18).clamp(0.06, 0.6),
        objectId: jStrOrNull(j, 'objectId'),
        label: jStrOrNull(j, 'label'),
        reactsToSuccess: jBool(j, 'reactsToSuccess', fallback: true),
        spritePrompt: jStrOrNull(j, 'spritePrompt'),
        spritePath: jStrOrNull(j, 'spritePath'),
        spriteAsset: jStrOrNull(j, 'spriteAsset'),
        animation: PropTypes.animations.contains(jStr(j, 'animation'))
            ? jStr(j, 'animation')
            : 'bob',
      );

  SceneProp copyWith({String? type, String? spritePath}) => SceneProp(
        type: type ?? this.type,
        x: x,
        y: y,
        size: size,
        objectId: objectId,
        label: label,
        reactsToSuccess: reactsToSuccess,
        spritePrompt: spritePrompt,
        spritePath: spritePath ?? this.spritePath,
        spriteAsset: spriteAsset,
        animation: animation,
      );

  static double _unit(Object? v, double fallback) {
    final d = v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');
    if (d == null) return fallback;
    // Accept percentages by mistake (e.g. 40 instead of 0.4).
    final n = d > 1.0 ? d / 100.0 : d;
    return n.clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'x': x,
        'y': y,
        'size': size,
        'objectId': objectId,
        'label': label,
        'reactsToSuccess': reactsToSuccess,
        'spritePrompt': spritePrompt,
        'spritePath': spritePath,
        'spriteAsset': spriteAsset,
        'animation': animation,
      };
}

class Scene {
  const Scene({
    required this.backdrop,
    required this.ambientColor,
    required this.lighting,
    required this.objects,
    this.props = const [],
    this.imagePrompt = '',
    this.imagePath,
    this.imageAsset,
  });

  /// One of [Backdrops.all]. Used by the procedural backdrop when there is no
  /// illustration.
  final String backdrop;

  /// Hex like `#2b6cb0`. Falls back to theme colour when unparsable.
  final String ambientColor;
  final Lighting lighting;
  final List<SceneObject> objects;

  /// Animated props placed over the illustration.
  final List<SceneProp> props;

  /// Prompt for the AI illustrator (English, no text in image).
  final String imagePrompt;

  /// Generated illustration on disk (app documents dir), if any.
  final String? imagePath;

  /// Bundled illustration (for built-in games), if any.
  final String? imageAsset;

  bool get hasImage => imagePath != null || imageAsset != null;

  /// Objects that carry a finding needed for the puzzle.
  List<SceneObject> get clueObjects => objects.where((o) => o.hasClue).toList();

  /// The puzzle data is spread over the scene (player must explore).
  bool get hasClueChain => clueObjects.length >= 2;

  SceneObject? objectById(String id) {
    for (final o in objects) {
      if (o.id == id) return o;
    }
    return null;
  }

  factory Scene.fromJson(Map<String, dynamic> j) {
    final objs = jMapList(j, 'objects');
    return Scene(
      backdrop: Backdrops.normalize(jStrOrNull(j, 'backdrop')),
      ambientColor: jStr(j, 'ambientColor', fallback: '#3b82f6'),
      lighting: Lighting.parse(jStrOrNull(j, 'lighting')),
      objects: [
        for (var i = 0; i < objs.length; i++) SceneObject.fromJson(objs[i], i),
      ],
      props: jMapList(j, 'props').map(SceneProp.fromJson).toList(),
      imagePrompt: jStr(j, 'imagePrompt'),
      imagePath: jStrOrNull(j, 'imagePath'),
      imageAsset: jStrOrNull(j, 'imageAsset'),
    );
  }

  Map<String, dynamic> toJson() => {
        'backdrop': backdrop,
        'ambientColor': ambientColor,
        'lighting': lighting.wire,
        'objects': objects.map((o) => o.toJson()).toList(),
        'props': props.map((p) => p.toJson()).toList(),
        'imagePrompt': imagePrompt,
        'imagePath': imagePath,
        'imageAsset': imageAsset,
      };

  Scene copyWith(
          {String? imagePath, bool clearImage = false, List<SceneProp>? props}) =>
      Scene(
        backdrop: backdrop,
        ambientColor: ambientColor,
        lighting: lighting,
        objects: objects,
        props: props ?? this.props,
        imagePrompt: imagePrompt,
        imagePath: clearImage ? null : (imagePath ?? this.imagePath),
        imageAsset: imageAsset,
      );
}

/// Texts used when the live game master is unavailable.
class FallbackTexts {
  const FallbackTexts({
    required this.success,
    required this.failure,
    required this.stuck,
  });

  final String success;
  final String failure;

  /// Shown when the player asks the GM for help without hints left.
  final String stuck;

  factory FallbackTexts.fromJson(Map<String, dynamic> j) => FallbackTexts(
        success: jStr(j, 'success', fallback: 'Brawo! Mechanizm ustępuje.'),
        failure:
            jStr(j, 'failure', fallback: 'To nie to. Spróbujcie jeszcze raz.'),
        stuck: jStr(j, 'stuck',
            fallback: 'Przyjrzyjcie się uważnie wszystkim wskazówkom.'),
      );

  Map<String, dynamic> toJson() =>
      {'success': success, 'failure': failure, 'stuck': stuck};
}

class GameStage {
  const GameStage({
    required this.id,
    required this.title,
    required this.narrative,
    required this.scene,
    required this.puzzle,
    required this.hints,
    required this.fallbackTexts,
    required this.effectOnSuccess,
  });

  final String id;
  final String title;

  /// Text shown when entering the stage.
  final String narrative;
  final Scene scene;
  final Puzzle puzzle;

  /// Three hints, vague → explicit.
  final List<String> hints;
  final FallbackTexts fallbackTexts;
  final SuccessEffect effectOnSuccess;

  factory GameStage.fromJson(Map<String, dynamic> j, int index) => GameStage(
        id: jStrOrNull(j, 'id') ?? 'stage_${index + 1}',
        title: jStr(j, 'title', fallback: 'Etap ${index + 1}'),
        narrative: jStr(j, 'narrative'),
        scene: Scene.fromJson(jMap(j, 'scene')),
        puzzle: Puzzle.fromJson(jMap(j, 'puzzle')),
        hints: jStrList(j, 'hints'),
        fallbackTexts: FallbackTexts.fromJson(jMap(j, 'fallbackTexts')),
        effectOnSuccess:
            SuccessEffect.parse(jStrOrNull(j, 'effectOnSuccess')),
      );

  GameStage copyWith({Scene? scene}) => GameStage(
        id: id,
        title: title,
        narrative: narrative,
        scene: scene ?? this.scene,
        puzzle: puzzle,
        hints: hints,
        fallbackTexts: fallbackTexts,
        effectOnSuccess: effectOnSuccess,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'narrative': narrative,
        'scene': scene.toJson(),
        'puzzle': puzzle.toJson(),
        'hints': hints,
        'fallbackTexts': fallbackTexts.toJson(),
        'effectOnSuccess': effectOnSuccess.wire,
      };
}

/// The playable game produced by the AI designer from a [Scenario].
class GameSpec {
  const GameSpec({
    required this.id,
    required this.scenarioId,
    required this.title,
    required this.intro,
    required this.outro,
    required this.difficulty,
    required this.targetAge,
    required this.visualTheme,
    required this.stages,
    required this.createdAt,
    this.designedBy,
    this.gmPersona = '',
  });

  static const format = 'escape-room-game/1';

  /// Who the live game master is in the world of the game.
  final String gmPersona;

  final String id;
  final String scenarioId;
  final String title;
  final String intro;
  final String outro;
  final Difficulty difficulty;
  final int targetAge;
  final VisualTheme visualTheme;
  final List<GameStage> stages;
  final DateTime createdAt;

  /// e.g. "anthropic/claude-opus-5" – informational.
  final String? designedBy;

  factory GameSpec.fromJson(Map<String, dynamic> j,
      {String? id, String? scenarioId, String? designedBy}) {
    final stages = jMapList(j, 'stages');
    return GameSpec(
      id: id ?? jStrOrNull(j, 'id') ?? '',
      scenarioId: scenarioId ?? jStr(j, 'scenarioId'),
      title: jStr(j, 'title', fallback: 'Bez tytułu'),
      intro: jStr(j, 'intro'),
      outro: jStr(j, 'outro'),
      difficulty: Difficulty.parse(jStrOrNull(j, 'difficulty')),
      targetAge: jInt(j, 'targetAge', fallback: 10),
      visualTheme: VisualTheme.parse(jStrOrNull(j, 'visualTheme')),
      stages: [
        for (var i = 0; i < stages.length; i++) GameStage.fromJson(stages[i], i),
      ],
      createdAt: jDate(j, 'createdAt'),
      designedBy: designedBy ?? jStrOrNull(j, 'designedBy'),
      gmPersona: jStr(j, 'gmPersona').trim(),
    );
  }

  Map<String, dynamic> toJson() => {
        'format': format,
        'id': id,
        'scenarioId': scenarioId,
        'gmPersona': gmPersona,
        'title': title,
        'intro': intro,
        'outro': outro,
        'difficulty': difficulty.wire,
        'targetAge': targetAge,
        'visualTheme': visualTheme.wire,
        'stages': stages.map((s) => s.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'designedBy': designedBy,
      };

  /// True when every stage has an illustration.
  bool get hasImages => stages.every((s) => s.scene.hasImage);

  GameSpec copyWith(
          {String? id,
          String? scenarioId,
          String? designedBy,
          List<GameStage>? stages}) =>
      GameSpec(
        id: id ?? this.id,
        scenarioId: scenarioId ?? this.scenarioId,
        title: title,
        intro: intro,
        outro: outro,
        difficulty: difficulty,
        targetAge: targetAge,
        visualTheme: visualTheme,
        stages: stages ?? this.stages,
        createdAt: createdAt,
        designedBy: designedBy ?? this.designedBy,
      );
}
