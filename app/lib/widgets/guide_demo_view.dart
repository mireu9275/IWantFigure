/// 3D motion demo of a layout type (guide page, 움직임으로 보기).
library;

import 'package:flutter/material.dart';

import '../guide/guide_demo.dart';
import '../l10n/strings.dart';
import '../scene3d/projection.dart';
import '../scene3d/scene_painter.dart';
import '../scene3d/timeline.dart';

/// Plays [demo] and publishes the guide step on screen to [step].
///
/// Two ways to watch: the play button runs the whole demo in a loop; a step
/// number, the previous/next buttons or "replay this step" play just that
/// step once and stop at its end, so a scene can be watched again. The page
/// calls [GuideDemoViewState.playStep] when a How-to step is tapped.
///
/// Drag to orbit, pinch to zoom, double-tap to reset the view (as in the
/// result screen's 3D tab). When [expanded] is true the step bar and the
/// current step's text from [steps] are shown under the view (the page hides
/// them while the view is shrunk). Starts paused when the platform asks for
/// reduced motion.
class GuideDemoView extends StatefulWidget {
  const GuideDemoView({super.key, required this.demo, required this.steps, this.step, this.expanded = true});

  final GuideDemo demo;

  /// The guide's "How to aim" texts; a demo segment's step indexes this list.
  final List<String> steps;

  /// Receives the step on screen (-1 before the first one).
  final ValueNotifier<int>? step;

  final bool expanded;

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

  /// Bumped by every play/stop command so a finished single-step run does
  /// not override a newer command.
  int _run = 0;

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

  /// Plays only [step] (its first stretch in the demo) and stops at its end.
  /// Returns false when the demo does not illustrate that step.
  bool playStep(int step) {
    final range = _timeline.rangeOfStep(step);
    if (range == null) return false;
    final (start, rangeEnd) = range;
    // Stop just inside the step: at its exact end the next step begins.
    final end = rangeEnd - 1;
    final total = _timeline.totalMs;
    final run = ++_run;
    setState(() {
      _playing = true;
      _controller.value = start / total;
      _controller
          .animateTo(end / total, duration: Duration(milliseconds: end - start), curve: Curves.linear)
          .whenCompleteOrCancel(() {
        if (mounted && run == _run) setState(() => _playing = false);
      });
    });
    return true;
  }

  /// Play: run the whole demo in a loop from here. Pause: stop.
  void _togglePlay() {
    _run++;
    setState(() {
      _playing = !_playing;
      if (_playing) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
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
            if (widget.expanded) ...[_stepBar(context, s), _caption(context)],
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

  /// Previous / numbered steps / next / replay this step.
  Widget _stepBar(BuildContext context, S s) {
    final colors = Theme.of(context).colorScheme;
    final steps = _timeline.steps;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final current = _timeline.frameAt(_ms).step;
        final index = steps.indexOf(current);
        final prev = index > 0 ? steps[index - 1] : null;
        final next = index < 0 ? steps.first : (index < steps.length - 1 ? steps[index + 1] : null);
        return Row(
          children: [
            IconButton(
              tooltip: s.guideDemoPrevStep,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.skip_previous),
              onPressed: prev == null ? null : () => playStep(prev),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final step in steps)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: _stepDot(s, colors, step, active: step == current),
                      ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: s.guideDemoNextStep,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.skip_next),
              onPressed: next == null ? null : () => playStep(next),
            ),
            IconButton(
              tooltip: s.guideDemoReplayStep,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.replay),
              onPressed: current < 0 ? null : () => playStep(current),
            ),
          ],
        );
      },
    );
  }

  Widget _stepDot(S s, ColorScheme colors, int step, {required bool active}) => Tooltip(
        message: s.guideDemoShowStep(step + 1),
        child: InkResponse(
          onTap: () => playStep(step),
          radius: 18,
          child: Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? colors.primary : colors.surface,
              border: Border.all(color: colors.primary),
            ),
            child: Text(
              '${step + 1}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: active ? colors.onPrimary : colors.primary,
              ),
            ),
          ),
        ),
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
