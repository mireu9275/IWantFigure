/// Bottom sheet for the prize dimensions and the box position corrections.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../engine/inputs.dart';
import '../l10n/strings.dart';
import '../services/session_controller.dart';
import '../services/settings.dart';

/// Opens the prize sheet bound to [controller].
Future<void> showPrizeSheet(BuildContext context, SessionController controller) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: PrizeSheet(controller: controller),
    ),
  );
}

/// Presets, numeric fields and the position sliders. Every change is applied
/// to the controller immediately.
class PrizeSheet extends StatefulWidget {
  const PrizeSheet({super.key, required this.controller});

  final SessionController controller;

  static const yOffsetRange = (-80.0, 80.0);
  static const topFaceRange = (0.15, 0.7);
  static const yawRange = (-45.0, 45.0);

  @override
  State<PrizeSheet> createState() => _PrizeSheetState();
}

class _PrizeSheetState extends State<PrizeSheet> {
  late final TextEditingController _w;
  late final TextEditingController _d;
  late final TextEditingController _h;
  late final TextEditingController _m;

  SessionController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    final p = c.prize;
    _w = TextEditingController(text: _fmt(p.widthMm));
    _d = TextEditingController(text: _fmt(p.depthMm));
    _h = TextEditingController(text: _fmt(p.heightMm));
    _m = TextEditingController(text: p.massG == null ? '' : _fmt(p.massG!));
  }

  @override
  void dispose() {
    _w.dispose();
    _d.dispose();
    _h.dispose();
    _m.dispose();
    super.dispose();
  }

  static String _fmt(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

  void _applyPreset(PrizePreset preset) {
    final p = preset.spec;
    c.setPrize(p);
    _w.text = _fmt(p.widthMm);
    _d.text = _fmt(p.depthMm);
    _h.text = _fmt(p.heightMm);
    _m.text = p.massG == null ? '' : _fmt(p.massG!);
    setState(() {});
  }

  void _applyFields() {
    double? parse(String t) => double.tryParse(t.trim());
    final p = c.prize;
    c.setPrize(p.copyWith(
      name: 'custom',
      widthMm: parse(_w.text)?.clamp(20, 600) ?? p.widthMm,
      depthMm: parse(_d.text)?.clamp(20, 600) ?? p.depthMm,
      heightMm: parse(_h.text)?.clamp(10, 600) ?? p.heightMm,
      massG: parse(_m.text)?.clamp(10, 5000) ?? p.massG,
    ));
  }

  PrizePreset? _matchingPreset(PrizeSpec p) {
    for (final preset in PrizePreset.values) {
      final s = preset.spec;
      if (s.widthMm == p.widthMm && s.depthMm == p.depthMm && s.heightMm == p.heightMm && s.massG == p.massG) {
        return preset;
      }
    }
    return null;
  }

  String _presetLabel(S s, PrizePreset p) => switch (p) {
        PrizePreset.figureBoxS => s.presetFigureBoxS,
        PrizePreset.figureBoxM => s.presetFigureBoxM,
        PrizePreset.figureBoxL => s.presetFigureBoxL,
        PrizePreset.plush => s.presetPlush,
      };

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final corr = c.corrections;
        final selected = _matchingPreset(c.prize);
        final yOff = (corr.boxYOffsetMm ?? 0).clamp(PrizeSheet.yOffsetRange.$1, PrizeSheet.yOffsetRange.$2);
        final ratio = (corr.topFaceRatio ?? 0.35).clamp(PrizeSheet.topFaceRange.$1, PrizeSheet.topFaceRange.$2);
        final yaw = (corr.yawDeg ?? 0).clamp(PrizeSheet.yawRange.$1, PrizeSheet.yawRange.$2);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.prizeSheetTitle, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final p in PrizePreset.values)
                    ChoiceChip(
                      label: Text(_presetLabel(s, p)),
                      selected: selected == p,
                      onSelected: (_) => _applyPreset(p),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _numField(_w, s.widthMm)),
                  const SizedBox(width: 8),
                  Expanded(child: _numField(_d, s.depthMm)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _numField(_h, s.heightMm)),
                  const SizedBox(width: 8),
                  Expanded(child: _numField(_m, s.massG)),
                ],
              ),
              const SizedBox(height: 16),
              _sliderLabel(context, s.boxYOffset, '${yOff.round()} mm'),
              Row(
                children: [
                  Text(s.towardBack, style: Theme.of(context).textTheme.labelSmall),
                  Expanded(
                    child: Slider(
                      value: yOff,
                      min: PrizeSheet.yOffsetRange.$1,
                      max: PrizeSheet.yOffsetRange.$2,
                      divisions: 32,
                      label: '${yOff.round()} mm',
                      onChanged: (v) => c.setCorrections(corr.copyWith(boxYOffsetMm: v)),
                    ),
                  ),
                  Text(s.towardFront, style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
              _sliderLabel(context, s.topFaceRatio, '${(ratio * 100).round()}%'),
              Slider(
                value: ratio,
                min: PrizeSheet.topFaceRange.$1,
                max: PrizeSheet.topFaceRange.$2,
                divisions: 22,
                label: '${(ratio * 100).round()}%',
                onChanged: (v) => c.setCorrections(corr.copyWith(topFaceRatio: v)),
              ),
              _sliderLabel(context, s.yaw, '${yaw.round()}°'),
              Slider(
                value: yaw,
                min: PrizeSheet.yawRange.$1,
                max: PrizeSheet.yawRange.$2,
                divisions: 30,
                label: '${yaw.round()}°',
                onChanged: (v) => c.setCorrections(corr.copyWith(yawDeg: v)),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Text(s.done),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sliderLabel(BuildContext context, String label, String value) => Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.labelLarge)),
          Text(value, style: Theme.of(context).textTheme.labelLarge),
        ],
      );

  Widget _numField(TextEditingController ctl, String label) => TextField(
        controller: ctl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
        onChanged: (_) => _applyFields(),
      );
}
