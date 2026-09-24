/// Photo with the aim overlay painted on top, and an edit mode where the
/// prize box, bars and top-face edge can be dragged to correct the geometry.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../engine/aim_engine.dart';
import '../l10n/strings.dart';
import '../models/analysis.dart';
import 'arm_style.dart';

/// Maps normalized image coordinates (0..1, origin top-left) to widget pixels
/// for an image drawn with `BoxFit.contain` inside [viewport].
class OverlayMapper {
  OverlayMapper({
    required this.viewport,
    required int imageWidth,
    required int imageHeight,
  }) {
    final iw = imageWidth <= 0 ? 1.0 : imageWidth.toDouble();
    final ih = imageHeight <= 0 ? 1.0 : imageHeight.toDouble();
    final scale = math.min(viewport.width / iw, viewport.height / ih);
    final dw = iw * scale;
    final dh = ih * scale;
    imageRect = Rect.fromLTWH(
      (viewport.width - dw) / 2,
      (viewport.height - dh) / 2,
      dw,
      dh,
    );
  }

  final Size viewport;

  /// Where the image pixels actually are inside the viewport (letterboxed).
  late final Rect imageRect;

  Offset toWidget(Pt p) => Offset(
        imageRect.left + p.x * imageRect.width,
        imageRect.top + p.y * imageRect.height,
      );

  Pt toNorm(Offset o) => Pt(
        imageRect.width == 0 ? 0 : (o.dx - imageRect.left) / imageRect.width,
        imageRect.height == 0 ? 0 : (o.dy - imageRect.top) / imageRect.height,
      );

  Rect boxToWidget(NBox b) => Rect.fromPoints(
        toWidget(Pt(b.x1, b.y1)),
        toWidget(Pt(b.x2, b.y2)),
      );
}

/// Draggable element under the finger while editing.
enum OverlayHandle {
  none,
  cornerTopLeft,
  cornerTopRight,
  cornerBottomLeft,
  cornerBottomRight,
  moveBox,
  frontBar,
  backBar,
  topEdge,
}

/// Shows the photo with the plan's geometry on top. In [editing] mode the
/// prize bbox corners, the whole bbox, the two bar lines and the top-face
/// edge are draggable; [onCorrectionsChanged] receives the new
/// [SceneCorrections] while dragging (throttled) and on release.
class PhotoOverlay extends StatefulWidget {
  const PhotoOverlay({
    super.key,
    required this.imageBytes,
    required this.imageWidth,
    required this.imageHeight,
    required this.plan,
    required this.corrections,
    required this.editing,
    required this.onCorrectionsChanged,
    this.otherObjects = const [],
    this.throttle = const Duration(milliseconds: 60),
    this.onZoomChanged,
  });

  final Uint8List imageBytes;
  final int imageWidth;
  final int imageHeight;
  final AimPlan plan;
  final SceneCorrections corrections;
  final bool editing;
  final ValueChanged<SceneCorrections> onCorrectionsChanged;

  /// Detected objects other than the ones in the plan, drawn faintly.
  final List<DetectedObject> otherObjects;

  /// Minimum interval between callbacks while dragging.
  final Duration throttle;

  /// Called with `true` when the viewer is zoomed in (scale > 1) and `false`
  /// when it returns to the fitted view, so a parent can stop competing
  /// horizontal gestures (e.g. a `TabBarView` swipe) while panning.
  final ValueChanged<bool>? onZoomChanged;

  /// Scale above which the view counts as zoomed.
  static const zoomThreshold = 1.01;

  /// Range allowed for the top-face ratio while dragging.
  static const topFaceRange = (0.15, 0.7);

  /// Touch radius for handles, in logical pixels.
  static const handleHitRadius = 22.0;

  @override
  State<PhotoOverlay> createState() => _PhotoOverlayState();
}

class _PhotoOverlayState extends State<PhotoOverlay> {
  final _viewerController = TransformationController();

  OverlayHandle _active = OverlayHandle.none;
  Pt? _dragStart;
  _WorkingGeometry? _work;
  _WorkingGeometry? _workStart;
  DateTime _lastEmit = DateTime.fromMillisecondsSinceEpoch(0);
  bool _zoomed = false;

  /// True while the viewer is zoomed in.
  bool get isZoomed => _zoomed;

  @override
  void initState() {
    super.initState();
    _viewerController.addListener(_onViewerChanged);
  }

  @override
  void didUpdateWidget(PhotoOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.editing && oldWidget.editing) {
      _active = OverlayHandle.none;
      _work = null;
    }
    if (widget.editing && !oldWidget.editing) {
      _viewerController.value = Matrix4.identity();
    }
  }

  @override
  void dispose() {
    _viewerController.removeListener(_onViewerChanged);
    _viewerController.dispose();
    super.dispose();
  }

  void _onViewerChanged() {
    final zoomed = _viewerController.value.getMaxScaleOnAxis() > PhotoOverlay.zoomThreshold;
    if (zoomed == _zoomed) return;
    _zoomed = zoomed;
    widget.onZoomChanged?.call(zoomed);
  }

  /// Geometry currently shown: the live drag state or the plan's overlay.
  _WorkingGeometry? _effective() {
    if (_work != null) return _work;
    final o = widget.plan.overlay;
    if (o == null) return null;
    return _WorkingGeometry.fromOverlay(o, widget.corrections);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          constraints.maxWidth.isFinite ? constraints.maxWidth : 300,
          constraints.maxHeight.isFinite ? constraints.maxHeight : 300,
        );
        final mapper = OverlayMapper(
          viewport: size,
          imageWidth: widget.imageWidth,
          imageHeight: widget.imageHeight,
        );
        final geometry = _effective();
        final painter = _OverlayPainter(
          plan: widget.plan,
          geometry: geometry,
          mapper: mapper,
          editing: widget.editing,
          activeHandle: _active,
          otherObjects: widget.otherObjects,
          strings: s,
          theme: Theme.of(context),
        );

        Widget content = SizedBox(
          width: size.width,
          height: size.height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(
                widget.imageBytes,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
              ),
              CustomPaint(painter: painter),
            ],
          ),
        );

        if (widget.editing) {
          content = GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) => _onPanStart(d.localPosition, mapper),
            onPanUpdate: (d) => _onPanUpdate(d.localPosition, mapper),
            onPanEnd: (_) => _onPanEnd(),
            onPanCancel: _onPanEnd,
            child: content,
          );
        } else {
          content = InteractiveViewer(
            transformationController: _viewerController,
            minScale: 1,
            maxScale: 4,
            clipBehavior: Clip.hardEdge,
            child: content,
          );
        }
        return ColoredBox(color: Colors.black, child: content);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Dragging

  void _onPanStart(Offset local, OverlayMapper mapper) {
    final g = _effective();
    if (g == null) return;
    final handle = _hitTest(local, g, mapper);
    if (handle == OverlayHandle.none) return;
    setState(() {
      _active = handle;
      _dragStart = mapper.toNorm(local);
      _workStart = g;
      _work = g;
    });
  }

  void _onPanUpdate(Offset local, OverlayMapper mapper) {
    final start = _dragStart;
    final base = _workStart;
    if (_active == OverlayHandle.none || start == null || base == null) return;
    final now = mapper.toNorm(local);
    final dx = now.x - start.x;
    final dy = now.y - start.y;
    final next = _applyDrag(base, _active, dx, dy, now);
    setState(() => _work = next);
    final t = DateTime.now();
    if (t.difference(_lastEmit) >= widget.throttle) {
      _lastEmit = t;
      widget.onCorrectionsChanged(next.toCorrections(widget.corrections));
    }
  }

  void _onPanEnd() {
    final w = _work;
    if (_active == OverlayHandle.none) return;
    if (w != null) {
      widget.onCorrectionsChanged(w.toCorrections(widget.corrections));
    }
    setState(() {
      _active = OverlayHandle.none;
      _dragStart = null;
      _workStart = null;
      // Keep _work until the parent's plan catches up, then drop it on the
      // next frame so we follow the recomputed overlay.
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _work = null);
    });
  }

  OverlayHandle _hitTest(Offset local, _WorkingGeometry g, OverlayMapper mapper) {
    final b = g.prizeBbox;
    final r = PhotoOverlay.handleHitRadius;
    final corners = {
      OverlayHandle.cornerTopLeft: mapper.toWidget(Pt(b.x1, b.y1)),
      OverlayHandle.cornerTopRight: mapper.toWidget(Pt(b.x2, b.y1)),
      OverlayHandle.cornerBottomLeft: mapper.toWidget(Pt(b.x1, b.y2)),
      OverlayHandle.cornerBottomRight: mapper.toWidget(Pt(b.x2, b.y2)),
    };
    for (final e in corners.entries) {
      if ((e.value - local).distance <= r) return e.key;
    }
    final topEdge = mapper.toWidget(g.topEdgeHandle);
    if ((topEdge - local).distance <= r) return OverlayHandle.topEdge;

    final fb = g.frontBar;
    if (fb != null && _nearSegment(local, mapper.toWidget(fb[0]), mapper.toWidget(fb[1]), r * 0.7)) {
      return OverlayHandle.frontBar;
    }
    final bb = g.backBar;
    if (bb != null && _nearSegment(local, mapper.toWidget(bb[0]), mapper.toWidget(bb[1]), r * 0.7)) {
      return OverlayHandle.backBar;
    }
    if (mapper.boxToWidget(b).inflate(6).contains(local)) return OverlayHandle.moveBox;
    return OverlayHandle.none;
  }

  static bool _nearSegment(Offset p, Offset a, Offset b, double tol) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    double t = len2 == 0 ? 0 : ((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2;
    t = t.clamp(0.0, 1.0);
    final proj = a + ab * t;
    return (proj - p).distance <= tol;
  }

  static _WorkingGeometry _applyDrag(
    _WorkingGeometry base,
    OverlayHandle h,
    double dx,
    double dy,
    Pt now,
  ) {
    final b = base.prizeBbox;
    const minSize = 0.02;
    switch (h) {
      case OverlayHandle.cornerTopLeft:
        return base.withBbox(NBox(
          math.min(b.x1 + dx, b.x2 - minSize),
          math.min(b.y1 + dy, b.y2 - minSize),
          b.x2,
          b.y2,
        ));
      case OverlayHandle.cornerTopRight:
        return base.withBbox(NBox(
          b.x1,
          math.min(b.y1 + dy, b.y2 - minSize),
          math.max(b.x2 + dx, b.x1 + minSize),
          b.y2,
        ));
      case OverlayHandle.cornerBottomLeft:
        return base.withBbox(NBox(
          math.min(b.x1 + dx, b.x2 - minSize),
          b.y1,
          b.x2,
          math.max(b.y2 + dy, b.y1 + minSize),
        ));
      case OverlayHandle.cornerBottomRight:
        return base.withBbox(NBox(
          b.x1,
          b.y1,
          math.max(b.x2 + dx, b.x1 + minSize),
          math.max(b.y2 + dy, b.y1 + minSize),
        ));
      case OverlayHandle.moveBox:
        // Keep the box fully inside the image while moving.
        final mx = dx.clamp(-b.x1, 1 - b.x2);
        final my = dy.clamp(-b.y1, 1 - b.y2);
        return base.withBbox(NBox(b.x1 + mx, b.y1 + my, b.x2 + mx, b.y2 + my));
      case OverlayHandle.frontBar:
        final fb = base.frontBar;
        if (fb == null) return base;
        return base.copyWith(frontBar: _shiftLine(fb, dy), frontBarEdited: true);
      case OverlayHandle.backBar:
        final bb = base.backBar;
        if (bb == null) return base;
        return base.copyWith(backBar: _shiftLine(bb, dy), backBarEdited: true);
      case OverlayHandle.topEdge:
        final h = b.height;
        if (h <= 0) return base;
        final ratio = ((now.y - b.y1) / h)
            .clamp(PhotoOverlay.topFaceRange.$1, PhotoOverlay.topFaceRange.$2);
        return base.withRatio(ratio);
      case OverlayHandle.none:
        return base;
    }
  }

  static List<Pt> _shiftLine(List<Pt> line, double dy) {
    final y0 = (line[0].y + dy).clamp(0.0, 1.0);
    final y1 = (line[1].y + dy).clamp(0.0, 1.0);
    return [Pt(line[0].x, y0), Pt(line[1].x, y1)];
  }
}

/// Geometry being edited (or the plan's overlay when idle).
class _WorkingGeometry {
  const _WorkingGeometry({
    required this.prizeBbox,
    required this.topFaceRatio,
    required this.topFace,
    required this.frontBar,
    required this.backBar,
    required this.dropHole,
    required this.claw,
    required this.motionFrom,
    required this.motionTo,
    required this.barsSynthesized,
    this.bboxEdited = false,
    this.ratioEdited = false,
    this.frontBarEdited = false,
    this.backBarEdited = false,
  });

  factory _WorkingGeometry.fromOverlay(OverlayGeometry o, SceneCorrections c) {
    final b = o.prizeBbox;
    double ratio;
    if (c.topFaceRatio != null) {
      ratio = c.topFaceRatio!;
    } else if (o.topFace.isNotEmpty && b.height > 0) {
      ratio = ((o.topFace[0].y - b.y1) / b.height).clamp(0.05, 0.95);
    } else {
      ratio = 0.35;
    }
    return _WorkingGeometry(
      prizeBbox: b,
      topFaceRatio: ratio,
      topFace: o.topFace.length == 4 ? o.topFace : topFaceFor(b, ratio),
      frontBar: o.frontBar,
      backBar: o.backBar,
      dropHole: o.dropHole,
      claw: o.claw,
      motionFrom: o.motionFrom,
      motionTo: o.motionTo,
      barsSynthesized: o.barsSynthesized,
    );
  }

  final NBox prizeBbox;
  final double topFaceRatio;
  final List<Pt> topFace;
  final List<Pt>? frontBar;
  final List<Pt>? backBar;
  final NBox? dropHole;
  final NBox? claw;
  final Pt? motionFrom;
  final Pt? motionTo;
  final bool barsSynthesized;
  final bool bboxEdited;
  final bool ratioEdited;
  final bool frontBarEdited;
  final bool backBarEdited;

  /// Same construction as the engine: a trapezoid whose lower edge sits at
  /// `y1 + ratio * height` and whose upper edge is inset by 5 %.
  static List<Pt> topFaceFor(NBox b, double ratio) {
    final y = b.y1 + b.height * ratio;
    final inset = b.width * 0.05;
    return [
      Pt(b.x1, y),
      Pt(b.x2, y),
      Pt(b.x2 - inset, b.y1),
      Pt(b.x1 + inset, b.y1),
    ];
  }

  /// Midpoint of the top-face lower edge: the drag handle for the ratio.
  Pt get topEdgeHandle => Pt(prizeBbox.cx, prizeBbox.y1 + prizeBbox.height * topFaceRatio);

  _WorkingGeometry withBbox(NBox b) => copyWith(
        prizeBbox: b,
        topFace: topFaceFor(b, topFaceRatio),
        bboxEdited: true,
      );

  _WorkingGeometry withRatio(double r) => copyWith(
        topFaceRatio: r,
        topFace: topFaceFor(prizeBbox, r),
        ratioEdited: true,
      );

  _WorkingGeometry copyWith({
    NBox? prizeBbox,
    double? topFaceRatio,
    List<Pt>? topFace,
    List<Pt>? frontBar,
    List<Pt>? backBar,
    bool? bboxEdited,
    bool? ratioEdited,
    bool? frontBarEdited,
    bool? backBarEdited,
  }) =>
      _WorkingGeometry(
        prizeBbox: prizeBbox ?? this.prizeBbox,
        topFaceRatio: topFaceRatio ?? this.topFaceRatio,
        topFace: topFace ?? this.topFace,
        frontBar: frontBar ?? this.frontBar,
        backBar: backBar ?? this.backBar,
        dropHole: dropHole,
        claw: claw,
        motionFrom: motionFrom,
        motionTo: motionTo,
        barsSynthesized: barsSynthesized,
        bboxEdited: bboxEdited ?? this.bboxEdited,
        ratioEdited: ratioEdited ?? this.ratioEdited,
        frontBarEdited: frontBarEdited ?? this.frontBarEdited,
        backBarEdited: backBarEdited ?? this.backBarEdited,
      );

  /// Folds the edited fields into [base]; untouched fields keep their value.
  SceneCorrections toCorrections(SceneCorrections base) {
    NBox? barBox(List<Pt> line) => NBox(line[0].x, line[0].y - 0.012, line[1].x, line[1].y + 0.012).normalized();
    return SceneCorrections(
      prizeBbox: bboxEdited ? prizeBbox.normalized() : base.prizeBbox,
      topFaceRatio: ratioEdited ? topFaceRatio : base.topFaceRatio,
      frontBar: frontBarEdited && frontBar != null ? barBox(frontBar!) : base.frontBar,
      backBar: backBarEdited && backBar != null ? barBox(backBar!) : base.backBar,
      dropHole: base.dropHole,
      claw: base.claw,
      yawDeg: base.yawDeg,
      boxYOffsetMm: base.boxYOffsetMm,
    );
  }
}

// -----------------------------------------------------------------------------
// Painter

class _OverlayPainter extends CustomPainter {
  _OverlayPainter({
    required this.plan,
    required this.geometry,
    required this.mapper,
    required this.editing,
    required this.activeHandle,
    required this.otherObjects,
    required this.strings,
    required this.theme,
  });

  final AimPlan plan;
  final _WorkingGeometry? geometry;
  final OverlayMapper mapper;
  final bool editing;
  final OverlayHandle activeHandle;
  final List<DetectedObject> otherObjects;
  final S strings;
  final ThemeData theme;

  static const _prizeColor = Color(0xFFFFD84D);
  static const _barColor = Color(0xFF4DD9FF);
  static const _holeColor = Color(0xFFFF3B3B);
  static const _clawColor = Color(0xFFE0E0E0);
  static const _motionColor = Color(0xFFFF5FD2);
  static const _faintColor = Color(0x88FFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(mapper.imageRect);
    _paintOtherObjects(canvas);
    final g = geometry;
    if (g != null) {
      _paintDropHole(canvas, g);
      _paintClawBox(canvas, g);
      _paintBars(canvas, g);
      _paintPrize(canvas, g);
      _paintMotion(canvas, g);
      _paintCurrentStep(canvas);
      if (editing) _paintHandles(canvas, g);
    }
    canvas.restore();
  }

  void _paintOtherObjects(Canvas canvas) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = _faintColor;
    for (final o in otherObjects) {
      final r = mapper.boxToWidget(o.bbox);
      canvas.drawRect(r, paint);
      _label(canvas, o.id, r.topLeft + const Offset(2, 2), _faintColor, small: true);
    }
  }

  void _paintDropHole(Canvas canvas, _WorkingGeometry g) {
    final h = g.dropHole;
    if (h == null) return;
    final r = mapper.boxToWidget(h);
    canvas.drawRect(r, Paint()..color = _holeColor.withValues(alpha: 0.18));
    canvas.drawRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = _holeColor.withValues(alpha: 0.8),
    );
    _label(canvas, strings.labelDropHole, r.bottomLeft + const Offset(4, -18), _holeColor);
  }

  void _paintClawBox(Canvas canvas, _WorkingGeometry g) {
    final c = g.claw;
    if (c == null) return;
    final r = mapper.boxToWidget(c);
    canvas.drawRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = _clawColor.withValues(alpha: 0.8),
    );
    _label(canvas, strings.labelClaw, r.topLeft + const Offset(4, 4), _clawColor, small: true);
  }

  void _paintBars(Canvas canvas, _WorkingGeometry g) {
    final dashed = g.barsSynthesized;
    void bar(List<Pt>? line, String label, bool active) {
      if (line == null || line.length < 2) return;
      final a = mapper.toWidget(line[0]);
      final b = mapper.toWidget(line[1]);
      final paint = Paint()
        ..color = active ? Colors.white : _barColor
        ..strokeWidth = active ? 4 : 3
        ..strokeCap = StrokeCap.round;
      if (dashed) {
        _dashedLine(canvas, a, b, paint, dash: 10, gap: 7);
      } else {
        canvas.drawLine(a, b, paint);
      }
      _label(canvas, dashed ? '$label · ${strings.estimated}' : label, a + const Offset(4, 6), _barColor);
    }

    bar(g.backBar, strings.labelBackBar, activeHandle == OverlayHandle.backBar);
    bar(g.frontBar, strings.labelFrontBar, activeHandle == OverlayHandle.frontBar);
  }

  void _paintPrize(Canvas canvas, _WorkingGeometry g) {
    final r = mapper.boxToWidget(g.prizeBbox);
    canvas.drawRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _prizeColor,
    );
    if (g.topFace.length == 4) {
      final path = Path()..moveTo(mapper.toWidget(g.topFace[0]).dx, mapper.toWidget(g.topFace[0]).dy);
      for (var i = 1; i < 4; i++) {
        final p = mapper.toWidget(g.topFace[i]);
        path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = _prizeColor.withValues(alpha: 0.28));
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = _prizeColor,
      );
    }
    _label(canvas, strings.labelPrize, r.bottomLeft + const Offset(4, -18), _prizeColor);
  }

  void _paintMotion(Canvas canvas, _WorkingGeometry g) {
    final from = g.motionFrom;
    final to = g.motionTo;
    if (from == null || to == null) return;
    final a = mapper.toWidget(from);
    final b = mapper.toWidget(to);
    if ((b - a).distance < 2) return;
    final paint = Paint()
      ..color = _motionColor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(a, b, paint);
    _arrowHead(canvas, a, b, paint..style = PaintingStyle.fill, 12);
    _label(canvas, strings.labelMotion, b + const Offset(8, -8), _motionColor, small: true);
  }

  void _paintCurrentStep(Canvas canvas) {
    final step = plan.current;
    if (step == null) return;
    final color = armColor(step.arm);
    final claw = mapper.toWidget(step.clawPoint);
    final tip = mapper.toWidget(step.tipPoint);

    // Connector.
    canvas.drawLine(
      claw,
      tip,
      Paint()
        ..color = color.withValues(alpha: 0.7)
        ..strokeWidth = 1.5,
    );

    // Tip dot.
    canvas.drawCircle(tip, 7, Paint()..color = color);
    canvas.drawCircle(
      tip,
      7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
    _label(canvas, strings.labelTip, tip + const Offset(10, 6), color, small: true);

    // Claw centre target: ring + crosshair + halo.
    const ring = 20.0;
    canvas.drawCircle(claw, ring + 6, Paint()..color = color.withValues(alpha: 0.18));
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = color;
    canvas.drawCircle(claw, ring, stroke);
    canvas.drawCircle(
      claw,
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.9),
    );
    for (final d in const [Offset(1, 0), Offset(-1, 0), Offset(0, 1), Offset(0, -1)]) {
      canvas.drawLine(claw + d * (ring - 6), claw + d * (ring + 10), stroke);
    }
    canvas.drawCircle(claw, 3, Paint()..color = Colors.white);
    _label(
      canvas,
      '${strings.labelClawCenter} · ${strings.armShort(step.arm)}',
      claw + const Offset(ring + 12, -ring),
      color,
    );
  }

  void _paintHandles(Canvas canvas, _WorkingGeometry g) {
    final b = g.prizeBbox;
    final corners = {
      OverlayHandle.cornerTopLeft: Pt(b.x1, b.y1),
      OverlayHandle.cornerTopRight: Pt(b.x2, b.y1),
      OverlayHandle.cornerBottomLeft: Pt(b.x1, b.y2),
      OverlayHandle.cornerBottomRight: Pt(b.x2, b.y2),
    };
    for (final e in corners.entries) {
      _handle(canvas, mapper.toWidget(e.value), active: activeHandle == e.key, color: _prizeColor);
    }
    _handle(
      canvas,
      mapper.toWidget(g.topEdgeHandle),
      active: activeHandle == OverlayHandle.topEdge,
      color: _prizeColor,
      diamond: true,
    );
    _label(canvas, strings.labelTopFace, mapper.toWidget(g.topEdgeHandle) + const Offset(14, -8), _prizeColor, small: true);
    for (final entry in {
      OverlayHandle.frontBar: g.frontBar,
      OverlayHandle.backBar: g.backBar,
    }.entries) {
      final line = entry.value;
      if (line == null) continue;
      final mid = mapper.toWidget(Pt((line[0].x + line[1].x) / 2, (line[0].y + line[1].y) / 2));
      _handle(canvas, mid, active: activeHandle == entry.key, color: _barColor, square: true);
    }
    if (activeHandle == OverlayHandle.moveBox) {
      canvas.drawRect(
        mapper.boxToWidget(b),
        Paint()..color = _prizeColor.withValues(alpha: 0.12),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Primitives

  void _handle(
    Canvas canvas,
    Offset c, {
    required bool active,
    required Color color,
    bool diamond = false,
    bool square = false,
  }) {
    final r = active ? 12.0 : 9.0;
    final fill = Paint()..color = active ? color : Colors.white;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = active ? Colors.white : color;
    if (diamond) {
      final p = Path()
        ..moveTo(c.dx, c.dy - r)
        ..lineTo(c.dx + r, c.dy)
        ..lineTo(c.dx, c.dy + r)
        ..lineTo(c.dx - r, c.dy)
        ..close();
      canvas.drawPath(p, fill);
      canvas.drawPath(p, stroke);
    } else if (square) {
      final rect = Rect.fromCenter(center: c, width: r * 2, height: r * 2);
      canvas.drawRect(rect, fill);
      canvas.drawRect(rect, stroke);
    } else {
      canvas.drawCircle(c, r, fill);
      canvas.drawCircle(c, r, stroke);
    }
  }

  void _arrowHead(Canvas canvas, Offset from, Offset to, Paint paint, double size) {
    final dir = (to - from);
    final len = dir.distance;
    if (len == 0) return;
    final u = dir / len;
    final n = Offset(-u.dy, u.dx);
    final base = to - u * size;
    final path = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(base.dx + n.dx * size * 0.55, base.dy + n.dy * size * 0.55)
      ..lineTo(base.dx - n.dx * size * 0.55, base.dy - n.dy * size * 0.55)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, Paint paint, {double dash = 8, double gap = 6}) {
    final total = (b - a).distance;
    if (total == 0) return;
    final u = (b - a) / total;
    var d = 0.0;
    while (d < total) {
      final e = math.min(d + dash, total);
      canvas.drawLine(a + u * d, a + u * e, paint);
      d = e + gap;
    }
  }

  void _label(Canvas canvas, String text, Offset at, Color color, {bool small = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: (theme.textTheme.bodySmall ?? const TextStyle()).copyWith(
          color: Colors.white,
          fontSize: small ? 10 : 12,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: math.max(40, mapper.imageRect.width - 8));
    var x = at.dx;
    var y = at.dy;
    final w = tp.width + 8;
    final h = tp.height + 4;
    final r = mapper.imageRect;
    if (x + w > r.right) x = r.right - w;
    if (x < r.left) x = r.left;
    if (y + h > r.bottom) y = r.bottom - h;
    if (y < r.top) y = r.top;
    final rect = RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), const Radius.circular(4));
    canvas.drawRRect(rect, Paint()..color = Colors.black.withValues(alpha: 0.6));
    canvas.drawRRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color.withValues(alpha: 0.9),
    );
    tp.paint(canvas, Offset(x + 4, y + 2));
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter old) =>
      old.plan != plan ||
      old.geometry != geometry ||
      old.mapper.imageRect != mapper.imageRect ||
      old.editing != editing ||
      old.activeHandle != activeHandle ||
      old.otherObjects != otherObjects ||
      old.strings.locale != strings.locale;
}
