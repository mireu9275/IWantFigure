/// Progress screen shown while the photo is analysed; navigates to the
/// result when done, or offers retry / mock fallback on error.
library;

import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../l10n/strings.dart';
import '../services/api_client.dart';
import '../services/session_controller.dart';
import 'result_screen.dart';

/// Localized description of an analysis failure. Server error codes get a
/// specific hint (`unauthorized` → check the app key, `rate_limited`,
/// `provider_not_configured`); provider errors (502) show the relayed
/// provider message.
String analysisErrorText(S s, Object? e) {
  switch (e) {
    case ApiTimeoutException _:
      return s.errorTimeout;
    case NetworkException _:
      return s.errorNetwork;
    case ApiException(statusCode: 0):
      return s.errorBadResponse;
    case ApiException api:
      if (api.isUnauthorized) return s.errorUnauthorized;
      if (api.isRateLimited) return s.errorRateLimited;
      if (api.isProviderNotConfigured) return s.errorProviderNotConfigured;
      if (api.isProviderError) {
        return s.errorProvider(api.providerMessage ?? api.message);
      }
      final detail = api.providerMessage == null ? api.message : '${api.message} (${api.providerMessage})';
      return s.errorServer(api.statusCode, detail);
    default:
      return '${s.analyzeFailed}: $e';
  }
}

/// Runs [SessionController.analyze] and replaces itself with [ResultScreen].
class AnalyzingScreen extends StatefulWidget {
  const AnalyzingScreen({super.key, required this.controller});

  final SessionController controller;

  @override
  State<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends State<AnalyzingScreen> {
  bool _navigated = false;

  SessionController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (c.state == SessionState.idle) {
        c.analyze();
      } else if (c.state == SessionState.ready) {
        _goToResult();
      }
    });
  }

  @override
  void dispose() {
    c.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    if (c.state == SessionState.ready) {
      _goToResult();
    } else {
      setState(() {});
    }
  }

  void _goToResult() {
    if (_navigated) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => ResultScreen(controller: c)),
    );
  }


  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    final isError = c.state == SessionState.error;
    return Scaffold(
      appBar: AppBar(title: Text(s.analyzingTitle)),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: 0.35,
            child: Image.memory(c.photo.bytes, fit: BoxFit.cover, gaplessPlayback: true),
          ),
          Center(
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!isError) ...[
                      const Center(child: CircularProgressIndicator()),
                      const SizedBox(height: 16),
                      _stageRow(context, s.stagePrepare, AnalyzeStage.prepare),
                      if (c.blurFaces) _stageRow(context, s.stageBlur, AnalyzeStage.blur),
                      _stageRow(context, s.stageServer, AnalyzeStage.server),
                      _stageRow(context, s.stageAim, AnalyzeStage.aim),
                    ] else ...[
                      Icon(Icons.error_outline, color: scheme.error, size: 40),
                      const SizedBox(height: 8),
                      Text(s.analyzeFailed, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Text(analysisErrorText(s, c.error), textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => c.analyze(),
                        icon: const Icon(Icons.refresh),
                        label: Text(s.retry),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          final scope = AppScope.maybeOf(context);
                          c.service = scope?.buildService(forceMock: true) ?? c.service;
                          c.analyze();
                        },
                        icon: const Icon(Icons.science_outlined),
                        label: Text(s.switchToMock),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: Text(s.back),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stageRow(BuildContext context, String label, AnalyzeStage stage) {
    final scheme = Theme.of(context).colorScheme;
    final order = AnalyzeStage.values.indexOf(stage);
    final currentOrder = AnalyzeStage.values.indexOf(c.stage);
    final done = c.state == SessionState.ready || order < currentOrder;
    final active = c.state == SessionState.analyzing && order == currentOrder;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : (active ? Icons.radio_button_checked : Icons.radio_button_off),
            size: 20,
            color: done ? scheme.primary : (active ? scheme.secondary : scheme.outline),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(fontWeight: active ? FontWeight.bold : FontWeight.normal),
          ),
        ],
      ),
    );
  }
}
