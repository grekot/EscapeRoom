import 'package:flutter/material.dart';

import '../domain/catalog.dart';

const _seed = Color(0xFF14B8A6);

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: _seed,
    brightness: Brightness.dark,
    surface: const Color(0xFF0F172A),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFF0B1220),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF162032),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF111A2B),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

/// Colour palette for a visual theme.
class ThemePalette {
  const ThemePalette({
    required this.primary,
    required this.secondary,
    required this.top,
    required this.bottom,
  });

  final Color primary;
  final Color secondary;
  final Color top;
  final Color bottom;

  static ThemePalette of(VisualTheme t) => switch (t) {
        VisualTheme.laboratory => const ThemePalette(
            primary: Color(0xFF22D3EE),
            secondary: Color(0xFFA3E635),
            top: Color(0xFF0E2A3A),
            bottom: Color(0xFF071119)),
        VisualTheme.castle => const ThemePalette(
            primary: Color(0xFFC084FC),
            secondary: Color(0xFFFBBF24),
            top: Color(0xFF2A1A3E),
            bottom: Color(0xFF120A1C)),
        VisualTheme.spaceship => const ThemePalette(
            primary: Color(0xFF60A5FA),
            secondary: Color(0xFFF472B6),
            top: Color(0xFF111C3A),
            bottom: Color(0xFF05091A)),
        VisualTheme.cave => const ThemePalette(
            primary: Color(0xFFF59E0B),
            secondary: Color(0xFF94A3B8),
            top: Color(0xFF2B1F14),
            bottom: Color(0xFF120D08)),
        VisualTheme.pyramid => const ThemePalette(
            primary: Color(0xFFFBBF24),
            secondary: Color(0xFF38BDF8),
            top: Color(0xFF3A2A12),
            bottom: Color(0xFF1A1206)),
        VisualTheme.ship => const ThemePalette(
            primary: Color(0xFF2DD4BF),
            secondary: Color(0xFFFB923C),
            top: Color(0xFF0F2A3A),
            bottom: Color(0xFF06131C)),
        VisualTheme.library => const ThemePalette(
            primary: Color(0xFFD6A35C),
            secondary: Color(0xFF86EFAC),
            top: Color(0xFF2E2114),
            bottom: Color(0xFF150E08)),
        VisualTheme.forest => const ThemePalette(
            primary: Color(0xFF4ADE80),
            secondary: Color(0xFFFDE68A),
            top: Color(0xFF0F2E1A),
            bottom: Color(0xFF06140B)),
        VisualTheme.bunker => const ThemePalette(
            primary: Color(0xFFF87171),
            secondary: Color(0xFFCBD5E1),
            top: Color(0xFF262B33),
            bottom: Color(0xFF0E1013)),
      };
}

Color? parseHexColor(String s) {
  var h = s.trim().replaceAll('#', '');
  if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return null;
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(v);
}

IconData backdropIcon(String backdrop) => switch (backdrop) {
      'workshop' => Icons.handyman,
      'control_room' => Icons.settings_input_component,
      'corridor' => Icons.meeting_room,
      'vault' => Icons.lock,
      'throne_hall' => Icons.castle,
      'dungeon' => Icons.grid_on,
      'tower' => Icons.location_city,
      'cockpit' => Icons.flight_takeoff,
      'engine_room' => Icons.settings,
      'airlock' => Icons.door_sliding,
      'cavern' => Icons.terrain,
      'underground_lake' => Icons.water,
      'tomb' => Icons.account_balance,
      'sand_chamber' => Icons.landscape,
      'deck' => Icons.sailing,
      'cabin' => Icons.bed,
      'cargo_hold' => Icons.inventory_2,
      'reading_room' => Icons.menu_book,
      'archive' => Icons.folder,
      'clearing' => Icons.park,
      'hut' => Icons.cottage,
      'bunker_hall' => Icons.shield,
      'generator_room' => Icons.bolt,
      'garden' => Icons.local_florist,
      'kitchen' => Icons.kitchen,
      'observatory' => Icons.star,
      _ => Icons.meeting_room,
    };

IconData sceneIcon(String name) => switch (name) {
      'cable' => Icons.cable,
      'lock' => Icons.lock,
      'safe' => Icons.security,
      'scale' => Icons.balance,
      'box' => Icons.inventory_2,
      'lamp' => Icons.light,
      'book' => Icons.menu_book,
      'key' => Icons.key,
      'gear' => Icons.settings,
      'potion' => Icons.science,
      'map' => Icons.map,
      'crystal' => Icons.diamond,
      'door' => Icons.door_front_door,
      'lever' => Icons.toggle_on,
      'switch' => Icons.power_settings_new,
      'computer' => Icons.computer,
      'screen' => Icons.tv,
      'keyboard' => Icons.keyboard,
      'battery' => Icons.battery_full,
      'bulb' => Icons.lightbulb,
      'candle' => Icons.local_fire_department,
      'chest' => Icons.inventory,
      'clock' => Icons.schedule,
      'compass' => Icons.explore,
      'skull' => Icons.dangerous,
      'scroll' => Icons.description,
      'telescope' => Icons.travel_explore,
      'wrench' => Icons.build,
      'hammer' => Icons.hardware,
      'microscope' => Icons.biotech,
      'flask' => Icons.science,
      'mirror' => Icons.flip,
      'painting' => Icons.image,
      'plant' => Icons.eco,
      'radio' => Icons.radio,
      'rope' => Icons.link,
      'ladder' => Icons.stairs,
      'window' => Icons.window,
      'table' => Icons.table_restaurant,
      'chair' => Icons.chair,
      'statue' => Icons.person_pin,
      'torch' => Icons.flashlight_on,
      'coin' => Icons.monetization_on,
      'bottle' => Icons.liquor,
      'note' => Icons.sticky_note_2,
      'phone' => Icons.phone,
      'camera' => Icons.photo_camera,
      'anchor' => Icons.anchor,
      'rocket' => Icons.rocket_launch,
      'shield' => Icons.shield,
      _ => Icons.inventory_2,
    };

IconData themeIcon(VisualTheme t) => switch (t) {
      VisualTheme.laboratory => Icons.science,
      VisualTheme.castle => Icons.castle,
      VisualTheme.spaceship => Icons.rocket_launch,
      VisualTheme.cave => Icons.terrain,
      VisualTheme.pyramid => Icons.change_history,
      VisualTheme.ship => Icons.sailing,
      VisualTheme.library => Icons.menu_book,
      VisualTheme.forest => Icons.park,
      VisualTheme.bunker => Icons.shield,
    };
