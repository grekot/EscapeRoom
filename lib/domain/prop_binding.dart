import 'game_spec.dart';

/// Keeps props visually consistent with the objects they are bound to.
///
/// The AI designer sometimes attaches a decorative prop (e.g. a candle) to an
/// unrelated object (e.g. a parchment). Each object icon has a set of prop
/// types that plausibly depict it; a bound prop outside that set is replaced
/// by the set's first (most literal) type, so that what the player taps looks
/// like what the game master then describes.
class PropBinding {
  const PropBinding._();

  /// Object icon → acceptable prop types (first = preferred replacement).
  static const Map<String, List<String>> compatible = {
    'note': ['scroll', 'book'],
    'scroll': ['scroll', 'book'],
    'map': ['scroll'],
    'book': ['book', 'scroll'],
    'candle': ['candle', 'lamp'],
    'torch': ['candle', 'lamp'],
    'lock': ['pinpad', 'chest', 'door'],
    'safe': ['pinpad', 'chest', 'door'],
    'keyboard': ['pinpad', 'screen'],
    'lever': ['lever', 'switch'],
    'switch': ['switch', 'lever'],
    'battery': ['switch', 'lamp'],
    'gear': ['gear', 'valve', 'fan'],
    'wrench': ['gear', 'valve'],
    'hammer': ['gear'],
    'door': ['door'],
    'screen': ['screen', 'radar'],
    'computer': ['screen', 'radar', 'pinpad'],
    'radio': ['radar', 'screen'],
    'chest': ['chest'],
    'box': ['chest'],
    'crystal': ['crystal', 'lamp'],
    'potion': ['potion', 'valve', 'gauge'],
    'flask': ['potion', 'valve', 'gauge'],
    'bottle': ['potion'],
    'lamp': ['lamp', 'candle'],
    'bulb': ['lamp'],
    'window': ['window'],
    'clock': ['pendulum', 'gauge'],
    'cable': ['sparks', 'switch'],
    'scale': ['gauge'],
    'compass': ['gauge', 'radar'],
  };

  /// Pure effects may decorate any object without depicting it.
  static const Set<String> effects = {'steam', 'sparks'};

  /// The type a prop bound to an object with [icon] should have, or null when
  /// [current] is already acceptable (or the icon has no counterpart).
  static String? replacementFor(String icon, String current) {
    if (effects.contains(current) || current == 'custom') return null;
    final ok = compatible[icon];
    if (ok == null || ok.contains(current)) return null;
    return ok.first;
  }

  /// Returns the stage with mismatched prop types corrected.
  static GameStage fix(GameStage stage) {
    final icons = {for (final o in stage.scene.objects) o.id: o.icon};
    var changed = false;
    final props = <SceneProp>[];
    for (final p in stage.scene.props) {
      final icon = p.objectId == null ? null : icons[p.objectId];
      final want = icon == null ? null : replacementFor(icon, p.type);
      if (want != null) {
        changed = true;
        props.add(p.copyWith(type: want));
      } else {
        props.add(p);
      }
    }
    if (!changed) return stage;
    return stage.copyWith(scene: stage.scene.copyWith(props: props));
  }

  static GameSpec fixAll(GameSpec spec) =>
      spec.copyWith(stages: spec.stages.map(fix).toList());
}
