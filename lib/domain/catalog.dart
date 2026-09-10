/// The catalogue of things the app can render. The AI game designer picks
/// from these lists, so anything it produces is guaranteed to be displayable.
library;

enum Difficulty {
  easy('easy', 'Łatwy'),
  medium('medium', 'Średni'),
  hard('hard', 'Trudny');

  const Difficulty(this.wire, this.label);
  final String wire;
  final String label;

  static Difficulty parse(String? s) => values.firstWhere(
        (d) => d.wire == (s ?? '').toLowerCase().trim(),
        orElse: () => Difficulty.medium,
      );
}

enum VisualTheme {
  laboratory('laboratory', 'Laboratorium'),
  castle('castle', 'Zamek'),
  spaceship('spaceship', 'Statek kosmiczny'),
  cave('cave', 'Jaskinia'),
  pyramid('pyramid', 'Piramida'),
  ship('ship', 'Statek piracki'),
  library('library', 'Biblioteka'),
  forest('forest', 'Las'),
  bunker('bunker', 'Bunkier');

  const VisualTheme(this.wire, this.label);
  final String wire;
  final String label;

  static VisualTheme parse(String? s) => values.firstWhere(
        (d) => d.wire == (s ?? '').toLowerCase().trim(),
        orElse: () => VisualTheme.laboratory,
      );
}

enum Lighting {
  dark('dark'),
  flicker('flicker'),
  bright('bright'),
  redAlert('red_alert');

  const Lighting(this.wire);
  final String wire;

  static Lighting parse(String? s) => values.firstWhere(
        (d) => d.wire == (s ?? '').toLowerCase().trim(),
        orElse: () => Lighting.dark,
      );
}

enum SuccessEffect {
  safeOpen('safe_open'),
  doorSlide('door_slide'),
  lightsOn('lights_on'),
  gearsTurn('gears_turn'),
  sparkle('sparkle'),
  none('none');

  const SuccessEffect(this.wire);
  final String wire;

  static SuccessEffect parse(String? s) => values.firstWhere(
        (d) => d.wire == (s ?? '').toLowerCase().trim(),
        orElse: () => SuccessEffect.sparkle,
      );
}

/// Backdrops: a room "kind". Rendering maps each to a gradient + big icon.
class Backdrops {
  static const List<String> all = [
    'workshop',
    'control_room',
    'corridor',
    'vault',
    'throne_hall',
    'dungeon',
    'tower',
    'cockpit',
    'engine_room',
    'airlock',
    'cavern',
    'underground_lake',
    'tomb',
    'sand_chamber',
    'deck',
    'cabin',
    'cargo_hold',
    'reading_room',
    'archive',
    'clearing',
    'hut',
    'bunker_hall',
    'generator_room',
    'garden',
    'kitchen',
    'observatory',
  ];

  static String normalize(String? s) {
    final v = (s ?? '').toLowerCase().trim();
    return all.contains(v) ? v : 'corridor';
  }
}

/// Icons the designer may attach to scene objects. Mapped to Material icons
/// in the UI layer; unknown names fall back to a generic "box" icon.
class SceneIcons {
  static const List<String> all = [
    'cable',
    'lock',
    'safe',
    'scale',
    'box',
    'lamp',
    'book',
    'key',
    'gear',
    'potion',
    'map',
    'crystal',
    'door',
    'lever',
    'switch',
    'computer',
    'screen',
    'keyboard',
    'battery',
    'bulb',
    'candle',
    'chest',
    'clock',
    'compass',
    'skull',
    'scroll',
    'telescope',
    'wrench',
    'hammer',
    'microscope',
    'flask',
    'mirror',
    'painting',
    'plant',
    'radio',
    'rope',
    'ladder',
    'window',
    'table',
    'chair',
    'statue',
    'torch',
    'coin',
    'bottle',
    'note',
    'phone',
    'camera',
    'anchor',
    'rocket',
    'shield',
  ];

  static String normalize(String? s) {
    final v = (s ?? '').toLowerCase().trim();
    return all.contains(v) ? v : 'box';
  }
}

/// Wire names of puzzle types the app can render.
class PuzzleTypes {
  static const sequenceOrder = 'sequence_order';
  static const pinCode = 'pin_code';
  static const multipleChoice = 'multiple_choice';
  static const textAnswer = 'text_answer';
  static const matching = 'matching';
  static const toggleGrid = 'toggle_grid';
  static const dialCombination = 'dial_combination';
  static const openExplanation = 'open_explanation';

  static const List<String> all = [
    sequenceOrder,
    pinCode,
    multipleChoice,
    textAnswer,
    matching,
    toggleGrid,
    dialCombination,
    openExplanation,
  ];
}

/// Animated props the app can draw on a scene. The designer places them with
/// relative coordinates over the backdrop illustration.
class PropTypes {
  static const Map<String, String> all = {
    'lever': 'wajcha – opuszczona/podniesiona, animacja przełączenia',
    'switch': 'przełącznik kołyskowy z diodą',
    'pinpad': 'mały panel z klawiaturą i migającą diodą (czerwona → zielona po sukcesie)',
    'gauge': 'okrągły wskaźnik z drgającą wskazówką',
    'lamp': 'lampa/dioda pulsująca światłem',
    'gear': 'para obracających się kół zębatych',
    'steam': 'para/dym unoszący się z rury',
    'sparks': 'iskry strzelające z uszkodzonego kabla',
    'door': 'drzwi/wrota – zamknięte, rozsuwają się po sukcesie',
    'screen': 'monitor z przewijanymi liniami tekstu i kursorem',
    'pendulum': 'wahadło zegara',
    'valve': 'zawór z kołem, obraca się powoli',
    'candle': 'świeca/pochodnia z migoczącym płomieniem',
    'window': 'okno z deszczem i błyskami burzy',
    'radar': 'ekran radaru z obracającą się wiązką',
    'chest': 'skrzynia – otwiera się po sukcesie',
    'crystal': 'świecący kryształ pulsujący kolorem',
    'fan': 'wentylator/śmigło obracające się',
    'scroll': 'zwój/pergamin/kartka – rozwija się i podświetla po sukcesie',
    'potion': 'fiolka/kolba z bulgoczącym płynem',
    'book': 'otwarta księga z przewracaną kartką',
    'custom': 'DOWOLNY przedmiot spoza listy – aplikacja wygeneruje jego obrazek (sprite) z pola spritePrompt i animuje go ogólnie (animation)',
  };

  /// Generic motions for generated sprites.
  static const List<String> animations = ['bob', 'pulse', 'swing', 'spin', 'none'];

  static String normalize(String? s) {
    final v = (s ?? '').toLowerCase().trim();
    return all.containsKey(v) ? v : 'lamp';
  }
}
