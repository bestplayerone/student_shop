import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/invoice_model.dart';

typedef ExternalCheckoutLauncher = Future<bool> Function(Uri url);

/// Displays the actual hosted invoice; this screen never decides payment status.
class XenditWebViewScreen extends StatefulWidget {
  const XenditWebViewScreen({
    super.key,
    required this.invoiceUrl,
    this.externalLauncher,
    this.embedCheckout,
  });

  final String invoiceUrl;
  final ExternalCheckoutLauncher? externalLauncher;
  final bool? embedCheckout;

  @override
  State<XenditWebViewScreen> createState() => _XenditWebViewScreenState();
}

class _XenditWebViewScreenState extends State<XenditWebViewScreen> {
  WebViewController? _controller;
  bool _opened = false;
  bool _opening = false;
  bool _loading = true;
  String? _loadError;

  bool get _embeddedCheckout =>
      widget.embedCheckout ??
      (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS));

  Uri? get _invoiceUri {
    final uri = Uri.tryParse(widget.invoiceUrl);
    return isXenditCheckoutUri(uri) ? uri : null;
  }

  @override
  void initState() {
    super.initState();
    final uri = _invoiceUri;
    if (_embeddedCheckout && uri != null) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (_) {
              if (mounted) setState(() => _loading = true);
            },
            onPageFinished: (_) {
              if (mounted) {
                setState(() {
                  _loading = false;
                  _loadError = null;
                });
              }
            },
            onWebResourceError: (error) {
              if (error.isForMainFrame == true && mounted) {
                setState(() {
                  _loading = false;
                  _loadError = 'Checkout could not load. Check your connection and retry.';
                });
              }
            },
            onNavigationRequest: (request) {
              final target = Uri.tryParse(request.url);
              return target?.scheme == 'https'
                  ? NavigationDecision.navigate
                  : NavigationDecision.prevent;
            },
          ),
        )
        ..loadRequest(uri);
    }
  }

  Future<void> _openCheckout() async {
    final uri = _invoiceUri;
    if (uri == null || _opening) return;
    setState(() => _opening = true);
    final opened =
        await (widget.externalLauncher?.call(uri) ??
            launchUrl(uri, mode: LaunchMode.externalApplication));
    if (!mounted) return;
    setState(() {
      _opened = opened;
      _opening = false;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Secure Checkout'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Done'),
        ),
      ],
    ),
    body: SafeArea(
      child: _invoiceUri == null
          ? const Center(child: Text('Checkout link is invalid'))
          : _embeddedCheckout
          ? Stack(
              children: [
                if (_controller != null)
                  WebViewWidget(controller: _controller!),
                if (_loading && _loadError == null)
                  const Center(child: CircularProgressIndicator()),
                if (_loadError case final error?)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.wifi_off, size: 48),
                          const SizedBox(height: 12),
                          Text(error, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _retryEmbeddedCheckout,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry checkout'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            )
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.open_in_browser,
                        size: 56,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Continue in your browser',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Xendit checkout opens in your browser on this device. '
                        'Complete your payment there, then return here and tap Done. '
                        'Done only checks your backend order; it does not mark a payment as paid.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _opening ? null : _openCheckout,
                        icon: const Icon(Icons.open_in_new),
                        label: Text(
                          _opening
                              ? 'Opening checkout…'
                              : _opened
                              ? 'Re-open checkout'
                              : 'Open checkout',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    ),
  );

  Future<void> _retryEmbeddedCheckout() async {
    final uri = _invoiceUri;
    if (uri == null || _controller == null) return;
    setState(() {
      _loadError = null;
      _loading = true;
    });
    await _controller!.loadRequest(uri);
  }
}
