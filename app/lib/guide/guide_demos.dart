/// Registry of the guide demos: which demo belongs to which layout type.
library;

import '../l10n/strings.dart';
import '../models/analysis.dart';
import 'demos/bridges.dart';
import 'demos/drops.dart';
import 'demos/grabs.dart';
import 'demos/rings_hooks.dart';
import 'demos/takoyaki.dart';
import 'guide_demo.dart';

/// The demo for [type] with labels in the language of [s]; null when the
/// type has none (unknown).
GuideDemo? guideDemoFor(LayoutType type, S s) => switch (type) {
      LayoutType.bridgeParallel => bridgeParallelDemo(s),
      LayoutType.bridgeHanoji => bridgeHanojiDemo(s),
      LayoutType.bridgeStep => bridgeStepDemo(s),
      LayoutType.frontDrop => frontDropDemo(s),
      LayoutType.valleyDrop => valleyDropDemo(s),
      LayoutType.sideDrop => sideDropDemo(s),
      LayoutType.floorBox => floorBoxDemo(s),
      LayoutType.ringPera => ringPeraDemo(s),
      LayoutType.ringD => ringDDemo(s),
      LayoutType.hookS => hookSDemo(s),
      LayoutType.takoyaki => takoyakiDemo(s),
      LayoutType.threeClaw => threeClawDemo(s),
      LayoutType.twoClawDirect => twoClawDirectDemo(s),
      LayoutType.pile => pileDemo(s),
      LayoutType.unknown => null,
    };
