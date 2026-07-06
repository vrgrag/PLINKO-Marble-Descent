import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../theme.dart';

class WebPageScreen extends StatefulWidget {
  final String title;
  final String url;

  const WebPageScreen({super.key, required this.title, required this.url});

  @override
  State<WebPageScreen> createState() => _WebPageScreenState();
}

class _WebPageScreenState extends State<WebPageScreen> {
  WebViewController? _controller;
  bool _loading = true;
  bool _hasError = false;
  bool _offline = false;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final res = await Connectivity().checkConnectivity();
    final offline = res.every((c) => c == ConnectivityResult.none);
    if (offline) {
      setState(() {
        _offline = true;
        _loading = false;
      });
      return;
    }
    _createController();
  }

  void _createController() {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.deepBlack)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _loading = true;
                _hasError = false;
              });
            }
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            if (mounted) {
              setState(() {
                _hasError = true;
                _loading = false;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
    setState(() => _controller = controller);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepBlack,
      appBar: AppBar(
        backgroundColor: AppColors.deepBlue,
        title: Text(widget.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            )),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        bottom: _loading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress / 100 : null,
                  minHeight: 3,
                  backgroundColor: AppColors.deepBlack,
                  valueColor: const AlwaysStoppedAnimation(AppColors.neonCyan),
                ),
              )
            : null,
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_offline) {
      return _fallback(
        icon: Icons.cloud_off,
        title: 'You are offline',
        message: 'Connect to the Internet to view ${widget.title}.',
        action: _OfflineAction(
          onRetry: () {
            setState(() {
              _offline = false;
              _loading = true;
              _hasError = false;
            });
            _init();
          },
        ),
      );
    }
    if (_hasError) {
      return _fallback(
        icon: Icons.error_outline,
        title: 'Failed to load',
        message: 'Could not load the page. Please try again.',
        action: _OfflineAction(
          onRetry: () {
            setState(() {
              _hasError = false;
              _loading = true;
            });
            _controller?.loadRequest(Uri.parse(widget.url));
          },
        ),
      );
    }
    final c = _controller;
    if (c == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.neonCyan),
      );
    }
    return WebViewWidget(controller: c);
  }

  Widget _fallback({
    required IconData icon,
    required String title,
    required String message,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppColors.neonCyan),
            const SizedBox(height: 12),
            Text(title, style: AppTextStyles.heading, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message,
                style: AppTextStyles.bodyDim, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            if (action != null) action,
          ],
        ),
      ),
    );
  }
}

class _OfflineAction extends StatelessWidget {
  final VoidCallback onRetry;
  const _OfflineAction({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return NeonButton(
      label: 'Retry',
      icon: Icons.refresh,
      onPressed: onRetry,
    );
  }
}
