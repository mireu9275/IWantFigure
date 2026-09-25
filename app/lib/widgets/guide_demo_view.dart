/// Looping 3D motion demo of a layout type (guide page, 움직임으로 보기).
library;

import 'package:flutter/material.dart';

import '../guide/guide_demo.dart';
import '../l10n/strings.dart';
import '../scene3d/projection.dart';
import '../scene3d/scene_painter.dart';
import '../scene3d/timeline.dart';

/// Plays [demo] in a loop and publishes the guide step on screen to [step].
///
/// Drag to orbit, pinch to zoom, double-tap to reset the view (as in the
/// result screen's 3D tab). The current step's text from [steps] is shown
/// under the view unless [showCaption] is false (the page hides it when the
/// view is shrunk). Starts paused when the platform asks for
/// reduced motion. Use [GuideDemoViewState.seekToStep] to jump to a step.
class GuideDemoView extends StatefulWidget {
  const GuideDemoView({super.key, required this.demo, required this.steps, this.step, this.showCaption = true});

  final GuideDemo demo;

  /// The guide's "How to aim" texts; a demo segment's step indexes this list.
  final List<String> steps;

  /// Receives the step on screen (-1 before the first one).
  final ValueNotifier<int>? step;

  final bool showCaption;

  @override
  State<GuideDemoView> createState() => GuideDemoViewState();
}

class GuideDemoViewState extends State<GuideDemoView> with SingleTickerProviderStateMixin {
  static const double _yawDegPerPx = 0.5;
  static const double _pitchDegPerPx = 0.35;

  late final AnimationController _controller;
  late OrbitCamera _camera;
  OrbitCamera? _gestureStartCamera;
  bool _playing = true;
  bool _started = false;

  SceneTimeline get _timeline => widget.demo.timeline;
  double get _ms => _controller.value * _timeline.totalMs;

  /// Whether the animation is running.
  bool get playing => _playing;

  /// Current time in the demo's timeline (ms).
  double get positionMs => _ms;

  @override
  void initState() {
    super.initState();
    _camera = OrbitCamera.fromHint(_timeline.stage.camera);
    _controller = AnimationController(vsync: this, duration: _timeline.duration)..addListener(_publishStep);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _playing = !MediaQuery.disableAnimationsOf(context);
    if (_playing) _controller.repeat();
    // Listeners (the page's step highlight) must not rebuild during this build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _publishStep();
    });
  }

  @override
  void didUpdateWidget(GuideDemoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.demo.type != widget.demo.type || oldWidget.demo.timeline.totalMs != _timeline.totalMs) {
      _camera = OrbitCamera.fromHint(_timeline.stage.camera);
      _controller.duration = _timeline.duration;
      _controller.value = 0;
      if (_playing) _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _publishStep() {
    final notifier = widget.step;
    if (notifier == null) return;
    final step = _timeline.frameAt(_ms).step;
    if (notifier.value != step) notifier.value = step;
  }

  /// Jumps to the first moment that shows [step] and plays from there.
  /// Returns false when the demo does not illustrate that step.
  bool seekToStep(int step) {
    final start = _timeline.startOfStep(step);
    if (start == null) return false;
    setState(() {
      _controller.value = start / _timeline.totalMs;
      _playing = true;
      _controller.repeat();
    });
    return true;
  }

  void _togglePlay() {
    setState(() {
      _playing = !_playing;
      if (_playing) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    });
  }

  void _replay() {
    setState(() {
      _controller.value = 0;
      _playing = true;
      _controller.repeat();
    });
  }

  void _resetCamera() => setState(() => _camera = OrbitCamera.fromHint(_timeline.stage.camera));

  void _onScaleStart(ScaleStartDetails details) => _gestureStartCamera = _camera;

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final OrbitCamera next;
    if (details.pointerCount <= 1) {
      next = _camera.copyWith(
        yawDeg: _camera.yawDeg - details.focalPointDelta.dx * _yawDegPerPx,
        pitchDeg: _camera.pitchDeg + details.focalPointDelta.dy * _pitchDegPerPx,
      );
    } else {
      final start = _gestureStartCamera ?? _camera;
      final scale = details.scale <= 0 ? 1.0 : details.scale;
      next = _camera.copyWith(distanceMm: start.distanceMm / scale);
    }
    if (next != _camera) setState(() => _camera = next);
  }

  void _onScaleEnd(ScaleEndDetails details) => _gestureStartCamera = null;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final labels = SceneLabels(
      dropHole: s.labelDropHole,
      front: s.sceneFront,
      resetView: s.resetView,
      playMotion: s.guideDemoPlay,
      pauseMotion: s.guideDemoPause,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ColoredBox(
        color: colors.surfaceContainerLow,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Buttons are siblings above the detector so the double-tap
                  // recognizer does not delay their taps (see SceneView).
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onScaleStart: _onScaleStart,
                    onScaleUpdate: _onScaleUpdate,
                    onScaleEnd: _onScaleEnd,
                    onDoubleTap: _resetCamera,
                    child: Semantics(
                      label: s.guideDemoTitle,
                      image: true,
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) => CustomPaint(
                          willChange: _controller.isAnimating,
                          painter: ScenePainter(
                            scene: _timeline.sceneAt(_ms),
                            camera: _camera,
                            colors: colors,
                            textScaler: MediaQuery.textScalerOf(context),
                            labels: labels,
                            textStyle: theme.textTheme.bodySmall,
                          ),
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
                        _button(
                          _playing ? s.guideDemoPause : s.guideDemoPlay,
                          _playing ? Icons.pause : Icons.play_arrow,
                          _togglePlay,
                        ),
                        const SizedBox(width: 4),
                        _button(s.guideDemoReplay, Icons.replay, _replay),
                        const SizedBox(width: 4),
                        _button(s.resetView, Icons.center_focus_weak, _resetCamera),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => LinearProgressIndicator(
                value: _controller.value,
                minHeight: 3,
                backgroundColor: colors.surfaceContainerHighest,
              ),
            ),
            if (widget.showCaption) _caption(context),
          ],
        ),
      ),
    );
  }

  Widget _button(String tooltip, IconData icon, VoidCallback onPressed) => IconButton.filledTonal(
    tooltip: tooltip,
    visualDensity: VisualDensity.compact,
    iconSize: 20,
    onPressed: onPressed,
    icon: Icon(icon),
  );

  /// The current step's number and text under the view, always two lines
  /// tall so the view does not jump when the text changes.
  Widget _caption(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final style = theme.textTheme.bodySmall?.copyWith(color: colors.onSurface);
    final lineHeight = MediaQuery.textScalerOf(context).scale(style?.fontSize ?? 12) * (style?.height ?? 1.35);
    final notifier = widget.step;
    Widget row(int step) {
      final shown = step >= 0 && step < widget.steps.length;
      return Container(
        height: lineHeight * 2 + 16,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        color: colors.surfaceContainer,
        child: !shown
            ? null
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: colors.primary,
                    child: Text(
                      '${step + 1}',
                      style: TextStyle(fontSize: 11, color: colors.onPrimary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(widget.steps[step], maxLines: 2, overflow: TextOverflow.ellipsis, style: style),
                  ),
                ],
              ),
      );
    }

    if (notifier != null) {
      return ValueListenableBuilder<int>(valueListenable: notifier, builder: (context, step, _) => row(step));
    }
    return AnimatedBuilder(animation: _controller, builder: (context, _) => row(_timeline.frameAt(_ms).step));
  }
}
