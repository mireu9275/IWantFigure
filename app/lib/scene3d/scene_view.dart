/// Interactive, software-rendered 3D view of a [Scene3D].
library;

import 'package:flutter/material.dart';

import '../models/scene.dart';
import 'projection.dart';
import 'scene_painter.dart';

/// Interactive 3D view of a [Scene3D]: drag to orbit, pinch to zoom,
/// double-tap to reset. When [animateMotion] is true and the scene has a
/// [SceneMotion], the prize animates from its current to its predicted pose.
///
/// The view fills the space its parent gives it (when the height is
/// unbounded it falls back to a 4:3 box). [caption] and the motion's
/// description are shown in a translucent card at the bottom. [labels]
/// localizes the in-scene texts and the button tooltips.
class SceneView extends StatefulWidget {
  const SceneView({
    super.key,
    required this.scene,
    this.animateMotion = true,
    this.caption,
    this.labels = SceneLabels.defaults,
  });

  final Scene3D scene;
  final bool animateMotion;
  final String? caption;
  final SceneLabels labels;

  @override
  State<SceneView> createState() => _SceneViewState();
}

class _SceneViewState extends State<SceneView> with SingleTickerProviderStateMixin {
  /// Duration of the ease-in-out move from the current to the predicted pose.
  static const Duration motionDuration = Duration(milliseconds: 1600);

  /// Time the predicted pose is held before the animation jumps back.
  static const Duration holdDuration = Duration(milliseconds: 800);

  static const double _yawDegPerPx = 0.5;
  static const double _pitchDegPerPx = 0.35;

  late OrbitCamera _camera;
  late final AnimationController _controller;
  late final Animation<double> _t;
  late bool _animationEnabled;
  OrbitCamera? _gestureStartCamera;

  @override
  void initState() {
    super.initState();
    _camera = OrbitCamera.fromHint(widget.scene.camera);
    _animationEnabled = widget.animateMotion;
    _controller = AnimationController(vsync: this, duration: motionDuration + holdDuration);
    _t = _controller.drive(
      TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween<double>(begin: 0, end: 1).chain(CurveTween(curve: Curves.easeInOut)),
          weight: motionDuration.inMilliseconds.toDouble(),
        ),
        TweenSequenceItem(
          tween: ConstantTween<double>(1),
          weight: holdDuration.inMilliseconds.toDouble(),
        ),
      ]),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(SceneView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameHint(oldWidget.scene.camera, widget.scene.camera)) {
      _camera = OrbitCamera.fromHint(widget.scene.camera);
    }
    final motionChanged = !_sameMotion(oldWidget.scene.motion, widget.scene.motion);
    if (oldWidget.animateMotion != widget.animateMotion) {
      _animationEnabled = widget.animateMotion;
    }
    if (motionChanged) _controller.reset();
    _syncAnimation();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Starts or stops the repeating animation according to the current state.
  void _syncAnimation() {
    final shouldRun = _animationEnabled && widget.scene.motion != null;
    if (shouldRun) {
      if (!_controller.isAnimating) _controller.repeat();
    } else if (_controller.isAnimating) {
      _controller.stop();
    }
  }

  void _resetCamera() {
    setState(() => _camera = OrbitCamera.fromHint(widget.scene.camera));
  }

  void _toggleAnimation() {
    setState(() {
      _animationEnabled = !_animationEnabled;
      _syncAnimation();
    });
  }

  void _onScaleStart(ScaleStartDetails details) {
    _gestureStartCamera = _camera;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final OrbitCamera next;
    if (details.pointerCount <= 1) {
      // One finger: orbit. Dragging right turns the scene to the right,
      // dragging down looks more from above.
      next = _camera.copyWith(
        yawDeg: _camera.yawDeg - details.focalPointDelta.dx * _yawDegPerPx,
        pitchDeg: _camera.pitchDeg + details.focalPointDelta.dy * _pitchDegPerPx,
      );
    } else {
      // Two fingers: pinch to zoom, relative to the distance at gesture start.
      final start = _gestureStartCamera ?? _camera;
      final scale = details.scale <= 0 ? 1.0 : details.scale;
      next = _camera.copyWith(distanceMm: start.distanceMm / scale);
    }
    if (next != _camera) setState(() => _camera = next);
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _gestureStartCamera = null;
  }

  static bool _sameHint(CameraHint a, CameraHint b) =>
      a.yawDeg == b.yawDeg && a.pitchDeg == b.pitchDeg && a.distanceMm == b.distanceMm && a.target == b.target;

  static bool _samePose(Pose a, Pose b) =>
      a.position == b.position &&
      a.rotation.yawDeg == b.rotation.yawDeg &&
      a.rotation.pitchDeg == b.rotation.pitchDeg &&
      a.rotation.rollDeg == b.rotation.rollDeg;

  static bool _sameMotion(SceneMotion? a, SceneMotion? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    return a.boxId == b.boxId && _samePose(a.from, b.from) && _samePose(a.to, b.to);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textScaler = MediaQuery.textScalerOf(context);
    final motion = widget.scene.motion;
    final caption = widget.caption;
    final captionLines = <Widget>[
      if (caption != null && caption.isNotEmpty)
        Text(caption, style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurface)),
      if (motion != null && motion.description.isNotEmpty)
        Text(
          motion.description,
          style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth ? constraints.maxWidth : 360.0;
        final height = constraints.hasBoundedHeight ? constraints.maxHeight : width * 0.75;
        final size = Size(width, height);
        return SizedBox(
          width: width,
          height: height,
          child: ClipRect(
            child: DecoratedBox(
              decoration: BoxDecoration(color: colors.surfaceContainerLow),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // The overlay buttons are siblings above the detector rather
                  // than its children, so their taps are not held back by the
                  // double-tap recognizer.
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onScaleStart: _onScaleStart,
                    onScaleUpdate: _onScaleUpdate,
                    onScaleEnd: _onScaleEnd,
                    onDoubleTap: _resetCamera,
                    child: AnimatedBuilder(
                      animation: _t,
                      builder: (context, _) => CustomPaint(
                        size: size,
                        willChange: _controller.isAnimating,
                        painter: ScenePainter(
                          scene: widget.scene,
                          camera: _camera,
                          colors: colors,
                          t: motion == null ? 0 : _t.value,
                          textScaler: textScaler,
                          labels: widget.labels,
                          textStyle: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (motion != null)
                          IconButton.filledTonal(
                            tooltip: _animationEnabled ? widget.labels.pauseMotion : widget.labels.playMotion,
                            visualDensity: VisualDensity.compact,
                            iconSize: 20,
                            onPressed: _toggleAnimation,
                            icon: Icon(_animationEnabled ? Icons.pause : Icons.play_arrow),
                          ),
                        IconButton.filledTonal(
                          tooltip: widget.labels.resetView,
                          visualDensity: VisualDensity.compact,
                          iconSize: 20,
                          onPressed: _resetCamera,
                          icon: const Icon(Icons.center_focus_weak),
                        ),
                      ],
                    ),
                  ),
                  if (captionLines.isNotEmpty)
                    Positioned(
                      left: 8,
                      right: 8,
                      bottom: 8,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: colors.surface.withValues(alpha: 0.82),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: captionLines,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
