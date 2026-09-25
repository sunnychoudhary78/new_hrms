import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _sharing = false;
  bool _frameBusy = false;
  StreamSubscription<dynamic>? _shareFrames;

  static const _shareChannel = MethodChannel('hrms/screen_share');

  static const _webviewKey = ValueKey('hrms-meeting-webview');
  static final _webviewGestures = <Factory<OneSequenceGestureRecognizer>>{
    Factory<EagerGestureRecognizer>(EagerGestureRecognizer.new),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _shareFrames = const EventChannel('hrms/screen_share_frames')
        .receiveBroadcastStream()
        .listen(_onShareEvent, onError: (_) {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shareFrames?.cancel();
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
      ..addJavaScriptChannel(
        'HrmsScreenShare',
        onMessageReceived: (message) {
          if (message.message == 'start') {
            _startNativeShare();
          } else if (message.message == 'stop') {
            _stopNativeShare();
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            _injectKeepAlive();
            _injectJitsiUiFixes();
            _injectDisplayName();
            _injectRaiseHand();
            _injectScreenShare();
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
    await _injectDisplayName();
    await _injectJitsiUiFixes();
    await _injectRaiseHand();
    await _injectScreenShare();
  }

  void _dismissCustomView() {
    _hideCustomView?.call();
    _hideCustomView = null;
    if (mounted) setState(() => _customView = null);
  }

  void _leaveMeeting() {
    _dismissCustomView();
    _stopNativeShare();
    MeetingCallKeepAlive.stop();
    ref.read(meetingSessionProvider.notifier).end();
    setState(() {
      _controller = null;
      _cachedWebView = null;
      _loadedUrl = null;
      _confirmingLeave = false;
    });
  }

  void _onShareEvent(dynamic event) {
    final value = event?.toString() ?? '';
    if (value == '__stopped__') {
      _controller?.runJavaScript(
        'window.__hrmsCancelScreenShare&&window.__hrmsCancelScreenShare()',
      );
      if (mounted) setState(() => _sharing = false);
      return;
    }
    _pushFrame(value);
  }

  Future<void> _pushFrame(String b64) async {
    if (_frameBusy || b64.isEmpty) return;
    final controller = _controller;
    if (controller == null) return;
    _frameBusy = true;
    try {
      await controller.runJavaScript(
        "window.__hrmsDrawScreen&&window.__hrmsDrawScreen('$b64')",
      );
    } catch (_) {}
    _frameBusy = false;
  }

  Future<void> _startNativeShare() async {
    if (defaultTargetPlatform != TargetPlatform.android || _sharing) return;
    if (mounted) setState(() => _sharing = true);
    try {
      final ok = await _shareChannel.invokeMethod<bool>('start');
      if (ok == true) return;
    } catch (_) {}
    await _controller?.runJavaScript(
      'window.__hrmsCancelScreenShare&&window.__hrmsCancelScreenShare()',
    );
    if (mounted) setState(() => _sharing = false);
  }

  Future<void> _stopNativeShare() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _shareChannel.invokeMethod<bool>('stop');
      } catch (_) {}
    }
    if (mounted && _sharing) setState(() => _sharing = false);
  }

  Future<void> _injectScreenShare() async {
    final controller = _controller;
    if (controller == null) return;
    final useCanvas = defaultTargetPlatform == TargetPlatform.android;
    try {
      await controller.runJavaScript(
        'window.__hrmsUseCanvasShare = ${useCanvas ? 'true' : 'false'};\n$_jitsiScreenShareJs',
      );
    } catch (_) {}
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
    await _injectScreenShare();
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

  Future<void> _injectRaiseHand() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.runJavaScript(_jitsiRaiseHandJs);
    } catch (_) {}
  }

  Future<void> _injectDisplayName() async {
    final controller = _controller;
    if (controller == null) return;
    final name = ref.read(meetingSessionProvider).displayName?.trim() ?? '';
    if (name.isEmpty) return;
    final escaped = name.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
    try {
      await controller.runJavaScript(
        "window.__hrmsDisplayName = '$escaped';\n$_jitsiDisplayNameJs",
      );
    } catch (_) {}
  }

  static const _jitsiDisplayNameJs = r'''
(function () {
  var name = window.__hrmsDisplayName;
  if (!name) return;
  function looksLikeNameInput(el) {
    if (!el || el.tagName !== 'INPUT') return false;
    var type = (el.getAttribute('type') || 'text').toLowerCase();
    if (type !== 'text' && type !== 'search' && type !== '') return false;
    var hint = ((el.placeholder || '') + ' ' + (el.getAttribute('aria-label') || '') + ' ' + (el.name || '') + ' ' + (el.id || '')).toLowerCase();
    return hint.indexOf('name') !== -1 || hint.indexOf('display') !== -1;
  }
  function fill() {
    var inputs = document.querySelectorAll('input');
    for (var i = 0; i < inputs.length; i++) {
      var el = inputs[i];
      if (!looksLikeNameInput(el)) continue;
      if (el.value === name) continue;
      el.focus();
      el.value = name;
      try {
        el.dispatchEvent(new Event('input', { bubbles: true }));
        el.dispatchEvent(new Event('change', { bubbles: true }));
      } catch (e) {}
    }
    try {
      if (window.APP && APP.conference && typeof APP.conference.changeLocalDisplayName === 'function') {
        APP.conference.changeLocalDisplayName(name);
      }
    } catch (e) {}
  }
  fill();
  setTimeout(fill, 400);
  setTimeout(fill, 1200);
  setTimeout(fill, 2500);
})();
''';

  static const _jitsiRaiseHandJs = r'''
(function () {
  if (window.__hrmsRaiseHandReady) return;
  var HAND_SVG = '<svg viewBox="0 0 24 24" width="22" height="22" aria-hidden="true"><path fill="currentColor" d="M19.5 9.5c-.28 0-.5.22-.5.5v4.5c0 2.76-2.24 5-5 5s-5-2.24-5-5V6.5c0-.55.45-1 1-1s1 .45 1 1V13h1.5V4.5c0-.55.45-1 1-1s1 .45 1 1V13H15V5.5c0-.55.45-1 1-1s1 .45 1 1V13h1.5V10c0-.28.22-.5.5-.5s.5.22.5.5v4.5c0 3.59-2.91 6.5-6.5 6.5S6.5 18.09 6.5 14.5v-3c0-.28-.22-.5-.5-.5s-.5.22-.5.5v3C5.5 19.43 8.57 22.5 12.5 22.5S19.5 19.43 19.5 15.5V10c0-.28-.22-.5-.5-.5z"/></svg>';
  var tries = 0;

  function inCall() {
    try {
      if (window.APP && APP.conference && typeof APP.conference.isJoined === 'function' && APP.conference.isJoined()) return true;
    } catch (e) {}
    return !!(document.querySelector('#new-toolbox') || document.querySelector('.toolbox-content-items'));
  }

  function labelOf(el) {
    return ((el.getAttribute('aria-label') || '') + ' ' + (el.getAttribute('title') || '')).toLowerCase();
  }

  function findChat() {
    var nodes = document.querySelectorAll('button');
    for (var i = 0; i < nodes.length; i++) {
      var label = labelOf(nodes[i]);
      if (label.indexOf('chat') !== -1 || label.indexOf('togglechat') !== -1) return nodes[i];
    }
    return null;
  }

  function toggleRaiseHand() {
    try {
      if (window.APP && APP.conference && typeof APP.conference.toggleRaiseHand === 'function') {
        APP.conference.toggleRaiseHand();
        return;
      }
    } catch (e) {}
    try {
      if (window.APP && APP.conference && typeof APP.conference.raiseHand === 'function') {
        window.__hrmsHandRaised = !window.__hrmsHandRaised;
        APP.conference.raiseHand(window.__hrmsHandRaised);
      }
    } catch (e) {}
  }

  function place() {
    if (!inCall()) return false;
    var chat = findChat();
    if (!chat || !chat.parentNode) return false;
    if (document.getElementById('hrms-raise-hand')) return true;
    if (!document.getElementById('hrms-raise-hand-style') && document.head) {
      var style = document.createElement('style');
      style.id = 'hrms-raise-hand-style';
      style.textContent = '#hrms-raise-hand{display:inline-flex!important;align-items:center;justify-content:center;width:48px;height:48px;margin:0 2px;border:0;border-radius:50%;background:transparent;color:#fff;padding:0;}#hrms-raise-hand svg{display:block;width:22px;height:22px;}';
      document.head.appendChild(style);
    }
    var btn = document.createElement('button');
    btn.id = 'hrms-raise-hand';
    btn.type = 'button';
    btn.setAttribute('aria-label', 'Raise hand');
    btn.innerHTML = HAND_SVG;
    btn.addEventListener('click', function (e) {
      e.preventDefault();
      e.stopPropagation();
      toggleRaiseHand();
      window.__hrmsHandRaised = !window.__hrmsHandRaised;
      btn.style.color = window.__hrmsHandRaised ? '#fbbf24' : '#fff';
    });
    chat.parentNode.insertBefore(btn, chat.nextSibling);
    window.__hrmsRaiseHandReady = true;
    return true;
  }

  function wait() {
    if (place()) return;
    if (++tries > 40) return;
    setTimeout(wait, 1500);
  }
  wait();
})();
''';

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
    if (document.getElementById('hrms-jitsi-icon-fix')) return;
    var style = document.createElement('style');
    style.id = 'hrms-jitsi-icon-fix';
    style.textContent = css;
    document.head.appendChild(style);
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

  static const _jitsiScreenShareJs = r'''
(function () {
  var SHARE_SVG = '<svg viewBox="0 0 24 24" width="22" height="22" aria-hidden="true"><path fill="currentColor" d="M20 18c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2H4c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2H0v2h24v-2h-4zM4 6h16v10H4V6zm10 6.5V10l3.5 3.5L14 17v-2.5H8v-2h6z"/></svg>';
  var placeTries = 0;

  function patch(obj) {
    if (!obj) return;
    ['isMobileBrowser', 'isMobileDevice'].forEach(function (name) {
      if (typeof obj[name] === 'function') obj[name] = function () { return false; };
    });
    ['isDesktopSharingEnabled', 'supportsGetDisplayMedia'].forEach(function (name) {
      if (typeof obj[name] === 'function') obj[name] = function () { return true; };
    });
  }

  function ensureDesktopInList(list) {
    if (!list || typeof list.indexOf !== 'function') return;
    if (list.indexOf('desktop') !== -1) return;
    var mic = list.indexOf('microphone');
    if (mic >= 0) list.splice(mic + 1, 0, 'desktop');
    else list.push('desktop');
  }

  window.__hrmsEnableDesktopShare = function () {
    try { patch(window.JitsiMeetJS); } catch (e) {}
    try { patch(window.JitsiMeetJS && JitsiMeetJS.util && JitsiMeetJS.util.browser); } catch (e) {}
    try {
      if (window.JitsiMeetJS && typeof JitsiMeetJS.isDesktopSharingEnabled === 'function') {
        JitsiMeetJS.isDesktopSharingEnabled = function () { return true; };
      }
    } catch (e) {}
    try {
      if (window.config) {
        config.disableScreensharing = false;
        ensureDesktopInList(config.toolbarButtons);
      }
    } catch (e) {}
    try {
      if (window.interfaceConfig) {
        ensureDesktopInList(interfaceConfig.TOOLBAR_BUTTONS);
      }
    } catch (e) {}
  };

  window.__hrmsMarkSharing = function (on) {
    window.__hrmsSharing = !!on;
    var btn = document.getElementById('hrms-screen-share');
    if (!btn) return;
    btn.style.color = on ? '#34d399' : '#fff';
    btn.setAttribute('aria-label', on ? 'Stop sharing your screen' : 'Share your screen');
    btn.setAttribute('title', on ? 'Stop sharing your screen' : 'Share your screen');
  };

  window.__hrmsDrawScreen = function (b64) {
    var canvas = window.__hrmsScreenCanvas;
    var ctx = window.__hrmsScreenCtx;
    if (!canvas || !ctx || !b64) return;
    var img = window.__hrmsScreenImg || new Image();
    window.__hrmsScreenImg = img;
    img.onload = function () {
      if (canvas.width !== img.width || canvas.height !== img.height) {
        canvas.width = img.width;
        canvas.height = img.height;
      }
      ctx.drawImage(img, 0, 0);
    };
    img.src = 'data:image/jpeg;base64,' + b64;
  };

  window.__hrmsCancelScreenShare = function () {
    window.__hrmsShareEnding = true;
    var stream = window.__hrmsScreenStream;
    window.__hrmsScreenStream = null;
    window.__hrmsMarkSharing(false);
    if (!stream) return;
    stream.getTracks().forEach(function (track) {
      try { track.stop(); } catch (e) {}
    });
  };

  window.__hrmsCanvasDisplayMedia = function () {
    var canvas = window.__hrmsScreenCanvas || document.createElement('canvas');
    canvas.width = 960;
    canvas.height = 540;
    window.__hrmsScreenCanvas = canvas;
    window.__hrmsScreenCtx = canvas.getContext('2d', { alpha: false });
    var stream = canvas.captureStream(12);
    window.__hrmsScreenStream = stream;
    window.__hrmsShareEnding = false;
    window.__hrmsMarkSharing(true);
    var track = stream.getVideoTracks()[0];
    if (track) {
      var origStop = track.stop.bind(track);
      track.stop = function () {
        try {
          if (!window.__hrmsShareEnding && window.HrmsScreenShare) {
            HrmsScreenShare.postMessage('stop');
          }
        } catch (e) {}
        window.__hrmsShareEnding = false;
        window.__hrmsMarkSharing(false);
        origStop();
      };
    }
    try { if (window.HrmsScreenShare) HrmsScreenShare.postMessage('start'); } catch (e) {}
    return Promise.resolve(stream);
  };

  if (navigator.mediaDevices && window.__hrmsUseCanvasShare && !navigator.mediaDevices.__hrmsSharePatched) {
    navigator.mediaDevices.__hrmsSharePatched = true;
    navigator.mediaDevices.getDisplayMedia = function () {
      return window.__hrmsCanvasDisplayMedia();
    };
  }

  function inCall() {
    try {
      if (window.APP && APP.conference && typeof APP.conference.isJoined === 'function' && APP.conference.isJoined()) return true;
    } catch (e) {}
    return !!(document.querySelector('#new-toolbox') || document.querySelector('.toolbox-content-items'));
  }

  function labelOf(el) {
    return ((el.getAttribute('aria-label') || '') + ' ' + (el.getAttribute('title') || '')).toLowerCase();
  }

  function isShareLabel(label) {
    return label.indexOf('share your screen') !== -1 ||
      label.indexOf('stop sharing your screen') !== -1 ||
      label.indexOf('stop screen sharing') !== -1 ||
      label.indexOf('screenshare') !== -1 ||
      label.indexOf('screen share') !== -1 ||
      (label.indexOf('desktop') !== -1 && label.indexOf('share') !== -1);
  }

  function inBottomToolbox(el) {
    return !!(el.closest('#new-toolbox') ||
      el.closest('.new-toolbox') ||
      el.closest('.toolbox-content-items') ||
      el.closest('.toolbox-content'));
  }

  function hideTopShare() {
    var nodes = document.querySelectorAll('button');
    for (var i = 0; i < nodes.length; i++) {
      var el = nodes[i];
      if (el.id === 'hrms-screen-share') continue;
      if (!isShareLabel(labelOf(el))) continue;
      if (inBottomToolbox(el)) {
        if (document.getElementById('hrms-screen-share')) {
          el.style.setProperty('display', 'none', 'important');
        }
        continue;
      }
      el.style.setProperty('display', 'none', 'important');
    }
  }

  function findChat() {
    var nodes = document.querySelectorAll('button');
    for (var i = 0; i < nodes.length; i++) {
      var label = labelOf(nodes[i]);
      if (label.indexOf('chat') !== -1 || label.indexOf('togglechat') !== -1) return nodes[i];
    }
    return null;
  }

  function toggleShare() {
    try {
      if (window.APP && APP.conference && typeof APP.conference.toggleScreenSharing === 'function') {
        var result = APP.conference.toggleScreenSharing();
        if (result && typeof result.catch === 'function') result.catch(function () {});
        return;
      }
    } catch (e) {}
    var nodes = document.querySelectorAll('button');
    for (var i = 0; i < nodes.length; i++) {
      if (nodes[i].id === 'hrms-screen-share') continue;
      if (isShareLabel(labelOf(nodes[i]))) {
        nodes[i].click();
        return;
      }
    }
    try {
      if (window.__hrmsUseCanvasShare) {
        if (window.__hrmsSharing) window.__hrmsCancelScreenShare();
        else window.__hrmsCanvasDisplayMedia();
      }
    } catch (e) {}
  }

  function ensureStyle() {
    if (document.getElementById('hrms-screen-share-style') || !document.head) return;
    var style = document.createElement('style');
    style.id = 'hrms-screen-share-style';
    style.textContent = [
      '#hrms-screen-share{display:inline-flex!important;align-items:center;justify-content:center;width:48px;height:48px;margin:0 2px;border:0;border-radius:50%;background:transparent;color:#fff;padding:0;}',
      '#hrms-screen-share svg{display:block;width:22px;height:22px;}',
      'header button[aria-label*="Share your screen"],',
      '.subject button[aria-label*="Share your screen"],',
      '.invite-more-container button[aria-label*="Share your screen"],',
      '.filmstrip button[aria-label*="Share your screen"]{display:none!important;}'
    ].join('');
    document.head.appendChild(style);
  }

  function place() {
    hideTopShare();
    if (!inCall()) return false;
    if (document.getElementById('hrms-screen-share')) return true;
    var chat = findChat();
    var box = document.querySelector('.toolbox-content-items') || (chat && chat.parentNode);
    if (!box) return false;
    ensureStyle();
    var btn = document.createElement('button');
    btn.id = 'hrms-screen-share';
    btn.type = 'button';
    btn.setAttribute('aria-label', 'Share your screen');
    btn.setAttribute('title', 'Share your screen');
    btn.innerHTML = SHARE_SVG;
    btn.addEventListener('click', function (e) {
      e.preventDefault();
      e.stopPropagation();
      toggleShare();
    });
    if (chat && chat.parentNode === box) box.insertBefore(btn, chat);
    else box.appendChild(btn);
    window.__hrmsMarkSharing(!!window.__hrmsSharing);
    hideTopShare();
    return true;
  }

  function waitPlace() {
    if (place()) return;
    if (++placeTries > 50) return;
    setTimeout(waitPlace, 1200);
  }

  window.__hrmsEnableDesktopShare();
  ensureStyle();
  waitPlace();
  if (!window.__hrmsSharePatchTimer) {
    var tries = 0;
    window.__hrmsSharePatchTimer = setInterval(function () {
      window.__hrmsEnableDesktopShare();
      hideTopShare();
      place();
      if (++tries > 40) {
        clearInterval(window.__hrmsSharePatchTimer);
        window.__hrmsSharePatchTimer = null;
      }
    }, 500);
  }
  if (!window.__hrmsShareObserver && document.documentElement) {
    var hideTimer = null;
    window.__hrmsShareObserver = new MutationObserver(function () {
      if (hideTimer) return;
      hideTimer = setTimeout(function () {
        hideTimer = null;
        hideTopShare();
      }, 400);
    });
    window.__hrmsShareObserver.observe(document.documentElement, { childList: true, subtree: true });
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
        _stopNativeShare();
        setState(() {
          _controller = null;
          _cachedWebView = null;
          _loadedUrl = null;
          _confirmingLeave = false;
          _customView = null;
          _hideCustomView = null;
          _sharing = false;
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
