import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/features/meetings/data/meeting_call_keepalive.dart';
import 'package:lms/features/meetings/presentation/meeting_join.dart';
import 'package:lms/features/meetings/presentation/providers/meeting_session_provider.dart';
import 'package:lms/features/meetings/presentation/providers/meetings_providers.dart';
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
  String? _pendingShareFrame;
  bool _leaving = false;
  bool _seenInCall = false;
  bool _cookiesReady = false;
  bool _refreshingJoin = false;
  bool _appBackgrounded = false;
  bool _pendingBackgroundLeave = false;
  bool _pipMode = false;
  /// After leaving Android PiP, Jitsi often emits a brief CONFERENCE_LEFT /
  /// close-page blip while WebRTC reattaches. Ignore hangup during this window.
  DateTime? _pipRestoreGraceUntil;
  int _joinRefreshes = 0;
  int _exitReloads = 0;
  DateTime? _joinedAt;
  StreamSubscription<dynamic>? _shareFrames;
  StreamSubscription<bool>? _pipSub;

  /// Chrome mobile, without the WebView `wv` token. Jitsi treats `wv` as an
  /// embedded browser and redirects to static/close before config.js runs.
  static const _androidMeetUserAgent =
      'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36';

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
    _pipSub = MeetingCallKeepAlive.pipModeChanges.listen(_onPipModeChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shareFrames?.cancel();
    _pipSub?.cancel();
    _controller = null;
    super.dispose();
  }

  bool get _inPipRestoreGrace {
    final until = _pipRestoreGraceUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  void _armPipRestoreGrace([Duration duration = const Duration(seconds: 12)]) {
    _pipRestoreGraceUntil = DateTime.now().add(duration);
    _pendingBackgroundLeave = false;
    _setJsPipState(inPip: false, restoreGrace: true);
  }

  void _onPipModeChanged(bool inPip) {
    if (!mounted) return;
    final wasPip = _pipMode;
    setState(() => _pipMode = inPip);
    if (inPip) {
      // PiP window must show the call, not the HRMS home under it.
      _pendingBackgroundLeave = false;
      ref.read(meetingSessionProvider.notifier).expand();
      _setJsPipState(inPip: true, restoreGrace: false);
      _kickMedia();
      return;
    }
    // User tapped the floating PiP window → restore full meeting.
    // Do NOT end the call on the transient leave/close blips that follow.
    if (wasPip && ref.read(meetingSessionProvider).isActive) {
      _armPipRestoreGrace();
      ref.read(meetingSessionProvider.notifier).expand();
      _onAppResumed();
    }
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
    if (state == AppLifecycleState.inactive) {
      // Prepare meeting UI before Android snapshots / auto-enters PiP.
      _prepareForPip();
      _onAppBackgrounded();
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _onAppBackgrounded();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _onAppResumed();
    }
  }

  Future<void> _prepareForPip() async {
    if (_sharing || _pipMode) return;
    if (!_seenInCall) return;
    if (defaultTargetPlatform != TargetPlatform.android) return;
    // Expand so Home / gesture leave (auto-enter PiP) captures the call UI,
    // not the HRMS shell. Actual PiP enter is handled natively.
    ref.read(meetingSessionProvider.notifier).expand();
    if (mounted) setState(() {});
  }

  Future<void> _onAppBackgrounded() async {
    _appBackgrounded = true;
    final session = ref.read(meetingSessionProvider);
    // Keep the microphone/camera FGS alive — OEMs kill WebRTC without it.
    await MeetingCallKeepAlive.start(title: session.title);
    await _injectKeepAlive();
    // Tell JS to ignore CONFERENCE_LEFT while HRMS is backgrounded or in PiP.
    await _setJsBackgrounded(true);
    if (_pipMode) {
      await _setJsPipState(inPip: true, restoreGrace: false);
    }
  }

  Future<void> _onAppResumed() async {
    _appBackgrounded = false;
    if (_pipMode) {
      // Still in the floating window — keep the call expanded / ignore leave.
      await _setJsPipState(inPip: true, restoreGrace: false);
      await _kickMedia();
      return;
    }
    final inGrace = _inPipRestoreGrace;
    await _setJsBackgrounded(false);
    await _setJsPipState(inPip: false, restoreGrace: inGrace);
    await _kickMedia();
    if (_pendingBackgroundLeave) {
      _pendingBackgroundLeave = false;
      // After PiP restore, never hang up on a stale leave — ICE may still be
      // reconnecting even though the user only tapped the floating window.
      if (inGrace) return;
      await _controller?.runJavaScript(
        'window.__hrmsCheckStillInCallAfterResume&&window.__hrmsCheckStillInCallAfterResume()',
      );
    }
  }

  Future<void> _setJsBackgrounded(bool backgrounded) async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.runJavaScript(
        'window.__hrmsAppBackgrounded = ${backgrounded ? 'true' : 'false'};'
        'if(!${backgrounded ? 'true' : 'false'} && window.__hrmsLeftTimer){'
        'clearTimeout(window.__hrmsLeftTimer);window.__hrmsLeftTimer=null;}',
      );
    } catch (_) {}
  }

  Future<void> _setJsPipState({
    required bool inPip,
    required bool restoreGrace,
  }) async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.runJavaScript(
        'window.__hrmsPipMode = ${inPip ? 'true' : 'false'};'
        'window.__hrmsPipRestoreGrace = ${restoreGrace ? 'true' : 'false'};'
        'if(window.__hrmsPipRestoreGraceTimer){clearTimeout(window.__hrmsPipRestoreGraceTimer);window.__hrmsPipRestoreGraceTimer=null;}'
        '${restoreGrace ? 'window.__hrmsPipRestoreGraceTimer=setTimeout(function(){window.__hrmsPipRestoreGrace=false;window.__hrmsPipRestoreGraceTimer=null;},12000);' : ''}'
        'if((!${inPip ? 'true' : 'false'}) && window.__hrmsLeftTimer){clearTimeout(window.__hrmsLeftTimer);window.__hrmsLeftTimer=null;}',
      );
    } catch (_) {}
  }

  Size _stageSize(MediaQueryData media) {
    return Size(
      media.size.width + media.viewInsets.horizontal,
      media.size.height + media.viewInsets.vertical,
    );
  }

  Future<void> _ensureController(String url) async {
    _leaving = false;
    if (_controller != null && _loadedUrl == url) return;
    _seenInCall = false;
    _joinedAt = null;
    _exitReloads = 0;

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
      ..addJavaScriptChannel(
        'HrmsMeeting',
        onMessageReceived: (message) {
          if (message.message == 'joined') {
            _seenInCall = true;
            _joinedAt ??= DateTime.now();
            _joinRefreshes = 0;
            _pendingBackgroundLeave = false;
          } else if (message.message == 'left') {
            // Minimizing / PiP / restore briefly drops WebRTC. Never hang up
            // from those blips — only an explicit Leave should end the call.
            if (_appBackgrounded || _pipMode || _inPipRestoreGrace || _sharing) {
              _pendingBackgroundLeave = true;
              return;
            }
            _leaveMeeting();
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            _allowMeetCookies();
          },
          onPageFinished: (_) {
            _allowMeetCookies();
            _injectKeepAlive();
            _injectJitsiUiFixes();
            _injectDisplayName();
            _injectRaiseHand();
            _injectScreenShare();
            _injectVideoPreviewFix();
            _injectLeaveHook();
          },
          onNavigationRequest: (request) {
            if (_handleNavigation(request.url)) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onUrlChange: (change) {
            final url = change.url;
            if (url != null) _handleNavigation(url);
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

    if (defaultTargetPlatform == TargetPlatform.android) {
      await controller.setUserAgent(_androidMeetUserAgent);
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
    await _injectVideoPreviewFix();
    await _injectLeaveHook();
  }

  void _dismissCustomView() {
    _hideCustomView?.call();
    _hideCustomView = null;
    if (mounted) setState(() => _customView = null);
  }

  bool _isJitsiExitUrl(String url) {
    final uri = Uri.tryParse(url);
    final scheme = (uri?.scheme ?? '').toLowerCase();
    if (scheme == 'intent' ||
        scheme == 'jitsi-meet' ||
        scheme == 'org.jitsi.meet') {
      return true;
    }
    final path = (uri?.path ?? url).toLowerCase();
    return path.contains('static/close') ||
        path.contains('close.html') ||
        path.contains('close2.html') ||
        path.contains('close3.html') ||
        path.contains('static/welcome');
  }

  bool _roomWasCleared(String url) {
    if (!_seenInCall) return false;
    final joinUri = Uri.tryParse(_loadedUrl ?? '');
    final now = Uri.tryParse(url);
    if (joinUri == null || now == null) return false;
    if (joinUri.host != now.host) return false;
    final joinRoom =
        joinUri.pathSegments.where((segment) => segment.isNotEmpty).toList();
    final nowRoom =
        now.pathSegments.where((segment) => segment.isNotEmpty).toList();
    return joinRoom.isNotEmpty && nowRoom.isEmpty;
  }

  bool _inJoinGrace() {
    final joinedAt = _joinedAt;
    if (joinedAt == null) return true;
    return DateTime.now().difference(joinedAt) < const Duration(seconds: 8);
  }

  bool _isAuthRejoinUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final path = uri.path.toLowerCase();
    if (path.contains('/meetings/rejoin/')) return true;
    final meetHost = Uri.tryParse(_loadedUrl ?? '')?.host.toLowerCase() ?? '';
    final host = uri.host.toLowerCase();
    if (meetHost.isEmpty || host.isEmpty || host == meetHost) return false;
    return path == '/meetings' ||
        path == '/meetings/' ||
        path.startsWith('/meetings/');
  }

  /// A Meet tab that lost its JWT is sent to a public guest rejoin link, or
  /// the host is sent back to the web meetings page. The app is still signed
  /// in, so mint a fresh join-url and stay in the same room as host/attendee.
  bool _handleNavigation(String url) {
    if (_isAuthRejoinUrl(url)) {
      _refreshAuthenticatedJoin();
      return true;
    }
    return _handleExitNavigation(url);
  }

  Future<void> _refreshAuthenticatedJoin() async {
    if (_refreshingJoin || _leaving) return;
    if (_joinRefreshes >= 2) {
      _leaveMeeting();
      return;
    }
    final session = ref.read(meetingSessionProvider);
    final meetingId = session.meetingId;
    if (meetingId == null || meetingId.isEmpty) {
      _leaveMeeting();
      return;
    }
    _refreshingJoin = true;
    _joinRefreshes++;
    try {
      final info = await ref
          .read(meetingsRepositoryProvider)
          .getJoinUrl(meetingId);
      if (!mounted || _leaving || info.url.isEmpty) {
        if (mounted && !_leaving) _leaveMeeting();
        return;
      }
      final name = session.displayName ?? '';
      ref.read(meetingSessionProvider.notifier).start(
            meetingId: meetingId,
            joinUrl: withJitsiJoinOverrides(info.url, name),
            title: session.title,
            displayName: name,
          );
    } catch (e) {
      debugPrint('Meeting rejoin failed: $e');
      if (mounted) _leaveMeeting();
    } finally {
      _refreshingJoin = false;
    }
  }

  /// Returns true when the navigation must be cancelled.
  ///
  /// The lobby affiliation fix on the Meet server can bounce a WebView
  /// through the close page while the participant is still being admitted.
  /// Reload the fresh join URL during that window instead of ending the call.
  bool _handleExitNavigation(String url) {
    final exit = _isJitsiExitUrl(url) || _roomWasCleared(url);
    if (!exit) return false;
    // MediaProjection consent pauses the activity; Jitsi may briefly hit an
    // exit URL. Never tear down the call while screen share is in flight.
    if (_sharing) return true;
    // Home minimize / Android PiP / restore from PiP — do not end the meeting.
    if (_appBackgrounded || _pipMode || _inPipRestoreGrace) {
      _reloadJoinUrl();
      return true;
    }
    if (_seenInCall && !_inJoinGrace()) {
      _leaveMeeting();
      return true;
    }
    _reloadJoinUrl();
    return true;
  }

  void _reloadJoinUrl() {
    if (_exitReloads >= 2 || _leaving) return;
    final join = _loadedUrl;
    final controller = _controller;
    if (join == null || join.isEmpty || controller == null) return;
    _exitReloads++;
    Future<void>.delayed(const Duration(milliseconds: 250), () {
      if (!mounted || _leaving) return;
      controller.loadRequest(Uri.parse(join));
    });
  }

  Future<void> _allowMeetCookies() async {
    if (_cookiesReady) return;
    final platform = _controller?.platform;
    if (platform is! AndroidWebViewController) return;
    try {
      final cookies = AndroidWebViewCookieManager(
        const PlatformWebViewCookieManagerCreationParams(),
      );
      await cookies.setAcceptThirdPartyCookies(platform, true);
      _cookiesReady = true;
    } catch (e) {
      debugPrint('Meeting cookies: $e');
    }
  }

  void _leaveMeeting() {
    if (_leaving) return;
    _leaving = true;
    _dismissCustomView();
    _stopNativeShare();
    MeetingCallKeepAlive.stop();
    ref.read(meetingSessionProvider.notifier).end();
    if (!mounted) return;
    setState(() {
      _controller = null;
      _cachedWebView = null;
      _loadedUrl = null;
      _confirmingLeave = false;
      _seenInCall = false;
      _joinedAt = null;
      _exitReloads = 0;
      _joinRefreshes = 0;
      _refreshingJoin = false;
      _cookiesReady = false;
      _appBackgrounded = false;
      _pendingBackgroundLeave = false;
      _pipMode = false;
      _pipRestoreGraceUntil = null;
    });
  }

  void _onShareEvent(dynamic event) {
    final value = event?.toString() ?? '';
    if (value == '__stopped__') {
      _pendingShareFrame = null;
      _controller?.runJavaScript(
        'window.__hrmsOnNativeShareStopped&&window.__hrmsOnNativeShareStopped()',
      );
      if (mounted) setState(() => _sharing = false);
      return;
    }
    _pushFrame(value);
  }

  Future<void> _pushFrame(String b64) async {
    // Guard against bridge OOM — oversized payloads have crashed the process
    // ("IMT-HRMS keeps stopping") on mid-range Android devices.
    if (b64.isEmpty || !_sharing || b64.length > 400000) return;
    // Latest-frame-wins: if JS is busy, keep only the newest JPEG.
    _pendingShareFrame = b64;
    if (_frameBusy) return;
    _frameBusy = true;
    try {
      while (_pendingShareFrame != null && _sharing) {
        final frame = _pendingShareFrame!;
        _pendingShareFrame = null;
        final controller = _controller;
        if (controller == null) break;
        // jsonEncode keeps the payload a valid JS string (no quote breakage).
        final arg = jsonEncode(frame);
        await controller.runJavaScript(
          'window.__hrmsDrawScreen&&window.__hrmsDrawScreen($arg)',
        );
      }
    } catch (_) {
    } finally {
      _frameBusy = false;
      // A frame may have arrived while we were clearing the busy flag.
      final leftover = _pendingShareFrame;
      if (leftover != null && _sharing) {
        _pushFrame(leftover);
      }
    }
  }

  Future<void> _startNativeShare() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    if (_sharing) return;
    if (mounted) setState(() => _sharing = true);
    await MeetingCallKeepAlive.setPipEnabled(false);
    try {
      final ok = await _shareChannel.invokeMethod<bool>('start');
      if (ok == true) {
        // Permission granted — only now attach the desktop track in Jitsi.
        // Starting share before the MediaProjection dialog returns pauses the
        // activity, drops WebRTC, and the leave hook used to kick the sharer.
        await _controller?.runJavaScript(
          'window.__hrmsOnNativeShareReady&&window.__hrmsOnNativeShareReady()',
        );
        return;
      }
    } catch (_) {}
    await _controller?.runJavaScript(
      'window.__hrmsOnNativeShareDenied&&window.__hrmsOnNativeShareDenied()',
    );
    if (mounted) setState(() => _sharing = false);
    if (ref.read(meetingSessionProvider).isActive) {
      await MeetingCallKeepAlive.setPipEnabled(true);
    }
  }

  Future<void> _stopNativeShare() async {
    _pendingShareFrame = null;
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _shareChannel.invokeMethod<bool>('stop');
      } catch (_) {}
    }
    if (mounted && _sharing) setState(() => _sharing = false);
    if (ref.read(meetingSessionProvider).isActive) {
      await MeetingCallKeepAlive.setPipEnabled(true);
    }
  }

  Future<void> _injectLeaveHook() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.runJavaScript(_jitsiLeaveHookJs);
    } catch (_) {}
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

  Future<void> _injectVideoPreviewFix() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.runJavaScript(_jitsiVideoPreviewFixJs);
    } catch (_) {}
  }

  Future<void> _kickMedia() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.runJavaScript('''
        (function() {
          document.querySelectorAll('video').forEach(function(v) {
            try {
              var stream = v.srcObject;
              var live = stream && stream.getVideoTracks && stream.getVideoTracks().some(function(t) {
                return t && t.readyState === 'live' && t.enabled !== false;
              });
              if (live && v.videoWidth > 0) v.play();
            } catch (e) {}
          });
          if (window.__hrmsFixCameraOffAvatars) window.__hrmsFixCameraOffAvatars();
        })();
      ''');
    } catch (_) {}
    await _injectKeepAlive();
    await _injectScreenShare();
    await _injectVideoPreviewFix();
    await _injectJitsiUiFixes();
    await _injectLeaveHook();
  }

  /// Jitsi header icons (close / back / cancel) render as a white circle
  /// in WebView until pressed. Force the outline icons from the pressed state.
  Future<void> _injectJitsiUiFixes() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.runJavaScript(_jitsiIconFixJs);
      await controller.runJavaScript(_jitsiCameraOffAvatarFixJs);
      await _injectSafeTopInset();
    } catch (_) {}
  }

  /// Push the in-call subject / timer below the OS status bar when the
  /// WebView is edge-to-edge in fullscreen.
  Future<void> _injectSafeTopInset() async {
    final controller = _controller;
    if (controller == null || !mounted) return;
    final top = MediaQuery.paddingOf(context).top;
    final px = top > 0 ? top : 28.0;
    try {
      await controller.runJavaScript('''
(function () {
  var top = ${px.toStringAsFixed(1)};
  var css = [
    '.subject,',
    '#videoconference-subject,',
    '.details-container,',
    '.subject-info-container,',
    '.filmstrip__toolbar,',
    '[class*="Subject"] {',
    '  top: ' + top + 'px !important;',
    '  margin-top: 0 !important;',
    '  padding-top: 4px !important;',
    '}',
    '.subject-text, .subject-timer, .conference-timer {',
    '  position: relative;',
    '  z-index: 2;',
    '}'
  ].join('');
  var style = document.getElementById('hrms-safe-top');
  if (!style) {
    style = document.createElement('style');
    style.id = 'hrms-safe-top';
    (document.head || document.documentElement).appendChild(style);
  }
  style.textContent = css;
})();
''');
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

  /// After camera on→off, Android WebView leaves a paused <video> with its
  /// default play glyph. Hide that overlay so Jitsi’s avatar initial shows.
  static const _jitsiCameraOffAvatarFixJs = r'''
(function () {
  if (window.__hrmsCameraOffAvatarReady) {
    if (window.__hrmsFixCameraOffAvatars) window.__hrmsFixCameraOffAvatars();
    return;
  }
  window.__hrmsCameraOffAvatarReady = true;

  function ensureStyle() {
    if (document.getElementById('hrms-camera-off-style') || !document.head) return;
    var style = document.createElement('style');
    style.id = 'hrms-camera-off-style';
    style.textContent = [
      'video::-webkit-media-controls { display: none !important; }',
      'video::-webkit-media-controls-enclosure { display: none !important; }',
      'video::-webkit-media-controls-start-playback-button { display: none !important; }',
      'video::-webkit-media-controls-overlay-play-button { display: none !important; opacity: 0 !important; }',
      'video::-webkit-media-controls-play-button { display: none !important; }',
      'video { -webkit-appearance: none; }',
      'video.hrms-camera-off {',
      '  opacity: 0 !important;',
      '  visibility: hidden !important;',
      '  pointer-events: none !important;',
      '}'
    ].join('');
    document.head.appendChild(style);
  }

  function hasLiveVideo(el) {
    try {
      var stream = el.srcObject;
      if (!stream || !stream.getVideoTracks) return false;
      return stream.getVideoTracks().some(function (t) {
        return t && t.readyState === 'live' && t.enabled !== false;
      });
    } catch (e) {
      return false;
    }
  }

  function isScreenShareVideo(el) {
    try {
      var stream = el.srcObject;
      if (stream && stream.getVideoTracks) {
        var hit = stream.getVideoTracks().some(function (t) {
          if (!t) return false;
          var label = (t.label || '').toLowerCase();
          var hint = (t.contentHint || '').toLowerCase();
          if (hint === 'detail' || hint === 'text') return true;
          return label.indexOf('screen') !== -1 ||
            label.indexOf('display') !== -1 ||
            label.indexOf('window') !== -1 ||
            label === 'screen';
        });
        if (hit) return true;
      }
      var wrap = el.closest
        ? (el.closest('.videocontainer') ||
            el.closest('[class*="tile"]') ||
            el.closest('[data-testid]') ||
            el.parentElement)
        : el.parentElement;
      var text = '';
      if (wrap) {
        text = (
          (wrap.getAttribute('aria-label') || '') +
          ' ' +
          (wrap.getAttribute('title') || '') +
          ' ' +
          (wrap.textContent || '')
        ).toLowerCase();
      }
      return text.indexOf("'s screen") !== -1 ||
        text.indexOf('’s screen') !== -1 ||
        text.indexOf('screen share') !== -1 ||
        text.indexOf('sharing screen') !== -1 ||
        text.indexOf('desktop') !== -1;
    } catch (e) {
      return false;
    }
  }

  window.__hrmsFixCameraOffAvatars = function () {
    ensureStyle();
    var nodes = document.querySelectorAll('video');
    for (var i = 0; i < nodes.length; i++) {
      var el = nodes[i];
      try {
        el.controls = false;
        el.removeAttribute('controls');
        el.setAttribute('playsinline', 'true');
        el.setAttribute('webkit-playsinline', 'true');
      } catch (e) {}
      if (isScreenShareVideo(el)) {
        el.classList.remove('hrms-camera-off');
        try { if (el.paused) el.play(); } catch (e) {}
        continue;
      }
      var live = hasLiveVideo(el);
      var blank = !live || el.readyState < 2 || el.videoWidth === 0;
      if (blank) {
        el.classList.add('hrms-camera-off');
      } else {
        el.classList.remove('hrms-camera-off');
      }
    }
  };

  ensureStyle();
  window.__hrmsFixCameraOffAvatars();

  ['play', 'pause', 'ended', 'emptied', 'loadeddata', 'resize'].forEach(function (evt) {
    document.addEventListener(evt, function (e) {
      if (e && e.target && e.target.tagName === 'VIDEO') {
        window.__hrmsFixCameraOffAvatars();
      }
    }, true);
  });

  if (!window.__hrmsCameraOffObserver && document.documentElement) {
    window.__hrmsCameraOffObserver = new MutationObserver(function () {
      if (window.__hrmsCameraOffScan) return;
      window.__hrmsCameraOffScan = setTimeout(function () {
        window.__hrmsCameraOffScan = null;
        window.__hrmsFixCameraOffAvatars();
      }, 200);
    });
    window.__hrmsCameraOffObserver.observe(document.documentElement, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ['src', 'style', 'class']
    });
  }
  if (!window.__hrmsCameraOffTimer) {
    window.__hrmsCameraOffTimer = setInterval(function () {
      window.__hrmsFixCameraOffAvatars();
    }, 1000);
  }
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
    list.push('desktop');
  }

  function inOverflowMenu(el) {
    return !!(el.closest('.overflow-menu') ||
      el.closest('[class*="overflow-menu"]') ||
      el.closest('[class*="OverflowMenu"]') ||
      el.closest('[class*="drawer"]') ||
      el.closest('[role="menu"]') ||
      el.closest('[role="dialog"]') ||
      el.closest('.toolbox-dialog'));
  }

  function isMenuContainer(el) {
    if (!el || !el.getAttribute) return false;
    var role = (el.getAttribute('role') || '').toLowerCase();
    if (role === 'menu' || role === 'dialog' || role === 'listbox') return true;
    var cls = ((el.className && el.className.toString()) || '').toLowerCase();
    return cls.indexOf('overflow-menu') !== -1 && cls.indexOf('overflow-menu-item') === -1;
  }

  function isClickableItem(el) {
    if (!el || el.nodeType !== 1) return false;
    var tag = (el.tagName || '').toLowerCase();
    var role = (el.getAttribute('role') || '').toLowerCase();
    var cls = ((el.className && el.className.toString()) || '').toLowerCase();
    return tag === 'button' || tag === 'a' || tag === 'li' ||
      role === 'menuitem' || role === 'button' ||
      cls.indexOf('overflow-menu-item') !== -1 ||
      cls.indexOf('toolbox-button') !== -1;
  }

  function labelOf(el) {
    if (!el) return '';
    var aria = ((el.getAttribute && (el.getAttribute('aria-label') || el.getAttribute('title'))) || '');
    var text = ((el.innerText || el.textContent || '').replace(/\s+/g, ' ')).trim();
    if (text.length > 48) text = text.slice(0, 48);
    return (aria + ' ' + text).toLowerCase();
  }

  function isShareLabel(label) {
    label = (label || '').toLowerCase();
    if (!label) return false;
    if (label.indexOf('invite') !== -1 || label.indexOf('copy') !== -1) return false;
    return label.indexOf('share your screen') !== -1 ||
      label.indexOf('start screen sharing') !== -1 ||
      label.indexOf('stop sharing your screen') !== -1 ||
      label.indexOf('stop screen sharing') !== -1 ||
      label.indexOf('screenshare') !== -1 ||
      label.indexOf('screen sharing') !== -1 ||
      label.indexOf('screen share') !== -1 ||
      label.indexOf('screen-sharing') !== -1 ||
      (label.indexOf('desktop') !== -1 && label.indexOf('share') !== -1);
  }

  function findShareTarget(el) {
    var cur = el;
    for (var i = 0; i < 8 && cur && cur !== document.body; i++) {
      if (isMenuContainer(cur)) break;
      if (isClickableItem(cur) && isShareLabel(labelOf(cur))) return cur;
      cur = cur.parentElement;
    }
    return null;
  }

  function removeBottomShareButton() {
    var extra = document.getElementById('hrms-screen-share');
    if (extra && extra.parentNode) extra.parentNode.removeChild(extra);
    var nodes = document.querySelectorAll('.toolbox-content-items > button, .toolbox-content-items > span > button');
    for (var i = 0; i < nodes.length; i++) {
      var el = nodes[i];
      if (inOverflowMenu(el)) continue;
      if (!isShareLabel(labelOf(el))) continue;
      el.style.setProperty('display', 'none', 'important');
    }
  }

  function enableOverflowShareItems() {
    var nodes = document.querySelectorAll('button, [role="menuitem"], [role="button"], li, a, div, span');
    for (var i = 0; i < nodes.length; i++) {
      var el = nodes[i];
      if (!isShareLabel(labelOf(el))) continue;
      try {
        el.removeAttribute('disabled');
        el.setAttribute('aria-disabled', 'false');
        el.style.pointerEvents = 'auto';
        el.style.opacity = '1';
      } catch (e) {}
    }
  }

  window.__hrmsEnableDesktopShare = function () {
    try { patch(window.JitsiMeetJS); } catch (e) {}
    try { patch(window.JitsiMeetJS && JitsiMeetJS.util && JitsiMeetJS.util.browser); } catch (e) {}
    try { patch(window.JitsiMeetJS && JitsiMeetJS.util && JitsiMeetJS.util.BrowserDetection); } catch (e) {}
    try {
      if (window.JitsiMeetJS && typeof JitsiMeetJS.isDesktopSharingEnabled === 'function') {
        JitsiMeetJS.isDesktopSharingEnabled = function () { return true; };
      }
    } catch (e) {}
    try {
      if (window.config) {
        config.disableScreensharing = false;
        config.desktopSharingEnabled = true;
        ensureDesktopInList(config.toolbarButtons);
      }
    } catch (e) {}
    try {
      if (window.interfaceConfig) {
        ensureDesktopInList(interfaceConfig.TOOLBAR_BUTTONS);
      }
    } catch (e) {}
    removeBottomShareButton();
    enableOverflowShareItems();
    hookOverflowShareItems();
  };

  window.__hrmsMarkSharing = function (on) {
    window.__hrmsSharing = !!on;
    if (!on) window.__hrmsShareStarting = false;
  };

  // Fixed-size canvas must stay in the DOM. Resizing after captureStream()
  // resets the track and remotes only see a black tile.
  // Keep the bitmap full-size and CSS-scaled tiny but ON-SCREEN + opaque so
  // Android WebView keeps compositing / sampling frames.
  window.__hrmsEnsureShareCanvas = function () {
    var canvas = window.__hrmsScreenCanvas;
    if (!canvas) {
      canvas = document.createElement('canvas');
      canvas.id = 'hrms-screen-share-canvas';
      canvas.width = 1280;
      canvas.height = 720;
      canvas.setAttribute('width', '1280');
      canvas.setAttribute('height', '720');
      canvas.style.cssText = 'position:fixed;left:0;top:0;width:1280px;height:720px;transform:scale(0.001);transform-origin:0 0;opacity:1;pointer-events:none;z-index:1;';
      window.__hrmsScreenCanvas = canvas;
      window.__hrmsScreenCtx = canvas.getContext('2d', { alpha: false, willReadFrequently: false });
    }
    if (!canvas.isConnected) {
      var root = document.body || document.documentElement;
      if (root) root.appendChild(canvas);
    }
    return canvas;
  };

  window.__hrmsBlitShareImage = function (img) {
    var canvas = window.__hrmsEnsureShareCanvas();
    var ctx = window.__hrmsScreenCtx;
    var iw = (img && (img.naturalWidth || img.width)) || 0;
    var ih = (img && (img.naturalHeight || img.height)) || 0;
    if (!canvas || !ctx || !img || !iw) return false;
    try {
      // Do NOT change canvas.width/height here — that kills captureStream.
      ctx.fillStyle = '#111827';
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      var scale = Math.min(canvas.width / iw, canvas.height / ih);
      var w = Math.max(1, iw * scale);
      var h = Math.max(1, ih * scale);
      var x = (canvas.width - w) / 2;
      var y = (canvas.height - h) / 2;
      ctx.drawImage(img, x, y, w, h);
      window.__hrmsLastShareDrawAt = Date.now();
      window.__hrmsRequestShareFrame();
      return true;
    } catch (e) {
      return false;
    }
  };

  window.__hrmsRequestShareFrame = function () {
    try {
      var stream = window.__hrmsScreenStream;
      var track = stream && stream.getVideoTracks && stream.getVideoTracks()[0];
      if (track && typeof track.requestFrame === 'function') track.requestFrame();
    } catch (e) {}
  };

  window.__hrmsNotifyShareReady = function () {
    if (window.__hrmsAwaitingFirstFrame) {
      window.__hrmsAwaitingFirstFrame = false;
      if (window.__hrmsBeginShareAfterFirstFrame) {
        window.__hrmsBeginShareAfterFirstFrame();
      }
    }
    if (window.__hrmsPendingDisplayMedia) {
      var pending = window.__hrmsPendingDisplayMedia;
      window.__hrmsPendingDisplayMedia = null;
      try {
        window.__hrmsCanvasDisplayMedia().then(pending.resolve, pending.reject);
      } catch (e) {
        try { pending.reject(e); } catch (e2) {}
      }
    }
  };

  window.__hrmsDrawScreen = function (b64) {
    var canvas = window.__hrmsEnsureShareCanvas();
    var ctx = window.__hrmsScreenCtx;
    if (!canvas || !ctx || !b64) return;
    window.__hrmsDrawGen = (window.__hrmsDrawGen || 0) + 1;
    var gen = window.__hrmsDrawGen;
    var dataUrl = 'data:image/jpeg;base64,' + b64;

    function onDecoded(img) {
      if (gen !== window.__hrmsDrawGen) return;
      window.__hrmsScreenImg = img;
      if (!window.__hrmsBlitShareImage(img)) return;
      window.__hrmsNotifyShareReady();
    }

    // createImageBitmap is faster / more reliable than Image+src races.
    if (typeof createImageBitmap === 'function' && typeof fetch === 'function') {
      try {
        fetch(dataUrl).then(function (r) { return r.blob(); }).then(function (blob) {
          return createImageBitmap(blob);
        }).then(onDecoded).catch(function () {
          fallbackImage();
        });
        return;
      } catch (e) {}
    }

    function fallbackImage() {
      var img = window.__hrmsScreenImgEl || new Image();
      window.__hrmsScreenImgEl = img;
      img.onload = function () { onDecoded(img); };
      img.onerror = function () {};
      img.src = dataUrl;
    }
    fallbackImage();
  };

  window.__hrmsStopSharePump = function () {
    if (window.__hrmsShareRaf) {
      try { cancelAnimationFrame(window.__hrmsShareRaf); } catch (e) {}
      window.__hrmsShareRaf = 0;
    }
  };

  window.__hrmsStartSharePump = function () {
    if (window.__hrmsShareRaf) return;
    var tick = function () {
      window.__hrmsShareRaf = requestAnimationFrame(tick);
      if (!window.__hrmsSharing) return;
      try {
        var img = window.__hrmsScreenImg;
        if (img) window.__hrmsBlitShareImage(img);
        else window.__hrmsRequestShareFrame();
      } catch (e) {
        window.__hrmsRequestShareFrame();
      }
    };
    tick();
  };

  window.__hrmsCancelScreenShare = function () {
    window.__hrmsShareEnding = true;
    window.__hrmsShareStarting = false;
    window.__hrmsAwaitingFirstFrame = false;
    window.__hrmsStopSharePump();
    var stream = window.__hrmsScreenStream;
    window.__hrmsScreenStream = null;
    window.__hrmsLastShareDrawAt = 0;
    window.__hrmsScreenImg = null;
    window.__hrmsMarkSharing(false);
    if (!stream) return;
    stream.getTracks().forEach(function (track) {
      try { track.stop(); } catch (e) {}
    });
  };

  function stopJitsiScreenShare() {
    try {
      if (window.APP && APP.conference && typeof APP.conference.toggleScreenSharing === 'function') {
        var stop = APP.conference.toggleScreenSharing(false);
        if (stop && typeof stop.catch === 'function') stop.catch(function () {});
      }
    } catch (e) {}
  }

  window.__hrmsOnNativeShareDenied = function () {
    window.__hrmsShareStarting = false;
    if (window.__hrmsPendingDisplayMedia) {
      var p = window.__hrmsPendingDisplayMedia;
      window.__hrmsPendingDisplayMedia = null;
      try {
        p.reject(new DOMException('Permission denied', 'NotAllowedError'));
      } catch (e) {}
    }
    window.__hrmsCancelScreenShare();
    stopJitsiScreenShare();
  };

  window.__hrmsOnNativeShareStopped = function () {
    window.__hrmsShareStarting = false;
    if (window.__hrmsPendingDisplayMedia) {
      var p = window.__hrmsPendingDisplayMedia;
      window.__hrmsPendingDisplayMedia = null;
      try {
        p.reject(new DOMException('Screen share stopped', 'AbortError'));
      } catch (e) {}
    }
    window.__hrmsCancelScreenShare();
    stopJitsiScreenShare();
  };

  window.__hrmsCanvasDisplayMedia = function () {
    if (window.__hrmsScreenStream && window.__hrmsSharing) {
      return Promise.resolve(window.__hrmsScreenStream);
    }
    var canvas = window.__hrmsEnsureShareCanvas();
    var ctx = window.__hrmsScreenCtx;
    // Keep live JPEG pixels. Never paint a "Sharing screen…" placard —
    // remotes were freezing on that text forever.
    if (window.__hrmsScreenImg) {
      window.__hrmsBlitShareImage(window.__hrmsScreenImg);
    } else if (ctx) {
      try {
        ctx.fillStyle = '#111827';
        ctx.fillRect(0, 0, canvas.width, canvas.height);
      } catch (e) {}
    }
    // IMPORTANT: do NOT use captureStream(0) on Android WebView.
    // requestFrame() is often missing/no-op there, so fps=0 → black forever.
    var stream = canvas.captureStream(15);
    window.__hrmsScreenStream = stream;
    window.__hrmsShareEnding = false;
    window.__hrmsMarkSharing(true);
    window.__hrmsStartSharePump();
    var track = stream.getVideoTracks()[0];
    if (track) {
      try { track.contentHint = 'detail'; } catch (e) {}
      try { track.enabled = true; } catch (e) {}
      try {
        Object.defineProperty(track, 'label', {
          configurable: true,
          get: function () { return 'Screen'; }
        });
      } catch (e) {}
      var origStop = track.stop.bind(track);
      track.stop = function () {
        try {
          if (!window.__hrmsShareEnding && window.HrmsScreenShare) {
            HrmsScreenShare.postMessage('stop');
          }
        } catch (e) {}
        window.__hrmsShareEnding = false;
        window.__hrmsMarkSharing(false);
        window.__hrmsStopSharePump();
        origStop();
      };
    }
    window.__hrmsRequestShareFrame();
    return Promise.resolve(stream);
  };

  window.__hrmsWaitForNativeDisplayMedia = function () {
    // If we already painted at least one native JPEG, return the canvas
    // stream immediately (do not wait for another frame — that raced and
    // left remotes on a black tile forever).
    if (window.__hrmsLastShareDrawAt) {
      return window.__hrmsCanvasDisplayMedia();
    }
    if (window.__hrmsScreenStream && window.__hrmsSharing) {
      return Promise.resolve(window.__hrmsScreenStream);
    }
    return new Promise(function (resolve, reject) {
      if (window.__hrmsPendingDisplayMedia) {
        var prev = window.__hrmsPendingDisplayMedia;
        window.__hrmsPendingDisplayMedia = {
          resolve: function (s) { try { prev.resolve(s); } catch (e) {} resolve(s); },
          reject: function (e) { try { prev.reject(e); } catch (e2) {} reject(e); }
        };
      } else {
        window.__hrmsPendingDisplayMedia = { resolve: resolve, reject: reject };
      }
      var timer = setTimeout(function () {
        if (!window.__hrmsPendingDisplayMedia) return;
        var p = window.__hrmsPendingDisplayMedia;
        window.__hrmsPendingDisplayMedia = null;
        try {
          p.reject(new DOMException('Screen share timed out', 'NotAllowedError'));
        } catch (e) {
          try { p.reject(e); } catch (e2) {}
        }
      }, 90000);
      var origResolve = window.__hrmsPendingDisplayMedia.resolve;
      var origReject = window.__hrmsPendingDisplayMedia.reject;
      window.__hrmsPendingDisplayMedia.resolve = function (s) {
        clearTimeout(timer);
        origResolve(s);
      };
      window.__hrmsPendingDisplayMedia.reject = function (e) {
        clearTimeout(timer);
        origReject(e);
      };
      // If native capture already running, just wait for the first JPEG.
      if (window.__hrmsShareStarting || window.__hrmsLastShareDrawAt) return;
      window.__hrmsShareStarting = true;
      try {
        if (window.HrmsScreenShare) {
          HrmsScreenShare.postMessage('start');
        } else {
          window.__hrmsPendingDisplayMedia.reject(new Error('Screen share unavailable'));
          window.__hrmsPendingDisplayMedia = null;
        }
      } catch (e) {
        window.__hrmsPendingDisplayMedia.reject(e);
        window.__hrmsPendingDisplayMedia = null;
      }
    });
  };

  function attachDesktopTrack(stream) {
    if (!stream || !window.JitsiMeetJS) return Promise.resolve();
    var make = function () {
      if (typeof JitsiMeetJS.createLocalTracksFromMediaStreams !== 'function') {
        return Promise.reject(new Error('no factory'));
      }
      var made = JitsiMeetJS.createLocalTracksFromMediaStreams([{
        stream: stream,
        sourceType: 'window',
        mediaType: 'video',
        videoType: 'desktop'
      }]);
      return Promise.resolve(made);
    };
    return make().then(function (tracks) {
      var track = tracks && tracks[0];
      if (!track || !window.APP || !APP.conference) return;
      if (typeof APP.conference.addTrack === 'function') return APP.conference.addTrack(track);
      if (APP.conference._room && typeof APP.conference._room.addTrack === 'function') {
        return APP.conference._room.addTrack(track);
      }
    });
  }

  function beginJitsiScreenShare() {
    patchDisplayMedia();
    window.__hrmsEnableDesktopShare();
    patchCreateLocalTracks();
    // Warm the canvas stream first so getDisplayMedia / createLocalTracks
    // return live screen pixels (not an empty placard).
    var streamP = window.__hrmsCanvasDisplayMedia();
    streamP.then(function (stream) {
      var usedToggle = false;
      try {
        if (window.APP && APP.conference && typeof APP.conference.toggleScreenSharing === 'function') {
          usedToggle = true;
          var result = APP.conference.toggleScreenSharing(true);
          if (result && typeof result.then === 'function') {
            result.then(function () {
              window.__hrmsRequestShareFrame();
              window.__hrmsStartSharePump();
            }).catch(function () {
              attachDesktopTrack(stream).then(function () {
                window.__hrmsRequestShareFrame();
                window.__hrmsStartSharePump();
              }).catch(function () {});
            });
            return;
          }
        }
      } catch (e) {
        usedToggle = false;
      }
      if (!usedToggle) {
        attachDesktopTrack(stream).then(function () {
          window.__hrmsRequestShareFrame();
          window.__hrmsStartSharePump();
        }).catch(function () {});
      }
    }).catch(function () {});
  }

  // Called from Flutter only after MediaProjection permission is granted.
  // Wait for the first real JPEG so the first WebRTC keyframe is not black.
  window.__hrmsOnNativeShareReady = function () {
    window.__hrmsShareStarting = true;
    window.__hrmsEnsureShareCanvas();
    window.__hrmsBeginShareAfterFirstFrame = function () {
      window.__hrmsBeginShareAfterFirstFrame = null;
      if (window.__hrmsFirstFrameTimer) {
        try { clearTimeout(window.__hrmsFirstFrameTimer); } catch (e) {}
        window.__hrmsFirstFrameTimer = 0;
      }
      beginJitsiScreenShare();
      // Resolve any getDisplayMedia() waiter that raced the first frame.
      if (window.__hrmsPendingDisplayMedia && window.__hrmsLastShareDrawAt) {
        var pending = window.__hrmsPendingDisplayMedia;
        window.__hrmsPendingDisplayMedia = null;
        window.__hrmsCanvasDisplayMedia().then(pending.resolve, pending.reject);
      }
    };
    if (window.__hrmsLastShareDrawAt && (Date.now() - window.__hrmsLastShareDrawAt) < 2500) {
      window.__hrmsBeginShareAfterFirstFrame();
      return;
    }
    window.__hrmsAwaitingFirstFrame = true;
    if (window.__hrmsFirstFrameTimer) {
      try { clearTimeout(window.__hrmsFirstFrameTimer); } catch (e) {}
    }
    // Do NOT fall back to starting with an empty canvas — that is the black screen.
    // Keep waiting for a real frame (native capture can take a moment after consent).
    window.__hrmsFirstFrameTimer = setTimeout(function () {
      window.__hrmsFirstFrameTimer = 0;
      if (!window.__hrmsAwaitingFirstFrame) return;
      if (window.__hrmsLastShareDrawAt) {
        window.__hrmsAwaitingFirstFrame = false;
        if (window.__hrmsBeginShareAfterFirstFrame) window.__hrmsBeginShareAfterFirstFrame();
        return;
      }
      // Still no pixels — keep waiting a bit longer once, then fail cleanly.
      window.__hrmsFirstFrameTimer = setTimeout(function () {
        window.__hrmsFirstFrameTimer = 0;
        if (!window.__hrmsAwaitingFirstFrame) return;
        window.__hrmsAwaitingFirstFrame = false;
        if (window.__hrmsLastShareDrawAt && window.__hrmsBeginShareAfterFirstFrame) {
          window.__hrmsBeginShareAfterFirstFrame();
          return;
        }
        window.__hrmsOnNativeShareDenied();
      }, 4000);
    }, 2500);
  };

  window.__hrmsStartOrStopShare = function () {
    patchDisplayMedia();
    window.__hrmsEnableDesktopShare();
    patchCreateLocalTracks();
    if (window.__hrmsSharing || window.__hrmsShareStarting) {
      window.__hrmsShareStarting = false;
      stopJitsiScreenShare();
      window.__hrmsCancelScreenShare();
      try { if (window.HrmsScreenShare) HrmsScreenShare.postMessage('stop'); } catch (e) {}
      return;
    }
    // Request native capture first. Do NOT toggle Jitsi share until Flutter
    // calls __hrmsOnNativeShareReady — otherwise the consent dialog backgrounds
    // the WebView and the leave hook disconnects the sharer after a few seconds.
    window.__hrmsShareStarting = true;
    if (!window.__hrmsUseCanvasShare) {
      beginJitsiScreenShare();
      return;
    }
    try {
      if (window.HrmsScreenShare) {
        HrmsScreenShare.postMessage('start');
        return;
      }
    } catch (e) {}
    window.__hrmsShareStarting = false;
    beginJitsiScreenShare();
  };

  function patchDisplayMedia() {
    if (!window.__hrmsUseCanvasShare) return;
    // Always wait until native MediaProjection frames exist. Returning an
    // empty canvas here is what made remotes see a black "X's screen".
    var getter = function () {
      return window.__hrmsWaitForNativeDisplayMedia();
    };
    try {
      if (navigator.mediaDevices) {
        navigator.mediaDevices.getDisplayMedia = getter;
      }
    } catch (e) {}
    try {
      navigator.getDisplayMedia = getter;
    } catch (e) {}
  }

  function patchCreateLocalTracks() {
    if (!window.JitsiMeetJS || typeof JitsiMeetJS.createLocalTracks !== 'function') return;
    if (JitsiMeetJS.__hrmsTracksWrapped) return;
    JitsiMeetJS.__hrmsTracksWrapped = true;
    var orig = JitsiMeetJS.createLocalTracks.bind(JitsiMeetJS);
    JitsiMeetJS.createLocalTracks = function (options) {
      var devices = (options && options.devices) || [];
      if (window.__hrmsUseCanvasShare && devices.indexOf('desktop') !== -1) {
        return window.__hrmsWaitForNativeDisplayMedia().then(function (stream) {
          if (typeof JitsiMeetJS.createLocalTracksFromMediaStreams === 'function') {
            return Promise.resolve(JitsiMeetJS.createLocalTracksFromMediaStreams([{
              stream: stream,
              sourceType: 'window',
              mediaType: 'video',
              videoType: 'desktop'
            }]));
          }
          return orig(options);
        });
      }
      return orig(options);
    };
  }

  function onShareGesture(e) {
    var target = findShareTarget(e.target);
    if (!target) return;
    if (!inOverflowMenu(target) && target.closest && target.closest('.toolbox-content-items') && !target.closest('[role="menu"]')) {
      return;
    }
    var now = Date.now();
    if (window.__hrmsShareTapAt && now - window.__hrmsShareTapAt < 700) {
      e.preventDefault();
      e.stopPropagation();
      if (e.stopImmediatePropagation) e.stopImmediatePropagation();
      return;
    }
    window.__hrmsShareTapAt = now;
    e.preventDefault();
    e.stopPropagation();
    if (e.stopImmediatePropagation) e.stopImmediatePropagation();
    window.__hrmsStartOrStopShare();
  }

  function ensureStyle() {
    if (document.getElementById('hrms-screen-share-style') || !document.head) return;
    var style = document.createElement('style');
    style.id = 'hrms-screen-share-style';
    style.textContent = [
      '#hrms-screen-share{display:none!important;}',
      '#new-toolbox .toolbox-content-items > button[aria-label*="Share your screen"],',
      '#new-toolbox .toolbox-content-items > span > button[aria-label*="Share your screen"],',
      '.new-toolbox .toolbox-content-items > button[aria-label*="Share your screen"]{display:none!important;}'
    ].join('');
    document.head.appendChild(style);
  }

  function hookOverflowShareItems() {
    var nodes = document.querySelectorAll('button, [role="menuitem"], [role="button"], li, a, div');
    for (var i = 0; i < nodes.length; i++) {
      var el = nodes[i];
      if (el.getAttribute('data-hrms-share-hook') === '1') continue;
      if (!isClickableItem(el) || !isShareLabel(labelOf(el))) continue;
      el.setAttribute('data-hrms-share-hook', '1');
      el.addEventListener('click', function (e) {
        e.preventDefault();
        e.stopPropagation();
        if (e.stopImmediatePropagation) e.stopImmediatePropagation();
        window.__hrmsStartOrStopShare();
      }, true);
    }
  }

  function hookGestures() {
    if (window.__hrmsShareClickHooked || !document.addEventListener) return;
    window.__hrmsShareClickHooked = true;
    document.addEventListener('click', onShareGesture, true);
    document.addEventListener('touchend', onShareGesture, true);
  }

  patchDisplayMedia();
  patchCreateLocalTracks();
  window.__hrmsEnableDesktopShare();
  ensureStyle();
  hookGestures();
  if (!window.__hrmsSharePatchTimer) {
    window.__hrmsSharePatchTimer = setInterval(function () {
      patchDisplayMedia();
      patchCreateLocalTracks();
      window.__hrmsEnableDesktopShare();
      hookGestures();
    }, 800);
  }
})();
''';

  static const _jitsiLeaveHookJs = r'''
(function () {
  if (window.__hrmsLeaveHookReady) {
    if (window.__hrmsArmLeaveHook) window.__hrmsArmLeaveHook();
    return;
  }
  window.__hrmsLeaveHookReady = true;

  function hideMeetingUi() {
    try {
      document.documentElement.style.background = '#000';
      if (document.body) {
        document.body.style.background = '#000';
        document.body.style.opacity = '0';
      }
    } catch (e) {}
  }

  function notifyLeft() {
    if (window.__hrmsLeftSent || !window.__hrmsJoinedSent) return;
    window.__hrmsLeftSent = true;
    if (window.__hrmsLeftTimer) {
      clearTimeout(window.__hrmsLeftTimer);
      window.__hrmsLeftTimer = null;
    }
    hideMeetingUi();
    try { if (window.HrmsMeeting) HrmsMeeting.postMessage('left'); } catch (e) {}
  }

  function stillInCall() {
    try {
      return !!(window.APP && APP.conference && typeof APP.conference.isJoined === 'function' && APP.conference.isJoined());
    } catch (e) {
      return false;
    }
  }

  function notifyJoined() {
    if (!stillInCall()) return;
    window.__hrmsJoinedSent = true;
    if (window.__hrmsLeftTimer) {
      clearTimeout(window.__hrmsLeftTimer);
      window.__hrmsLeftTimer = null;
    }
    if (window.__hrmsJoinedPosted) return;
    window.__hrmsJoinedPosted = true;
    try { if (window.HrmsMeeting) HrmsMeeting.postMessage('joined'); } catch (e) {}
  }

  function shouldIgnoreTransientLeave() {
    return !!(window.__hrmsAppBackgrounded ||
      window.__hrmsPipMode ||
      window.__hrmsPipRestoreGrace ||
      window.__hrmsShareStarting ||
      window.__hrmsSharing);
  }

  // Prosody sets member/owner affiliation while the occupant joins (lobby bypass).
  // That emits CONFERENCE_LEFT and then joins again. Wait before closing HRMS.
  // Screen-share MediaProjection consent, home minimize, and PiP restore also
  // briefly drop WebRTC — do not treat that as a real hangup.
  function scheduleLeft(fromHangup) {
    if (!window.__hrmsJoinedSent || window.__hrmsLeftSent) return;
    if (window.__hrmsLeftTimer) clearTimeout(window.__hrmsLeftTimer);
    if (!fromHangup && shouldIgnoreTransientLeave()) {
      // Stay in the meeting while HRMS is minimized / in PiP / restoring.
      return;
    }
    var shareBusy = !fromHangup && (window.__hrmsShareStarting || window.__hrmsSharing);
    var delay = shareBusy ? 12000 : 2500;
    window.__hrmsLeftTimer = setTimeout(function () {
      window.__hrmsLeftTimer = null;
      if (stillInCall()) return;
      if (!fromHangup && shouldIgnoreTransientLeave()) return;
      if (!fromHangup && window.__hrmsShareStarting) {
        scheduleLeft(false);
        return;
      }
      notifyLeft();
    }, delay);
  }

  window.__hrmsCheckStillInCallAfterResume = function () {
    if (window.__hrmsLeftSent) return;
    if (shouldIgnoreTransientLeave()) return;
    if (stillInCall()) {
      window.__hrmsJoinedSent = true;
      return;
    }
    // Give ICE a moment to recover after the activity resumes.
    if (window.__hrmsLeftTimer) clearTimeout(window.__hrmsLeftTimer);
    window.__hrmsLeftTimer = setTimeout(function () {
      window.__hrmsLeftTimer = null;
      if (stillInCall() || shouldIgnoreTransientLeave()) return;
      notifyLeft();
    }, 8000);
  };

  function wrapHangup() {
    try {
      if (!window.APP || !APP.conference || typeof APP.conference.hangup !== 'function') return;
      if (APP.conference.__hrmsHangupWrapped) return;
      APP.conference.__hrmsHangupWrapped = true;
      var orig = APP.conference.hangup.bind(APP.conference);
      APP.conference.hangup = function () {
        scheduleLeft(true);
        return orig.apply(APP.conference, arguments);
      };
    } catch (e) {}
  }

  function listenConferenceLeft() {
    try {
      if (!window.APP || !APP.conference) return;
      var room = APP.conference._room;
      if (!room || typeof room.on !== 'function' || room.__hrmsLeftHooked) return;
      if (!window.JitsiMeetJS || !JitsiMeetJS.events || !JitsiMeetJS.events.conference) return;
      room.__hrmsLeftHooked = true;
      room.on(JitsiMeetJS.events.conference.CONFERENCE_LEFT, function () {
        scheduleLeft(false);
      });
      if (JitsiMeetJS.events.conference.CONFERENCE_JOINED) {
        room.on(JitsiMeetJS.events.conference.CONFERENCE_JOINED, notifyJoined);
      }
    } catch (e) {}
  }

  function disableClosePage() {
    try {
      if (window.config) {
        config.enableClosePage = false;
        config.enableWelcomePage = false;
      }
    } catch (e) {}
    try {
      if (window.interfaceConfig) {
        interfaceConfig.SHOW_PROMOTIONAL_CLOSE_PAGE = false;
      }
    } catch (e) {}
    muteUiSounds();
  }

  // Mute Jitsi UI clips only (/sounds/*). Do not touch WebRTC call audio.
  function muteUiSounds() {
    try {
      if (window.config) {
        config.disableSounds = true;
        config.disableRecordAudioNotification = true;
        var extra = [
          'PARTICIPANT_JOINED_SOUND','PARTICIPANT_LEFT_SOUND','INCOMING_MSG_SOUND',
          'OUTGOING_CALL_EXPIRED_SOUND','OUTGOING_CALL_REJECTED_SOUND',
          'OUTGOING_CALL_RINGING_SOUND','OUTGOING_CALL_START_SOUND',
          'RAISE_HAND_SOUND','REACTION_SOUND','TALK_WHILE_MUTED_SOUND',
          'NO_AUDIO_SIGNAL_SOUND','E2EE_ON_SOUND','E2EE_OFF_SOUND',
          'RECORDING_ON_SOUND','RECORDING_OFF_SOUND',
          'TRANSCRIPTION_ON_SOUND','TRANSCRIPTION_OFF_SOUND',
          'RECORDING_AND_TRANSCRIPTION_ON_SOUND','RECORDING_AND_TRANSCRIPTION_OFF_SOUND',
          'LIVE_STREAMING_ON_SOUND','LIVE_STREAMING_OFF_SOUND'
        ];
        var cur = Array.isArray(config.disabledSounds) ? config.disabledSounds.slice() : [];
        for (var i = 0; i < extra.length; i++) {
          if (cur.indexOf(extra[i]) === -1) cur.push(extra[i]);
        }
        config.disabledSounds = cur;
      }
    } catch (e) {}
    try {
      if (!window.__hrmsUiSoundPatched && window.HTMLAudioElement) {
        window.__hrmsUiSoundPatched = true;
        var origPlay = HTMLAudioElement.prototype.play;
        HTMLAudioElement.prototype.play = function () {
          var src = ((this.currentSrc || this.src || '') + '').toString();
          if (/\/sounds\//i.test(src) || /ring\.mp3/i.test(src)) {
            try { this.pause(); this.currentTime = 0; } catch (e) {}
            return Promise.resolve();
          }
          return origPlay.apply(this, arguments);
        };
      }
    } catch (e) {}
    try {
      var nodes = document.querySelectorAll('audio');
      for (var a = 0; a < nodes.length; a++) {
        var el = nodes[a];
        var src = ((el.currentSrc || el.src || '') + '').toString();
        if (!/\/sounds\//i.test(src) && !/ring\.mp3/i.test(src)) continue;
        try { el.pause(); el.currentTime = 0; el.muted = true; } catch (e) {}
      }
    } catch (e) {}
  }

  function isHangupLabel(text) {
    return text.indexOf('hang up') !== -1 ||
      text.indexOf('leave the meeting') !== -1 ||
      text.indexOf('leave meeting') !== -1 ||
      text.indexOf('end meeting') !== -1 ||
      text.indexOf('end call') !== -1;
  }

  function hookConfirmButtons() {
    var nodes = document.querySelectorAll('button');
    for (var i = 0; i < nodes.length; i++) {
      var el = nodes[i];
      if (el.getAttribute('data-hrms-hangup-confirm') === '1') continue;
      var text = ((el.getAttribute('aria-label') || '') + ' ' + (el.getAttribute('title') || '') + ' ' + (el.textContent || '')).toLowerCase();
      if (!isHangupLabel(text)) continue;
      el.setAttribute('data-hrms-hangup-confirm', '1');
      el.addEventListener('click', function () {
        var inToolbar = !!(this.closest('#new-toolbox') || this.closest('.new-toolbox') || this.closest('.toolbox-content-items'));
        if (!inToolbar) {
          notifyLeft();
          return;
        }
        scheduleLeft(true);
      }, true);
    }
  }

  function checkWelcomeAfterLeave() {
    if (!window.__hrmsJoinedSent) return;
    var path = (location.pathname || '').toLowerCase();
    if (path.indexOf('close') !== -1) scheduleLeft(false);
  }

  window.__hrmsArmLeaveHook = function () {
    disableClosePage();
    wrapHangup();
    listenConferenceLeft();
    notifyJoined();
    hookConfirmButtons();
    checkWelcomeAfterLeave();
  };

  window.__hrmsArmLeaveHook();
  if (!window.__hrmsLeaveHookTimer) {
    window.__hrmsLeaveHookTimer = setInterval(function () {
      window.__hrmsArmLeaveHook();
    }, 700);
  }
})();
''';

  /// Android WebView often cannot open a second camera stream while the
  /// meeting already holds the device. Jitsi Video settings then shows a
  /// black preview. Reuse / clone the live local track for settings previews.
  static const _jitsiVideoPreviewFixJs = r'''
(function () {
  if (window.__hrmsVideoPreviewFixReady) {
    if (window.__hrmsFixVideoPreviews) window.__hrmsFixVideoPreviews();
    return;
  }
  window.__hrmsVideoPreviewFixReady = true;

  function isScreenTrack(track) {
    if (!track) return true;
    var label = ((track.label || '') + ' ' + (track.contentHint || '')).toLowerCase();
    return label.indexOf('screen') !== -1 || label.indexOf('display') !== -1 || label.indexOf('web contents') !== -1;
  }

  function streamFromJitsiLocal() {
    try {
      if (!window.APP || !APP.conference) return null;
      var track = null;
      if (typeof APP.conference.getLocalVideoTrack === 'function') {
        track = APP.conference.getLocalVideoTrack();
      }
      if (!track && APP.conference._room && typeof APP.conference._room.getLocalVideoTrack === 'function') {
        track = APP.conference._room.getLocalVideoTrack();
      }
      if (!track) return null;
      var media = null;
      if (track.stream) media = track.stream;
      else if (typeof track.getOriginalStream === 'function') media = track.getOriginalStream();
      else if (typeof track.getTrack === 'function') {
        var mt = track.getTrack();
        if (mt) media = new MediaStream([mt]);
      } else if (track.track) {
        media = new MediaStream([track.track]);
      }
      if (!media) return null;
      var vtracks = media.getVideoTracks();
      if (!vtracks.length || isScreenTrack(vtracks[0])) return null;
      if (vtracks[0].readyState === 'ended') return null;
      return media;
    } catch (e) {
      return null;
    }
  }

  function streamFromDomVideos() {
    try {
      var nodes = document.querySelectorAll('video');
      for (var i = 0; i < nodes.length; i++) {
        var el = nodes[i];
        if (inSettingsDialog(el)) continue;
        var stream = el.srcObject;
        if (!stream) continue;
        var tracks = stream.getVideoTracks();
        if (!tracks.length || isScreenTrack(tracks[0])) continue;
        if (tracks[0].readyState !== 'live') continue;
        if (el.videoWidth > 0 || !el.paused) return stream;
      }
    } catch (e) {}
    return null;
  }

  function getLocalCameraStream() {
    return streamFromJitsiLocal() || streamFromDomVideos();
  }

  function cloneVideoOnly(stream) {
    try {
      var cloned = stream.clone();
      cloned.getAudioTracks().forEach(function (t) {
        try { t.stop(); } catch (e) {}
        try { cloned.removeTrack(t); } catch (e) {}
      });
      return cloned;
    } catch (e) {
      try {
        var tracks = stream.getVideoTracks().filter(function (t) { return !isScreenTrack(t); });
        if (!tracks.length) return null;
        return new MediaStream(tracks.map(function (t) {
          try { return t.clone(); } catch (err) { return t; }
        }));
      } catch (e2) {
        return null;
      }
    }
  }

  function inSettingsDialog(el) {
    if (!el || !el.closest) return false;
    return !!(el.closest('.settings-dialog') ||
      el.closest('.settings-pane') ||
      el.closest('[class*="settings-dialog"]') ||
      el.closest('[class*="SettingsDialog"]') ||
      el.closest('[class*="video-preview"]') ||
      el.closest('[class*="VideoPreview"]') ||
      el.closest('[aria-label*="Settings"]') ||
      el.closest('[role="dialog"]'));
  }

  function looksLikePreviewVideo(el) {
    if (!el || el.tagName !== 'VIDEO') return false;
    if (!inSettingsDialog(el)) return false;
    var rect = null;
    try { rect = el.getBoundingClientRect(); } catch (e) {}
    // Ignore tiny sink / hidden elements.
    if (rect && rect.width > 0 && rect.width < 40) return false;
    return true;
  }

  function bindPreview(el, stream) {
    if (!el || !stream) return;
    try {
      el.setAttribute('playsinline', 'true');
      el.setAttribute('webkit-playsinline', 'true');
      el.muted = true;
      el.autoplay = true;
      if (el.srcObject !== stream) el.srcObject = stream;
      var play = el.play();
      if (play && typeof play.catch === 'function') play.catch(function () {});
    } catch (e) {}
  }

  function patchGetUserMedia() {
    if (!navigator.mediaDevices || typeof navigator.mediaDevices.getUserMedia !== 'function') return;
    if (navigator.mediaDevices.__hrmsGumPreviewPatched) return;
    navigator.mediaDevices.__hrmsGumPreviewPatched = true;
    var orig = navigator.mediaDevices.getUserMedia.bind(navigator.mediaDevices);
    navigator.mediaDevices.getUserMedia = function (constraints) {
      // Try a real open first so camera switching still works. If Android
      // rejects a second camera client, reuse the live meeting track.
      return orig(constraints).catch(function (err) {
        var wantsVideo = !!(constraints && constraints.video);
        if (!wantsVideo) return Promise.reject(err);
        var fallback = getLocalCameraStream();
        if (!fallback) return Promise.reject(err);
        var cloned = cloneVideoOnly(fallback);
        if (!cloned) return Promise.reject(err);
        return cloned;
      });
    };
  }

  window.__hrmsFixVideoPreviews = function () {
    patchGetUserMedia();
    var local = getLocalCameraStream();
    if (!local) return;
    var nodes = document.querySelectorAll('video');
    for (var i = 0; i < nodes.length; i++) {
      var el = nodes[i];
      if (!looksLikePreviewVideo(el)) continue;
      var hasLive = false;
      try {
        hasLive = !!(el.srcObject && el.srcObject.getVideoTracks().some(function (t) {
          return t.readyState === 'live' && !isScreenTrack(t);
        })) && el.videoWidth > 0;
      } catch (e) {}
      if (hasLive) continue;
      bindPreview(el, cloneVideoOnly(local) || local);
    }
  };

  patchGetUserMedia();
  window.__hrmsFixVideoPreviews();
  if (!window.__hrmsVideoPreviewObserver && document.documentElement) {
    window.__hrmsVideoPreviewObserver = new MutationObserver(function () {
      if (window.__hrmsVideoPreviewScanTimer) return;
      window.__hrmsVideoPreviewScanTimer = setTimeout(function () {
        window.__hrmsVideoPreviewScanTimer = null;
        window.__hrmsFixVideoPreviews();
      }, 200);
    });
    window.__hrmsVideoPreviewObserver.observe(document.documentElement, {
      childList: true,
      subtree: true
    });
  }
  if (!window.__hrmsVideoPreviewTimer) {
    window.__hrmsVideoPreviewTimer = setInterval(function () {
      window.__hrmsFixVideoPreviews();
    }, 1000);
  }
})();
''';

  static const _jitsiKeepAliveJs = r'''
(function () {
  if (window.__hrmsKeepMeeting) return;
  window.__hrmsKeepMeeting = true;
  var block = function (e) {
    try { e.stopImmediatePropagation(); } catch (err) {}
    try { e.preventDefault(); } catch (err) {}
  };
  document.addEventListener('visibilitychange', block, true);
  window.addEventListener('pagehide', block, true);
  window.addEventListener('freeze', block, true);
  window.addEventListener('blur', block, true);
  document.addEventListener('pause', block, true);
  try {
    Object.defineProperty(document, 'hidden', { configurable: true, get: function () { return false; } });
    Object.defineProperty(document, 'visibilityState', { configurable: true, get: function () { return 'visible'; } });
    Object.defineProperty(document, 'webkitHidden', { configurable: true, get: function () { return false; } });
  } catch (err) {}
  // Keep active media playing — never force-play camera-off tiles (that
  // leaves the WebView's big play icon over the avatar).
  try {
    if (!window.__hrmsMediaKeepTimer) {
      window.__hrmsMediaKeepTimer = setInterval(function () {
        try {
          document.querySelectorAll('audio,video').forEach(function (el) {
            try {
              if (el.tagName === 'VIDEO') {
                var stream = el.srcObject;
                var live = false;
                if (stream && stream.getVideoTracks) {
                  live = stream.getVideoTracks().some(function (t) {
                    return t && t.readyState === 'live' && t.enabled !== false;
                  });
                }
                if (!live || el.videoWidth === 0) return;
              }
              if (el.paused) el.play();
            } catch (e) {}
          });
        } catch (e) {}
      }, 2000);
    }
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
          _leaving = false;
          _seenInCall = false;
          _joinedAt = null;
          _exitReloads = 0;
          _joinRefreshes = 0;
          _refreshingJoin = false;
          _cookiesReady = false;
          _appBackgrounded = false;
          _pendingBackgroundLeave = false;
          _pipMode = false;
          _pipRestoreGraceUntil = null;
        });
      });
    }

    // Show the call full-bleed in PiP or when expanded in-app.
    final showMeeting = session.isActive && (expanded || _pipMode);

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        // Keep the WebView laid out on-screen (even when "minimized") so
        // Android Picture-in-Picture can show the call instead of a blank tile.
        if (session.isActive)
          Positioned(
            left: 0,
            top: 0,
            width: stage.width,
            height: stage.height,
            child: IgnorePointer(
              ignoring: !showMeeting,
              child: Opacity(
                opacity: showMeeting ? 1 : 0.01,
                child: Material(
                  color: Colors.black,
                  // Keep Jitsi subject/timer below the system status bar in
                  // fullscreen (otherwise "HRMS Meet" overlaps the clock).
                  child: SafeArea(
                    bottom: false,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Column(
                          children: [
                            if (!_pipMode)
                              _MeetingChrome(
                                title: session.title ?? 'Meeting',
                                onBack: () => ref
                                    .read(meetingSessionProvider.notifier)
                                    .minimize(),
                              ),
                            Expanded(child: _buildWebView()),
                          ],
                        ),
                        if (_customView != null && !_pipMode)
                          Positioned.fill(
                            child: ColoredBox(
                              color: Colors.black,
                              child: _customView!,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (!_pipMode)
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
            child: Visibility(
              visible: !showMeeting,
              maintainState: true,
              maintainAnimation: true,
              maintainSize: true,
              child: widget.child,
            ),
          ),
        if (session.isActive && !expanded && !_pipMode)
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

    // Parent meeting shell already applies SafeArea for the status bar.
    return Material(
      color: scheme.surface,
      elevation: 1,
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
