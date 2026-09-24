// STUB — replaced by the real software-rendered 3D view (see lib/scene3d/).
import 'package:flutter/material.dart';

import '../models/scene.dart';

/// Interactive 3D view of a [Scene3D]: drag to orbit, pinch to zoom,
/// double-tap to reset. When [animateMotion] is true and the scene has a
/// [SceneMotion], the prize animates from its current to its predicted pose.
class SceneView extends StatefulWidget {
  const SceneView({
    super.key,
    required this.scene,
    this.animateMotion = true,
    this.caption,
  });

  final Scene3D scene;
  final bool animateMotion;
  final String? caption;

  @override
  State<SceneView> createState() => _SceneViewState();
}

class _SceneViewState extends State<SceneView> {
  @override
  Widget build(BuildContext context) {
    return Center(child: Text(widget.caption ?? '3D view (stub)'));
  }
}
