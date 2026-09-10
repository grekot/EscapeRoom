import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../domain/catalog.dart';
import '../../../domain/game_spec.dart';
import '../props/prop_painter.dart';
import '../props/sprite_prop.dart';
import 'backdrop_painter.dart';

/// The "room": an illustration (AI-generated, bundled, or procedural),
/// lighting, animated props placed by the designer, and tappable objects.
///
/// Every object is reachable from the picture: either through the prop that
/// depicts it (labelled) or through a marker at the object's hotspot. The
/// chip row below is a legend; tapping a chip highlights the element on the
/// picture and vice versa.
class SceneView extends StatefulWidget {
  const SceneView({
    super.key,
    required this.stage,
    required this.palette,
    required this.onInspect,
    required this.enabled,
    this.solved = false,
    this.lit = false,
    this.discovered = const {},
    this.focusObjectId,
  });

  /// Object the game master points at; the scene flashes it when it changes.
  final String? focusObjectId;

  final GameStage stage;
  final ThemePalette palette;
  final void Function(SceneObject) onInspect;
  final bool enabled;

  /// Stage solved: props switch to their activated state.
  final bool solved;

  /// After `lights_on`, render as bright regardless of scene lighting.
  final bool lit;

  /// Ids of objects already examined in this stage (clue chain state).
  final Set<String> discovered;

  bool isLocked(SceneObject o) => o.isChained && !discovered.contains(o.requires);

  @override
  State<SceneView> createState() => _SceneViewState();
}

class _SceneViewState extends State<SceneView>
    with SingleTickerProviderStateMixin {
  // Created eagerly: a lazy `late final` would be initialised inside
  // dispose() for scenes that never animate, on a deactivated element.
  late final AnimationController _clock;
  final Set<int> _poked = {};
  String? _highlight;
  Timer? _highlightTimer;

  /// Object the camera is zoomed on (close-up mode), and where.
  SceneObject? _focus;
  Alignment _focusAlign = Alignment.center;

  @override
  void initState() {
    super.initState();
    _clock = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant SceneView old) {
    super.didUpdateWidget(old);
    if (old.stage.id != widget.stage.id) {
      _poked.clear();
      _highlight = null;
      _focus = null;
    }
    if (widget.solved && !old.solved) _focus = null;
    final f = widget.focusObjectId;
    if (f != null && f.isNotEmpty && f != old.focusObjectId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _flash(f);
      });
    }
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _clock.dispose();
    super.dispose();
  }

  SceneObject? _objectFor(SceneProp p) {
    if (p.objectId == null || p.objectId!.isEmpty) return null;
    for (final o in widget.stage.scene.objects) {
      if (o.id == p.objectId) return o;
    }
    return null;
  }

  /// Objects depicted by a prop (they need no separate marker).
  Set<String> get _depicted => {
        for (final p in widget.stage.scene.props)
          if (_objectFor(p) != null) p.objectId!,
      };

  void _flash(String objectId) {
    _highlightTimer?.cancel();
    setState(() => _highlight = objectId);
    _highlightTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _highlight = null);
    });
  }

  /// Where the object sits on the picture (prop position, hotspot, or centre).
  Alignment _alignmentOf(SceneObject o) {
    for (final p in widget.stage.scene.props) {
      if (p.objectId == o.id) return Alignment(p.x * 2 - 1, p.y * 2 - 1);
    }
    if (o.hasHotspot) return Alignment(o.x! * 2 - 1, o.y! * 2 - 1);
    return Alignment.center;
  }

  void _inspect(SceneObject o) {
    _flash(o.id);
    setState(() {
      _focus = o;
      _focusAlign = _alignmentOf(o);
    });
    widget.onInspect(o);
  }

  void _exitFocus() {
    if (_focus != null) setState(() => _focus = null);
  }

  @override
  Widget build(BuildContext context) {
    final scene = widget.stage.scene;
    final ambient = parseHexColor(scene.ambientColor) ?? widget.palette.primary;
    final lighting = widget.lit ? Lighting.bright : scene.lighting;
    final accent = widget.palette.primary;
    final depicted = _depicted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth, h = c.maxHeight;
                return AnimatedBuilder(
                  animation: _clock,
                  builder: (context, _) {
                    final t = _clock.value;
                    final focused = _focus != null;
                    return Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        // The "camera": the whole room scales around the
                        // inspected object when in close-up mode.
                        Positioned.fill(
                          child: AnimatedScale(
                            scale: focused ? 2.2 : 1.0,
                            alignment: _focusAlign,
                            duration: const Duration(milliseconds: 650),
                            curve: Curves.easeInOutCubic,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned.fill(
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 600),
                                    child: KeyedSubtree(
                                      key: ValueKey('bg-${widget.stage.id}'),
                                      child: _background(scene, ambient, t),
                                    ),
                                  ),
                                ),
                                ..._lighting(lighting, t),
                                for (var i = 0; i < scene.props.length; i++)
                                  ..._prop(scene.props[i], i, w, h, t, accent,
                                      showLabel: !focused),
                                if (!focused)
                                  for (final o in scene.objects)
                                    if (o.hasHotspot && !depicted.contains(o.id))
                                      _hotspot(o, w, h, t, accent),
                              ],
                            ),
                          ),
                        ),
                        if (focused) _closeUp(_focus!, accent),
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          child: IgnorePointer(
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Color(0xCC000000), Color(0x00000000)],
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(_lightIcon(lighting), size: 16,
                                      color: Colors.white.withValues(alpha: 0.75)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      widget.stage.title,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          shadows: const [Shadow(blurRadius: 8, color: Colors.black)]),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
        if (scene.objects.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final o in scene.objects)
                  _ObjectChip(
                    object: o,
                    accent: accent,
                    enabled: widget.enabled,
                    highlighted: _highlight == o.id,
                    explored: widget.discovered.contains(o.id),
                    onTap: () => _inspect(o),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _background(Scene scene, Color ambient, double t) {
    final path = scene.imagePath;
    if (path != null && File(path).existsSync()) {
      return Image.file(File(path), fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _procedural(scene, ambient, t));
    }
    if (scene.imageAsset != null) {
      return Image.asset(scene.imageAsset!, fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _procedural(scene, ambient, t));
    }
    return _procedural(scene, ambient, t);
  }

  Widget _procedural(Scene scene, Color ambient, double t) => CustomPaint(
        painter: BackdropPainter(
          backdrop: scene.backdrop,
          ambient: ambient,
          palette: widget.palette,
          t: t,
        ),
      );

  List<Widget> _lighting(Lighting lighting, double t) {
    switch (lighting) {
      case Lighting.dark:
        return [
          Positioned.fill(child: ColoredBox(color: Colors.black.withValues(alpha: 0.45))),
        ];
      case Lighting.flicker:
        final n = (sin(t * 2 * pi * 23) * sin(t * 2 * pi * 7)).abs();
        return [
          Positioned.fill(child: ColoredBox(color: Colors.black.withValues(alpha: 0.12 + 0.35 * n))),
        ];
      case Lighting.redAlert:
        final p = 0.5 + 0.5 * sin(t * 2 * pi * 2);
        return [
          Positioned.fill(child: ColoredBox(color: Colors.red.withValues(alpha: 0.08 + 0.22 * p))),
        ];
      case Lighting.bright:
        return const [];
    }
  }

  /// The prop itself plus, when it depicts an object, a name tag below it.
  List<Widget> _prop(SceneProp p, int index, double w, double h, double t, Color accent,
      {bool showLabel = true}) {
    final size = w * p.size;
    // Props are roughly square; tall ones get more height.
    final tall = const {'lever', 'candle', 'pendulum', 'door', 'crystal', 'steam', 'custom'}.contains(p.type);
    final ph = tall ? size * 1.35 : size;
    final left = (p.x * w - size / 2).clamp(0.0, max(0.0, w - size)).toDouble();
    final top = (p.y * h - ph / 2).clamp(0.0, max(0.0, h - ph)).toDouble();
    final activeTarget =
        (widget.solved && p.reactsToSuccess) || _poked.contains(index) ? 1.0 : 0.0;
    final obj = _objectFor(p);
    final togglable = const {'lever', 'switch', 'valve', 'lamp', 'fan'}.contains(p.type);
    final highlighted = obj != null && _highlight == obj.id;

    return [
      Positioned(
        left: left,
        top: top,
        width: size,
        height: ph,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: !widget.enabled
              ? null
              : () {
                  if (obj != null) _inspect(obj);
                  if (togglable) {
                    setState(() {
                      if (!_poked.remove(index)) _poked.add(index);
                    });
                  }
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: highlighted
                  ? [BoxShadow(color: accent.withValues(alpha: 0.9), blurRadius: 18, spreadRadius: 3)]
                  : const [],
            ),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: activeTarget),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeInOut,
              builder: (_, active, _) => p.isCustom
                  ? SpriteProp(prop: p, t: t, active: active, accent: accent, seed: index * 7)
                  : CustomPaint(
                      painter: PropPainter(
                        type: p.type,
                        t: t,
                        active: active,
                        accent: accent,
                        seed: index * 7 + p.type.hashCode % 13,
                      ),
                    ),
            ),
          ),
        ),
      ),
      if (obj != null && showLabel)
        Positioned(
          left: left + size / 2 - 70,
          top: min(top + ph + 2, h - 18),
          width: 140,
          child: IgnorePointer(
            child: Center(child: _Tag(text: obj.label, accent: accent, highlighted: highlighted)),
          ),
        ),
    ];
  }

  /// Marker for an object that no prop depicts: icon badge with a pulse ring.
  Widget _hotspot(SceneObject o, double w, double h, double t, Color accent) {
    const r = 16.0;
    final cx = (o.x! * w).clamp(r, w - r);
    final cy = (o.y! * h).clamp(r, h - r);
    final pulse = 0.5 + 0.5 * sin(t * 2 * pi * 2 + o.id.hashCode % 7);
    final highlighted = _highlight == o.id;
    return Positioned(
      left: cx - 70,
      top: cy - r,
      width: 140,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.enabled ? () => _inspect(o) : null,
            child: Container(
              width: r * 2,
              height: r * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.6),
                border: Border.all(
                  color: accent.withValues(alpha: highlighted ? 1 : 0.5 + 0.4 * pulse),
                  width: highlighted ? 2.5 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: highlighted ? 0.9 : 0.25 * pulse),
                    blurRadius: highlighted ? 18 : 8 + 8 * pulse,
                    spreadRadius: highlighted ? 3 : 1,
                  ),
                ],
              ),
              child: Icon(sceneIcon(o.icon), size: 16, color: accent),
            ),
          ),
          const SizedBox(height: 2),
          IgnorePointer(child: _Tag(text: o.label, accent: accent, highlighted: highlighted)),
        ],
      ),
    );
  }

  /// Darkened frame with the object's name and description; tap to leave.
  Widget _closeUp(SceneObject o, Color accent) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _exitFocus,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
          builder: (_, v, child) => Opacity(opacity: v, child: child),
          child: Stack(
            children: [
              // vignette so the zoomed object pops
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.9,
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.75)],
                      stops: const [0.45, 1],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accent.withValues(alpha: 0.5)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.zoom_out_map, size: 14, color: accent),
                    const SizedBox(width: 4),
                    const Text('Wróć', style: TextStyle(fontSize: 11.5)),
                  ]),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accent.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(sceneIcon(o.icon), color: accent, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(o.label,
                                style: TextStyle(fontWeight: FontWeight.w700, color: accent, fontSize: 13)),
                            const SizedBox(height: 2),
                            Text(o.description,
                                maxLines: o.hasClue ? 2 : 4,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, height: 1.3)),
                            if (o.hasClue) ...[
                              const SizedBox(height: 6),
                              _finding(o, accent),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The object's finding (or the reason it cannot be read yet).
  Widget _finding(SceneObject o, Color accent) {
    final locked = widget.isLocked(o);
    final text = locked
        ? (o.lockedText.isNotEmpty ? o.lockedText : 'Jeszcze nie da się tego odczytać – zbadajcie najpierw coś innego.')
        : o.clue;
    final color = locked ? Colors.white70 : accent;
    return Container(
      key: ValueKey(locked ? 'finding-locked' : 'finding-open'),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: (locked ? Colors.white : accent).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(locked ? Icons.lock_outline : Icons.search, size: 15, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              locked ? text : 'Odkrycie: $text',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, height: 1.3, color: locked ? Colors.white70 : Colors.white,
                  fontStyle: locked ? FontStyle.italic : FontStyle.normal),
            ),
          ),
        ],
      ),
    );
  }

  IconData _lightIcon(Lighting l) => switch (l) {
        Lighting.dark => Icons.dark_mode,
        Lighting.flicker => Icons.flash_on,
        Lighting.bright => Icons.light_mode,
        Lighting.redAlert => Icons.warning_amber,
      };
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.accent, required this.highlighted});

  final String text;
  final Color accent;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: highlighted ? accent : Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: highlighted ? 1 : 0.35)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: highlighted ? Colors.black : Colors.white,
        ),
      ),
    );
  }
}

class _ObjectChip extends StatelessWidget {
  const _ObjectChip({
    required this.object,
    required this.accent,
    required this.enabled,
    required this.highlighted,
    required this.onTap,
    this.explored = false,
  });

  final SceneObject object;
  final Color accent;
  final bool enabled;
  final bool highlighted;

  /// Already examined: no "unexplored" dot.
  final bool explored;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlighted ? accent.withValues(alpha: 0.25) : const Color(0xFF111A2B),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: accent.withValues(alpha: highlighted ? 1 : 0.35),
              width: highlighted ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(sceneIcon(object.icon), size: 18, color: accent),
              const SizedBox(width: 6),
              Text(object.label, style: const TextStyle(fontSize: 12.5)),
              if (!explored) ...[
                const SizedBox(width: 6),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent,
                    boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.8), blurRadius: 6)],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
