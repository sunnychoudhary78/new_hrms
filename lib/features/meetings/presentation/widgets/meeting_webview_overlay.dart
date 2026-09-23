import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/features/meetings/presentation/providers/meeting_session_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// Keeps a single Jitsi WebView alive for the whole app session.
///
/// The platform view is always laid out at full screen size. When the user
/// goes back into HRMS, that same view is moved off-screen (not resized) so
/// camera/mic keep running and the drawer/back stack stay usable.
class MeetingPersistentHost extends ConsumerStatefulWidget {
  const MeetingPersistentHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<MeetingPersistentHost> createState() =>
      _MeetingPersistentHostState();
}

class _MeetingPersistentHostState extends ConsumerState<MeetingPersistentHost>
    with WidgetsBindingObserver {
  WebViewController? _controller;
  String? _loadedUrl;
  bool _confirmingLeave = false;
  Widget? _customView;
  VoidCallback? _hideCustomView;

  static const _webviewKey = ValueKey('hrms-meeting-webview');
  static final _webviewGestures = <Factory<OneSequenceGestureRecognizer>>{
    Factory<EagerGestureRecognizer>(EagerGestureRecognizer.new),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller = null;
    super.dispose();
  }

  @override
  Future<bool> didPopRoute() async {
    if (_customView != null) {
      _dismissCustomView();
      return true;
    }
    final session = ref.read(meetingSessionProvider);
    if (session.isActive && session.expanded) {
      ref.read(meetingSessionProvider.notifier).minimize();
      return true;
    }
    return false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ref.read(meetingSessionProvider).isActive) {
      _kickMedia();
    }
  }

  Size _stageSize(MediaQueryData media) {
    return Size(
      media.size.width + media.viewInsets.horizontal,
      media.size.height + media.viewInsets.vertical,
    );
  }

  Future<void> _ensureController(String url) async {
    if (_controller != null && _loadedUrl == url) return;

    if (_controller != null) {
      await _controller!.loadRequest(Uri.parse(url));
      if (!mounted) return;
      setState(() => _loadedUrl = url);
      return;
    }

    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (error) {
            debugPrint('Meeting WebView error: ${error.description}');
          },
        ),
      );

    final platform = controller.platform;
    if (platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(kDebugMode);
      platform.setMediaPlaybackRequiresUserGesture(false);
      platform.setOnPlatformPermissionRequest((request) {
        request.grant();
      });
      platform.setCustomWidgetCallbacks(
        onShowCustomWidget: (widget, onHide) {
          _hideCustomView = onHide;
          if (mounted) setState(() => _customView = widget);
        },
        onHideCustomWidget: () {
          _hideCustomView = null;
          if (mounted) setState(() => _customView = null);
        },
      );
    } else if (platform is WebKitWebViewController) {
      platform.setAllowsBackForwardNavigationGestures(false);
      platform.setOnPlatformPermissionRequest((request) {
        request.grant();
      });
    }

    await controller.loadRequest(Uri.parse(url));
    if (!mounted) return;
    setState(() {
      _controller = controller;
      _loadedUrl = url;
    });
  }

  void _dismissCustomView() {
    _hideCustomView?.call();
    _hideCustomView = null;
    if (mounted) setState(() => _customView = null);
  }

  void _leaveMeeting() {
    _dismissCustomView();
    ref.read(meetingSessionProvider.notifier).end();
    setState(() {
      _controller = null;
      _loadedUrl = null;
      _confirmingLeave = false;
    });
  }

  Future<void> _kickMedia() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.runJavaScript('''
        (function() {
          document.querySelectorAll('video').forEach(function(v) {
            try { v.play(); } catch (e) {}
          });
        })();
      ''');
    } catch (_) {}
  }

  Widget _buildWebView() {
    final controller = _controller;
    if (controller == null) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final platform = controller.platform;
    if (platform is AndroidWebViewController) {
      return WebViewWidget.fromPlatform(
        platform: AndroidWebViewWidget(
          AndroidWebViewWidgetCreationParams(
            key: _webviewKey,
            controller: platform,
            displayWithHybridComposition: true,
            gestureRecognizers: _webviewGestures,
          ),
        ),
      );
    }

    return WebViewWidget(
      key: _webviewKey,
      controller: controller,
      gestureRecognizers: _webviewGestures,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(meetingSessionProvider);
    final media = MediaQuery.of(context);
    final stage = _stageSize(media);
    final expanded = session.isActive && session.expanded;

    ref.listen<MeetingSessionState>(meetingSessionProvider, (prev, next) {
      if (next.isActive && next.expanded && prev?.expanded == false) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _kickMedia();
        });
      }
    });

    if (session.isActive &&
        session.joinUrl != null &&
        _loadedUrl != session.joinUrl) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ensureController(session.joinUrl!);
      });
    }

    if (!session.isActive && (_controller != null || _loadedUrl != null)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _controller = null;
          _loadedUrl = null;
          _confirmingLeave = false;
          _customView = null;
          _hideCustomView = null;
        });
      });
    }

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        PopScope(
          canPop: !expanded,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (_customView != null) {
              _dismissCustomView();
              return;
            }
            if (expanded) {
              ref.read(meetingSessionProvider.notifier).minimize();
            }
          },
          child: widget.child,
        ),
        if (session.isActive)
          Positioned(
            left: expanded ? 0 : stage.width,
            top: 0,
            width: stage.width,
            height: stage.height,
            child: IgnorePointer(
              ignoring: !expanded,
              child: Material(
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Column(
                      children: [
                        _MeetingChrome(
                          confirmingLeave: _confirmingLeave,
                          title: session.title ?? 'Meeting',
                          onUseApp: () => ref
                              .read(meetingSessionProvider.notifier)
                              .minimize(),
                          onLeavePressed: () =>
                              setState(() => _confirmingLeave = true),
                          onLeaveConfirm: _leaveMeeting,
                          onLeaveCancel: () =>
                              setState(() => _confirmingLeave = false),
                        ),
                        Expanded(child: _buildWebView()),
                      ],
                    ),
                    if (_customView != null) Positioned.fill(child: _customView!),
                  ],
                ),
              ),
            ),
          ),
        if (session.isActive && !expanded)
          Positioned(
            right: 12,
            bottom: 24 + media.padding.bottom,
            child: _InCallChip(
              title: session.title ?? 'In a meeting',
              confirmingLeave: _confirmingLeave,
              onReturn: () {
                setState(() => _confirmingLeave = false);
                ref.read(meetingSessionProvider.notifier).expand();
              },
              onLeavePressed: () => setState(() => _confirmingLeave = true),
              onLeaveConfirm: _leaveMeeting,
              onLeaveCancel: () => setState(() => _confirmingLeave = false),
            ),
          ),
      ],
    );
  }
}

class _MeetingChrome extends StatelessWidget {
  const _MeetingChrome({
    required this.confirmingLeave,
    required this.title,
    required this.onUseApp,
    required this.onLeavePressed,
    required this.onLeaveConfirm,
    required this.onLeaveCancel,
  });

  final bool confirmingLeave;
  final String title;
  final VoidCallback onUseApp;
  final VoidCallback onLeavePressed;
  final VoidCallback onLeaveConfirm;
  final VoidCallback onLeaveCancel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xE6111827),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 48,
          child: confirmingLeave
              ? Row(
                  children: [
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'Leave this meeting?',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: onLeaveCancel,
                      child: const Text('Stay'),
                    ),
                    TextButton(
                      onPressed: onLeaveConfirm,
                      child: const Text(
                        'Leave',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    GestureDetector(
                      onTap: onUseApp,
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: onUseApp,
                      child: const Text(
                        'Use app',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    TextButton(
                      onPressed: onLeavePressed,
                      child: const Text(
                        'Leave',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _InCallChip extends StatelessWidget {
  const _InCallChip({
    required this.title,
    required this.confirmingLeave,
    required this.onReturn,
    required this.onLeavePressed,
    required this.onLeaveConfirm,
    required this.onLeaveCancel,
  });

  final String title;
  final bool confirmingLeave;
  final VoidCallback onReturn;
  final VoidCallback onLeavePressed;
  final VoidCallback onLeaveConfirm;
  final VoidCallback onLeaveCancel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF111827),
      elevation: 8,
      borderRadius: BorderRadius.circular(24),
      child: confirmingLeave
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'Leave?',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onLeaveCancel,
                    child: const Text('Stay'),
                  ),
                  TextButton(
                    onPressed: onLeaveConfirm,
                    child: const Text(
                      'Leave',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            )
          : InkWell(
              onTap: onReturn,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.videocam,
                      color: Colors.redAccent,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: onLeavePressed,
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.close, color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
