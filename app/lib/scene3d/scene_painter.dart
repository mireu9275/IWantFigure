/// Software renderer for a [Scene3D]: projects every face and segment with
/// an [OrbitCamera] and draws them with the painter's algorithm (far → near).
///
/// Drawing order per frame:
///  1. floor grid and the drop hole (the camera is always above the floor, so
///     nothing on the floor can occlude an object),
///  2. translucent acrylic platforms (everything rests on top of them),
///  3. all other solids — box faces, bar prisms, the claw — depth sorted,
///  4. annotations: the ghost of the predicted pose, marker guide lines,
///     labels and the aim markers.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/analysis.dart';
import '../models/scene.dart';
import 'projection.dart';

/// Paints a [Scene3D] seen through [camera].
///
/// [t] in `[0, 1]` is the motion animation parameter: the box named by
/// `scene.motion.boxId` is drawn at `motion.from.lerp(motion.to, t)` while
/// the final pose is always shown as a dashed ghost.
class ScenePainter extends CustomPainter {
  ScenePainter({
    required this.scene,
    required this.camera,
    required this.colors,
    this.t = 0,
    this.textScaler = TextScaler.noScaling,
  });

  final Scene3D scene;
  final OrbitCamera camera;

  /// Theme colours so the view stays readable in light and dark mode.
  final ColorScheme colors;

  /// Motion animation parameter, 0 = current pose, 1 = predicted pose.
  final double t;

  final TextScaler textScaler;

  /// Spacing of the floor grid lines.
  static const double gridStepMm = 100;

  /// Size of the claw unit body drawn above the aim point.
  static const Vec3 clawBodySize = Vec3(120, 120, 80);

  /// Label drawn on the drop hole.
  static const String dropHoleLabel = '落とし口';

  /// Label drawn at the player's edge of the field.
  static const String frontEdgeLabel = '手前';

  /// Fixed light direction (upper front-left) for flat shading.
  static final Vec3 lightDir = const Vec3(-0.35, 0.45, 0.82).normalized();

  static const Color _metal = Color(0xFF9AA0A6);
  static const Color _clawMetal = Color(0xFFB3B9C0);
  static const Color _clawArm = Color(0xFF646B72);
  static const Color _rubberTube = Color(0xFFF48FB1);
  static const Color _cardboard = Color(0xFFD9B98C);
  static const Color _plush = Color(0xFFF4A261);
  static const Color _acrylic = Color(0xFF90CAF9);
  static const Color _hole = Color(0xFFE53935);
  static const Color _armLeft = Color(0xFF2F80ED);
  static const Color _armRight = Color(0xFFF2994A);
  static const Color _armBoth = Color(0xFF27AE60);

  /// Colour used for a marker of the given [arm].
  static Color armColor(Arm arm) => switch (arm) {
        Arm.left => _armLeft,
        Arm.right => _armRight,
        Arm.both => _armBoth,
      };

  Color _materialColor(SceneMaterial material) => switch (material) {
        SceneMaterial.metal => _metal,
        SceneMaterial.rubberTube => _rubberTube,
        SceneMaterial.cardboard => _cardboard,
        SceneMaterial.plush => _plush,
        SceneMaterial.acrylic => _acrylic.withValues(alpha: 0.22),
        SceneMaterial.marker => colors.primary,
      };

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !size.width.isFinite || !size.height.isFinite) return;
    _Renderer(this, canvas, size).render();
  }

  @override
  bool shouldRepaint(ScenePainter oldDelegate) =>
      oldDelegate.scene != scene ||
      oldDelegate.camera != camera ||
      oldDelegate.t != t ||
      oldDelegate.colors != colors ||
      oldDelegate.textScaler != textScaler;
}

/// A drawable collected for depth sorting.
class _Item {
  const _Item(this.depth, this.draw);

  /// Average view depth in mm; larger = farther from the camera.
  final double depth;
  final void Function(Canvas canvas) draw;
}

/// Per-frame rendering state.
class _Renderer {
  _Renderer(this.painter, this.canvas, this.size);

  final ScenePainter painter;
  final Canvas canvas;
  final Size size;

  Scene3D get scene => painter.scene;
  OrbitCamera get camera => painter.camera;
  ColorScheme get colors => painter.colors;

  final List<_Item> _platform = [];
  final List<_Item> _solids = [];

  bool get _dark => colors.brightness == Brightness.dark;

  void render() {
    _drawFloor();
    _drawDropHole();

    final boxes = _boxesForFrame();
    for (final box in boxes) {
      _addBox(box);
    }
    for (final cylinder in scene.cylinders) {
      _addCylinder(cylinder);
    }
    final claw = scene.claw;
    if (claw != null) _addClaw(claw);

    _flush(_platform);
    _flush(_solids);

    _drawGhost();
    _drawBoxLabels(boxes);
    _drawFrontEdgeLabel();
    _drawMarkers();
  }

  void _flush(List<_Item> items) {
    items.sort((a, b) => b.depth.compareTo(a.depth));
    for (final item in items) {
      item.draw(canvas);
    }
    items.clear();
  }

  // ---------------------------------------------------------------------------
  // Scene content

  /// Boxes as drawn this frame: the moving prize replaced by its animated pose.
  List<SceneBox> _boxesForFrame() {
    final motion = scene.motion;
    if (motion == null) return scene.boxes;
    final t = painter.t.clamp(0.0, 1.0);
    return [
      for (final box in scene.boxes)
        if (box.id == motion.boxId) box.copyWith(pose: motion.from.lerp(motion.to, t)) else box,
    ];
  }

  void _drawFloor() {
    final hw = scene.fieldWidthMm / 2;
    final hd = scene.fieldDepthMm / 2;
    final gridPaint = Paint()
      ..color = colors.outlineVariant.withValues(alpha: _dark ? 0.55 : 0.7)
      ..strokeWidth = 1
      ..isAntiAlias = true;
    final borderPaint = Paint()
      ..color = colors.outline.withValues(alpha: 0.8)
      ..strokeWidth = 1.2
      ..isAntiAlias = true;

    final xs = _gridLines(-hw, hw);
    final ys = _gridLines(-hd, hd);
    for (final x in xs) {
      final border = x == xs.first || x == xs.last;
      _drawSegmentNow(Vec3(x, -hd, 0), Vec3(x, hd, 0), border ? borderPaint : gridPaint);
    }
    for (final y in ys) {
      final border = y == ys.first || y == ys.last;
      _drawSegmentNow(Vec3(-hw, y, 0), Vec3(hw, y, 0), border ? borderPaint : gridPaint);
    }
  }

  /// Grid line positions from [min] to [max] every [ScenePainter.gridStepMm],
  /// always including both ends.
  static List<double> _gridLines(double min, double max) {
    final out = <double>[];
    for (var v = min; v < max - 1e-6; v += ScenePainter.gridStepMm) {
      out.add(v);
    }
    out.add(max);
    return out;
  }

  void _drawDropHole() {
    final hole = scene.dropHole;
    if (hole == null) return;
    final corners = [
      Vec3(hole.xMin, hole.yMin, 0),
      Vec3(hole.xMax, hole.yMin, 0),
      Vec3(hole.xMax, hole.yMax, 0),
      Vec3(hole.xMin, hole.yMax, 0),
    ];
    final screen = _clippedScreenPolygon(corners);
    if (screen.length < 3) return;
    final path = Path()..addPolygon(screen, true);
    canvas.drawPath(
      path,
      Paint()
        ..color = ScenePainter._hole.withValues(alpha: _dark ? 0.32 : 0.26)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = ScenePainter._hole.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
    final centre = camera.project(
      Vec3((hole.xMin + hole.xMax) / 2, (hole.yMin + hole.yMax) / 2, 0),
      size,
    );
    if (centre.visible) {
      _drawLabel(
        centre.screen,
        ScenePainter.dropHoleLabel,
        color: _dark ? const Color(0xFFFF8A80) : const Color(0xFFC62828),
        anchor: Alignment.center,
      );
    }
  }

  void _addBox(SceneBox box) {
    final base = painter._materialColor(box.material);
    final translucent = box.material == SceneMaterial.acrylic;
    final edge = translucent ? ScenePainter._acrylic.withValues(alpha: 0.55) : _darken(base, 0.35);
    final target = translucent ? _platform : _solids;
    _addCuboid(box.corners(), box.pose.position, base, edge, cull: !translucent, into: target);
  }

  /// Adds the six faces of a cuboid given its 8 corners in the order produced
  /// by [SceneBox.corners] (x fastest, then y, then z).
  void _addCuboid(
    List<Vec3> c,
    Vec3 centre,
    Color fill,
    Color edge, {
    required bool cull,
    required List<_Item> into,
  }) {
    const faces = [
      [0, 2, 3, 1], // bottom (-z)
      [4, 5, 7, 6], // top (+z)
      [2, 6, 7, 3], // front (+y)
      [0, 1, 5, 4], // back (-y)
      [0, 4, 6, 2], // left (-x)
      [1, 3, 7, 5], // right (+x)
    ];
    for (final f in faces) {
      final pts = [c[f[0]], c[f[1]], c[f[2]], c[f[3]]];
      _addPolygon(pts, _outwardNormal(pts, centre), fill, edge, cull: cull, into: into);
    }
  }

  void _addCylinder(SceneCylinder cylinder) {
    const sides = 12;
    const maxSegmentMm = 150.0;
    final axisVec = cylinder.p1 - cylinder.p0;
    final length = axisVec.length;
    if (length <= 0) return;
    final axis = axisVec * (1 / length);
    final helper = axis.z.abs() < 0.9 ? const Vec3(0, 0, 1) : const Vec3(1, 0, 0);
    final u = axis.cross(helper).normalized();
    final v = axis.cross(u);
    final base = painter._materialColor(cylinder.material);
    final edge = _darken(base, 0.3);

    List<Vec3> ring(Vec3 centre) => [
          for (var i = 0; i < sides; i++)
            centre +
                u * (math.cos(i * 2 * math.pi / sides) * cylinder.radius) +
                v * (math.sin(i * 2 * math.pi / sides) * cylinder.radius),
        ];

    // Long bars are split so depth sorting against nearby boxes stays sane.
    final segments = math.max(1, (length / maxSegmentMm).ceil());
    for (var s = 0; s < segments; s++) {
      final a = cylinder.p0.lerp(cylinder.p1, s / segments);
      final b = cylinder.p0.lerp(cylinder.p1, (s + 1) / segments);
      final ringA = ring(a);
      final ringB = ring(b);
      for (var i = 0; i < sides; i++) {
        final j = (i + 1) % sides;
        final mid = (i + 0.5) * 2 * math.pi / sides;
        final normal = u * math.cos(mid) + v * math.sin(mid);
        _addPolygon([ringA[i], ringA[j], ringB[j], ringB[i]], normal, base, edge, cull: true, into: _solids);
      }
      if (s == 0) _addPolygon(ringA, -axis, base, edge, cull: true, into: _solids);
      if (s == segments - 1) _addPolygon(ringB, axis, base, edge, cull: true, into: _solids);
    }
  }

  void _addClaw(SceneClaw claw) {
    final c = claw.center;
    final body = SceneBox(
      id: 'claw_body',
      pose: Pose(Vec3(c.x, c.y, claw.restHeightMm)),
      size: ScenePainter.clawBodySize,
      material: SceneMaterial.metal,
    );
    _addCuboid(
      body.corners(),
      body.pose.position,
      ScenePainter._clawMetal,
      _darken(ScenePainter._clawMetal, 0.35),
      cull: true,
      into: _solids,
    );

    final bodyBottom = Vec3(c.x, c.y, claw.restHeightMm - ScenePainter.clawBodySize.z / 2);
    final radius = claw.openWidthMm / 2;
    final pivot = Vec3(c.x, c.y, c.z + math.max(60.0, radius * 1.1));
    final rodBottom = c.z < bodyBottom.z ? c : Vec3(c.x, c.y, bodyBottom.z - 1);

    // Thin vertical rod from the body down to the aim point.
    _addSegment(bodyBottom, rodBottom, ScenePainter._clawArm, widthMm: 8, into: _solids);
    // Hub where the arms are hinged.
    _addSegment(pivot, Vec3(c.x, c.y, pivot.z - 12), ScenePainter._clawArm, widthMm: 22, into: _solids);

    final count = claw.clawCount == 3 ? 3 : 2;
    final phase = count == 3 ? math.pi / 2 : 0.0;
    for (var i = 0; i < count; i++) {
      final angle = phase + i * 2 * math.pi / count;
      final dir = Vec3(math.cos(angle), math.sin(angle), 0);
      final tip = c + dir * radius;
      final elbow = c + dir * (radius + 14) + const Vec3(0, 0, 30);
      _addSegment(pivot, elbow, ScenePainter._clawArm, widthMm: 10, into: _solids);
      _addSegment(elbow, tip, ScenePainter._clawArm, widthMm: 8, into: _solids);
    }
  }

  /// Dashed outline of the prize at its predicted pose.
  void _drawGhost() {
    final motion = scene.motion;
    if (motion == null) return;
    final box = scene.boxById(motion.boxId);
    if (box == null) return;
    final ghost = box.copyWith(pose: motion.to);
    final c = ghost.corners();
    const edges = [
      [0, 1], [2, 3], [4, 5], [6, 7], // along x
      [0, 2], [1, 3], [4, 6], [5, 7], // along y
      [0, 4], [1, 5], [2, 6], [3, 7], // along z
    ];
    final paint = Paint()
      ..color = colors.primary.withValues(alpha: 0.75)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    for (final e in edges) {
      final seg = _clipSegment(camera.toView(c[e[0]]), camera.toView(c[e[1]]));
      if (seg == null) continue;
      _dashedLine(camera.viewToScreen(seg.$1, size), camera.viewToScreen(seg.$2, size), paint);
    }
  }

  /// Labels each box to the left of its leftmost top corner, so the label
  /// stays clear of the markers (whose labels extend to the right).
  void _drawBoxLabels(List<SceneBox> boxes) {
    for (final box in boxes) {
      if (box.label.isEmpty || box.material == SceneMaterial.acrylic) continue;
      final corners = box.corners();
      Projected? leftmost;
      for (var i = 4; i < 8; i++) {
        final p = camera.project(corners[i], size);
        if (!p.visible) continue;
        if (leftmost == null || p.screen.dx < leftmost.screen.dx) leftmost = p;
      }
      if (leftmost == null) continue;
      _drawLabel(
        leftmost.screen + const Offset(-6, 0),
        box.label,
        color: colors.onSurface,
        anchor: Alignment.centerRight,
      );
    }
  }

  void _drawFrontEdgeLabel() {
    final p = camera.project(Vec3(0, scene.fieldDepthMm / 2, 0), size);
    if (!p.visible) return;
    _drawLabel(
      p.screen + const Offset(0, 4),
      ScenePainter.frontEdgeLabel,
      color: colors.onSurfaceVariant,
      anchor: Alignment.topCenter,
      fontSize: 10,
      weight: FontWeight.w500,
      background: false,
    );
  }

  void _drawMarkers() {
    final projected = <(SceneMarker, Projected)>[];
    for (final marker in scene.markers) {
      final p = camera.project(marker.point, size);
      if (p.visible) projected.add((marker, p));
    }
    projected.sort((a, b) => b.$2.depth.compareTo(a.$2.depth));

    // Secondary markers (arm tips) label on their outer side, away from the
    // primary marker; the primary marker labels on the opposite side.
    Offset? primaryScreen;
    for (final (marker, p) in projected) {
      if (marker.primary) {
        primaryScreen = p.screen;
        break;
      }
    }
    var primarySide = 1.0;
    for (final (marker, p) in projected) {
      if (!marker.primary && primaryScreen != null && p.screen.dx >= primaryScreen.dx) primarySide = -1.0;
    }

    for (final (marker, p) in projected) {
      final color = ScenePainter.armColor(marker.arm);
      final scale = camera.scaleAt(p.depth).clamp(0.6, 1.6);
      final radius = (marker.primary ? 7.0 : 4.5) * scale;
      final double side;
      if (marker.primary) {
        side = primarySide;
      } else if (primaryScreen == null) {
        side = 1;
      } else {
        side = p.screen.dx >= primaryScreen.dx ? 1 : -1;
      }

      // Guide line down to the floor and a small foot.
      final foot = Vec3(marker.point.x, marker.point.y, 0);
      final seg = _clipSegment(camera.toView(marker.point), camera.toView(foot));
      if (seg != null) {
        final guide = Paint()
          ..color = color.withValues(alpha: 0.6)
          ..strokeWidth = 1.2
          ..isAntiAlias = true;
        final footScreen = camera.viewToScreen(seg.$2, size);
        _dashedLine(camera.viewToScreen(seg.$1, size), footScreen, guide, dash: 4, gap: 4);
        canvas.drawCircle(footScreen, 2.5 * scale, Paint()..color = color.withValues(alpha: 0.6));
      }

      canvas.drawCircle(p.screen, radius, Paint()..color = color..isAntiAlias = true);
      canvas.drawCircle(
        p.screen,
        radius,
        Paint()
          ..color = colors.surface
          ..style = PaintingStyle.stroke
          ..strokeWidth = marker.primary ? 2 : 1.5
          ..isAntiAlias = true,
      );
      canvas.drawCircle(
        p.screen,
        radius + (marker.primary ? 2.5 : 2),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..isAntiAlias = true,
      );
      if (marker.label.isNotEmpty) {
        _drawLabel(
          p.screen + Offset(side * (radius + 7), 0),
          marker.label,
          color: _dark ? color : _darken(color, 0.25),
          anchor: side > 0 ? Alignment.centerLeft : Alignment.centerRight,
          fontSize: marker.primary ? 11 : 10,
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Primitive helpers

  /// Queues a flat-shaded polygon. [normal] must be the outward normal; with
  /// [cull] faces looking away from the camera are skipped.
  void _addPolygon(
    List<Vec3> world,
    Vec3 normal,
    Color fill,
    Color edge, {
    required bool cull,
    required List<_Item> into,
  }) {
    if (cull) {
      final centroid = _centroid(world);
      if (normal.dot(camera.eye - centroid) <= 0) return;
    }
    final view = _clipNear([for (final p in world) camera.toView(p)]);
    if (view.length < 3) return;
    var depth = 0.0;
    for (final p in view) {
      depth += p.z;
    }
    depth /= view.length;
    final path = Path()..addPolygon([for (final p in view) camera.viewToScreen(p, size)], true);
    final color = _shade(fill, normal);
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final edgePaint = Paint()
      ..color = edge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    into.add(_Item(depth, (c) {
      c.drawPath(path, fillPaint);
      c.drawPath(path, edgePaint);
    }));
  }

  /// Queues a line segment whose thickness is given in millimetres.
  void _addSegment(Vec3 a, Vec3 b, Color color, {required double widthMm, required List<_Item> into}) {
    final seg = _clipSegment(camera.toView(a), camera.toView(b));
    if (seg == null) return;
    final depth = (seg.$1.z + seg.$2.z) / 2;
    final sa = camera.viewToScreen(seg.$1, size);
    final sb = camera.viewToScreen(seg.$2, size);
    final paint = Paint()
      ..color = color
      ..strokeWidth = math.max(1.5, widthMm * camera.pixelsPerMm(depth, size))
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    into.add(_Item(depth, (c) => c.drawLine(sa, sb, paint)));
  }

  /// Draws a segment immediately (no depth sorting), clipped to the near plane.
  void _drawSegmentNow(Vec3 a, Vec3 b, Paint paint) {
    final seg = _clipSegment(camera.toView(a), camera.toView(b));
    if (seg == null) return;
    canvas.drawLine(camera.viewToScreen(seg.$1, size), camera.viewToScreen(seg.$2, size), paint);
  }

  List<Offset> _clippedScreenPolygon(List<Vec3> world) {
    final view = _clipNear([for (final p in world) camera.toView(p)]);
    return [for (final p in view) camera.viewToScreen(p, size)];
  }

  /// Sutherland–Hodgman clipping of a view-space polygon against the plane
  /// `z = nearMm`.
  static List<Vec3> _clipNear(List<Vec3> pts) {
    const near = OrbitCamera.nearMm;
    final out = <Vec3>[];
    for (var i = 0; i < pts.length; i++) {
      final a = pts[i];
      final b = pts[(i + 1) % pts.length];
      final aIn = a.z >= near;
      final bIn = b.z >= near;
      if (aIn) out.add(a);
      if (aIn != bIn) out.add(a.lerp(b, (near - a.z) / (b.z - a.z)));
    }
    return out;
  }

  /// Clips a view-space segment against the near plane; null when fully behind.
  static (Vec3, Vec3)? _clipSegment(Vec3 a, Vec3 b) {
    const near = OrbitCamera.nearMm;
    final aIn = a.z >= near;
    final bIn = b.z >= near;
    if (!aIn && !bIn) return null;
    if (aIn && bIn) return (a, b);
    final u = (near - a.z) / (b.z - a.z);
    final cut = a.lerp(b, u);
    return aIn ? (a, cut) : (cut, b);
  }

  void _dashedLine(Offset a, Offset b, Paint paint, {double dash = 6, double gap = 4}) {
    final total = (b - a).distance;
    if (total <= 0 || !total.isFinite) return;
    if (total > 4000) {
      canvas.drawLine(a, b, paint);
      return;
    }
    final dir = (b - a) / total;
    var s = 0.0;
    while (s < total) {
      final e = math.min(s + dash, total);
      canvas.drawLine(a + dir * s, a + dir * e, paint);
      s = e + gap;
    }
  }

  /// Draws [text] next to [position]. [anchor] says which point of the label's
  /// box sits on [position]: e.g. [Alignment.bottomCenter] places the label
  /// above the position, [Alignment.centerLeft] to its right.
  void _drawLabel(
    Offset position,
    String text, {
    required Color color,
    required Alignment anchor,
    double fontSize = 11,
    FontWeight weight = FontWeight.w600,
    bool background = true,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize, fontWeight: weight, height: 1.2),
      ),
      textDirection: TextDirection.ltr,
      textScaler: painter.textScaler,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: math.max(40, size.width * 0.5));
    const padX = 6.0;
    const padY = 3.0;
    final w = tp.width + padX * 2;
    final h = tp.height + padY * 2;
    final left = position.dx - (anchor.x + 1) / 2 * w;
    final top = position.dy - (anchor.y + 1) / 2 * h;
    if (background) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(left, top, w, h), const Radius.circular(6)),
        Paint()..color = colors.surface.withValues(alpha: 0.85),
      );
    }
    tp.paint(canvas, Offset(left + padX, top + padY));
  }

  // ---------------------------------------------------------------------------
  // Geometry & colour helpers

  static Vec3 _centroid(List<Vec3> pts) {
    var sum = Vec3.zero;
    for (final p in pts) {
      sum = sum + p;
    }
    return sum * (1 / pts.length);
  }

  /// Normal of the polygon [pts] oriented away from [inside].
  static Vec3 _outwardNormal(List<Vec3> pts, Vec3 inside) {
    final n = (pts[1] - pts[0]).cross(pts[2] - pts[0]).normalized();
    return n.dot(_centroid(pts) - inside) < 0 ? -n : n;
  }

  static Color _shade(Color base, Vec3 normal) {
    final diffuse = math.max(0.0, normal.dot(ScenePainter.lightDir));
    final k = 0.6 + 0.4 * diffuse;
    return Color.from(alpha: base.a, red: base.r * k, green: base.g * k, blue: base.b * k);
  }

  static Color _darken(Color c, double amount) {
    final k = 1 - amount;
    return Color.from(alpha: c.a, red: c.r * k, green: c.g * k, blue: c.b * k);
  }
}
