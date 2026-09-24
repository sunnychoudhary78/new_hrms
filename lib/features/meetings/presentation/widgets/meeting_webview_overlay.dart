import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/features/meetings/data/meeting_call_keepalive.dart';
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
  Widget? _cachedWebView;
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
    if (!ref.read(meetingSessionProvider).isActive) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _injectKeepAlive();
      return;
    }
    if (state == AppLifecycleState.resumed) {
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
          onPageFinished: (_) {
            _injectKeepAlive();
            _injectJitsiUiFixes();
          },
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
      _cachedWebView = null;
    });
    await MeetingCallKeepAlive.start(title: ref.read(meetingSessionProvider).title);
    await _injectKeepAlive();
  }

  void _dismissCustomView() {
    _hideCustomView?.call();
    _hideCustomView = null;
    if (mounted) setState(() => _customView = null);
  }

  void _leaveMeeting() {
    _dismissCustomView();
    MeetingCallKeepAlive.stop();
    ref.read(meetingSessionProvider.notifier).end();
    setState(() {
      _controller = null;
      _cachedWebView = null;
      _loadedUrl = null;
      _confirmingLeave = false;
    });
  }

  Future<void> _injectKeepAlive() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.runJavaScript(_jitsiKeepAliveJs);
    } catch (_) {}
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
    await _injectKeepAlive();
  }

  /// Jitsi header icons (close / back / cancel) render as a white circle
  /// in WebView until pressed. Force the outline icons from the pressed state.
  Future<void> _injectJitsiUiFixes() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.runJavaScript(_jitsiIconFixJs);
    } catch (_) {}
  }

  static const _jitsiIconFixJs = r'''
(function () {
  var css = [
    'button[aria-label*="Close"],',
    'button[aria-label*="close"],',
    'button[aria-label*="Back"],',
    'button[aria-label*="back"],',
    'button[aria-label*="Cancel"],',
    'button[aria-label*="cancel"],',
    'button[aria-label*="Return"],',
    'button[aria-label*="return"],',
    'button[title*="Close"],',
    'button[title*="close"],',
    'button[title*="Back"],',
    'button[title*="back"],',
    'button[title*="Cancel"],',
    'button[title*="cancel"] {',
    '  background: transparent !important;',
    '  background-color: transparent !important;',
    '  box-shadow: none !important;',
    '}',
    'button[aria-label*="Close"] .jitsi-icon,',
    'button[aria-label*="close"] .jitsi-icon,',
    'button[aria-label*="Back"] .jitsi-icon,',
    'button[aria-label*="back"] .jitsi-icon,',
    'button[aria-label*="Cancel"] .jitsi-icon,',
    'button[aria-label*="cancel"] .jitsi-icon,',
    'button[aria-label*="Return"] .jitsi-icon,',
    'button[aria-label*="return"] .jitsi-icon,',
    'button[title*="Close"] .jitsi-icon,',
    'button[title*="close"] .jitsi-icon,',
    'button[title*="Back"] .jitsi-icon,',
    'button[title*="back"] .jitsi-icon,',
    'button[title*="Cancel"] .jitsi-icon,',
    'button[title*="cancel"] .jitsi-icon {',
    '  background: transparent !important;',
    '  background-color: transparent !important;',
    '  -webkit-mask-image: none !important;',
    '  mask-image: none !important;',
    '}',
    'button[aria-label*="Close"] svg,',
    'button[aria-label*="close"] svg,',
    'button[aria-label*="Back"] svg,',
    'button[aria-label*="back"] svg,',
    'button[aria-label*="Cancel"] svg,',
    'button[aria-label*="cancel"] svg,',
    'button[aria-label*="Return"] svg,',
    'button[aria-label*="return"] svg,',
    'button[title*="Close"] svg,',
    'button[title*="Back"] svg,',
    'button[title*="Cancel"] svg {',
    '  display: block !important;',
    '  visibility: visible !important;',
    '  opacity: 1 !important;',
    '  width: 22px !important;',
    '  height: 22px !important;',
    '}',
    'button[aria-label*="Close"] path,',
    'button[aria-label*="close"] path,',
    'button[aria-label*="Back"] path,',
    'button[aria-label*="back"] path,',
    'button[aria-label*="Cancel"] path,',
    'button[aria-label*="cancel"] path,',
    'button[aria-label*="Return"] path,',
    'button[aria-label*="return"] path,',
    'button[title*="Close"] path,',
    'button[title*="Back"] path,',
    'button[title*="Cancel"] path {',
    '  fill: #c2c7d0 !important;',
    '}'
  ].join('');

  function ensureStyle() {
    if (!document.head) return;
    var old = document.getElementById('hrms-jitsi-close-fix');
    if (old && old.parentNode) old.parentNode.removeChild(old);
    var style = document.getElementById('hrms-jitsi-icon-fix');
    if (!style) {
      style = document.createElement('style');
      style.id = 'hrms-jitsi-icon-fix';
      document.head.appendChild(style);
    }
    style.textContent = css;
  }

  var CROSS = '<svg viewBox="0 0 24 24" width="22" height="22" aria-hidden="true"><path fill="#c2c7d0" d="M19 6.41 17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z"/></svg>';
  var BACK = '<svg viewBox="0 0 24 24" width="22" height="22" aria-hidden="true"><path fill="#c2c7d0" d="M20 11H7.83l5.59-5.59L12 4l-8 8 8 8 1.41-1.41L7.83 13H20v-2z"/></svg>';

  function buttonLabel(el) {
    return ((el.getAttribute('aria-label') || '') + ' ' + (el.getAttribute('title') || '')).toLowerCase();
  }

  function buttonKind(el) {
    if (!el || el.tagName !== 'BUTTON') return '';
    var label = buttonLabel(el);
    if (label.indexOf('back') !== -1 || label.indexOf('return') !== -1) return 'back';
    if (label.indexOf('cancel') !== -1 || label.indexOf('close') !== -1 || label.indexOf('dismiss') !== -1) return 'close';
    return '';
  }

  function clearWhiteIcon(btn) {
    btn.style.background = 'transparent';
    btn.style.backgroundColor = 'transparent';
    btn.style.boxShadow = 'none';
    var icon = btn.querySelector('.jitsi-icon');
    if (icon) {
      icon.style.background = 'transparent';
      icon.style.backgroundColor = 'transparent';
      icon.style.webkitMaskImage = 'none';
      icon.style.maskImage = 'none';
    }
    var svgs = btn.querySelectorAll('svg');
    for (var i = 0; i < svgs.length; i++) {
      svgs[i].style.display = 'block';
      svgs[i].style.visibility = 'visible';
      svgs[i].style.opacity = '1';
    }
    var paths = btn.querySelectorAll('path');
    for (var p = 0; p < paths.length; p++) {
      paths[p].setAttribute('fill', '#c2c7d0');
    }
  }

  function fixButton(btn) {
    var kind = buttonKind(btn);
    if (!kind) return;
    if (btn.getAttribute('data-hrms-icon-fixed') === kind) return;
    btn.setAttribute('data-hrms-icon-fixed', kind);
    clearWhiteIcon(btn);
    var text = (btn.textContent || '').replace(/\s+/g, '');
    if (btn.querySelector('svg')) return;
    if (text.length > 0 && text.toLowerCase() !== 'close' && text.toLowerCase() !== 'back' && text.toLowerCase() !== 'cancel') return;
    btn.insertAdjacentHTML('afterbegin', kind === 'back' ? BACK : CROSS);
  }

  function scan() {
    ensureStyle();
    var nodes = document.querySelectorAll('button:not([data-hrms-icon-fixed])');
    for (var i = 0; i < nodes.length; i++) {
      fixButton(nodes[i]);
    }
  }

  var scanTimer = null;
  function scheduleScan() {
    if (scanTimer) return;
    scanTimer = setTimeout(function () {
      scanTimer = null;
      scan();
    }, 400);
  }

  scan();
  setTimeout(scan, 800);
  if (!window.__hrmsJitsiIconObserver) {
    window.__hrmsJitsiIconObserver = new MutationObserver(function () { scheduleScan(); });
    if (document.documentElement) {
      window.__hrmsJitsiIconObserver.observe(document.documentElement, {
        childList: true,
        subtree: true
      });
    }
  }
})();
''';

  static const _jitsiKeepAliveJs = r'''
(function () {
  if (window.__hrmsKeepMeeting) return;
  window.__hrmsKeepMeeting = true;
  var block = function (e) {
    try { e.stopImmediatePropagation(); } catch (err) {}
  };
  document.addEventListener('visibilitychange', block, true);
  window.addEventListener('pagehide', block, true);
  window.addEventListener('freeze', block, true);
  try {
    Object.defineProperty(document, 'hidden', { configurable: true, get: function () { return false; } });
    Object.defineProperty(document, 'visibilityState', { configurable: true, get: function () { return 'visible'; } });
  } catch (err) {}
})();
''';

  Widget _buildWebView() {
    final controller = _controller;
    if (controller == null) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_cachedWebView != null) return _cachedWebView!;

    final platform = controller.platform;
    final webView = platform is AndroidWebViewController
        ? WebViewWidget.fromPlatform(
            platform: AndroidWebViewWidget(
              AndroidWebViewWidgetCreationParams(
                key: _webviewKey,
                controller: platform,
                displayWithHybridComposition: true,
                gestureRecognizers: _webviewGestures,
              ),
            ),
          )
        : WebViewWidget(
            key: _webviewKey,
            controller: controller,
            gestureRecognizers: _webviewGestures,
          );
    _cachedWebView = webView;
    return webView;
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(meetingSessionProvider);
    final media = MediaQuery.of(context);
    final stage = _stageSize(media);
    final expanded = session.isActive && session.expanded;

    ref.listen<MeetingSessionState>(meetingSessionProvider, (prev, next) {
      if (next.isActive && prev?.isActive != true) {
        MeetingCallKeepAlive.start(title: next.title);
      }
      if (!next.isActive && prev?.isActive == true) {
        MeetingCallKeepAlive.stop();
      }
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
        MeetingCallKeepAlive.stop();
        setState(() {
          _controller = null;
          _cachedWebView = null;
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
                          title: session.title ?? 'Meeting',
                          onBack: () => ref
                              .read(meetingSessionProvider.notifier)
                              .minimize(),
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
    required this.title,
    required this.onBack,
  });

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iconColor = scheme.onSurface;

    return Material(
      color: scheme.surface,
      elevation: 1,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              GestureDetector(
                onTap: onBack,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: iconColor,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: iconColor,
                    fontWeight: FontWeight.w700,
                  ),
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
