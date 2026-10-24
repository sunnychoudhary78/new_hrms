import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:lms/features/auth/presentation/providers/auth_provider.dart';
import 'package:lms/features/chatbot/data/chatbot_api_service.dart';
import 'package:lms/features/chatbot/presentation/providers/chatbot_provider.dart';

/// Suggestion chip data (icon + pastel tint, same style as Home quick actions)
class _Suggestion {
  final String text;
  final String textHi;
  final IconData icon;
  final Color tint;
  const _Suggestion(this.text, this.textHi, this.icon, this.tint);
}

class ChatBotScreen extends ConsumerStatefulWidget {
  const ChatBotScreen({super.key});

  @override
  ConsumerState<ChatBotScreen> createState() => _ChatBotScreenState();
}

class _ChatBotScreenState extends ConsumerState<ChatBotScreen> {
  final _inputController = TextEditingController();
  final _inputFocusNode = FocusNode();
  final _scrollController = ScrollController();

  /// 'en' or 'hi'
  String _lang = 'en';
  bool get _hi => _lang == 'hi';

  /// Once Hindi has been used in this session we also tag English messages,
  /// so switching back to English makes the bot answer in English again.
  bool _hindiUsed = false;

  /// When true, the initial screen (hero + suggested questions) is shown even
  /// though the conversation has messages.
  bool _showMenu = false;

  static const _hiPrefix = 'Please reply in Hindi: ';
  static const _enPrefix = 'Please reply in English: ';

  String _t(String en, String hi) => _hi ? hi : en;

  static const _linkRoutes = <String, String>{
    '/leaves': '/leave-balance',
    '/attendance': '/view-attendance',
    '/corrections': '/view-corrections',
    '/my-payslips': '/payslip',
    '/policies': '/policies',
    '/org-chart': '/profile',
  };

  // ---- Theme helpers (match Home screen look) ----
  static const _lightBg = Color(0xFFF6F7FC);

  bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

  Color _bg(BuildContext c) =>
      _isDark(c) ? Theme.of(c).colorScheme.surface : _lightBg;

  Color _card(BuildContext c) => _isDark(c)
      ? Theme.of(c).colorScheme.surfaceContainerHigh
      : Colors.white;

  List<BoxShadow> _softShadow(BuildContext c) => _isDark(c)
      ? const []
      : [
          BoxShadow(
            color: const Color(0xFF5B5BE6).withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ];

  LinearGradient _brandGradient(ColorScheme scheme) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      scheme.primary,
      Color.lerp(scheme.primary, const Color(0xFF7C6CF2), 0.55)!,
    ],
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(chatbotProvider.notifier).loadConversation();
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatbotProvider);
    final auth = ref.watch(authProvider);
    final scheme = Theme.of(context).colorScheme;
    final name = auth.profile?.associatesName ?? auth.authUser?.name ?? 'there';
    final trimmedName = name.trim();
    final firstName = trimmedName.isEmpty
        ? 'there'
        : trimmedName.split(RegExp(r'\s+')).first;

    ref.listen<ChatbotState>(chatbotProvider, (previous, next) {
      if (previous?.messages.length != next.messages.length) {
        // Any new message / opened conversation leaves the menu view.
        if (_showMenu && next.messages.isNotEmpty) {
          setState(() => _showMenu = false);
        }
        _scrollToLatest();
      }
    });

    final busy = state.isSending || state.isLoadingHistory;
    final showMenu = state.messages.isEmpty || _showMenu;

    return Scaffold(
      backgroundColor: _bg(context),
      appBar: AppBar(
        backgroundColor: _bg(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t('Your Assistant', 'आपका असिस्टेंट'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
            ),
            Text(
              _t('Answers about your own HR data',
                  'आपके HR डेटा से जुड़े जवाब'),
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          _AppBarCircleButton(
            tooltip: _t('Chat history', 'चैट हिस्ट्री'),
            icon: Icons.history_rounded,
            color: _card(context),
            shadow: _softShadow(context),
            onPressed: busy ? null : _showConversationHistory,
          ),
          const SizedBox(width: 8),
          _NewChatPill(
            label: _t('New chat', 'नई चैट'),
            enabled: !busy,
            gradient: _brandGradient(scheme),
            onTap: () {
              ref.read(chatbotProvider.notifier).startNewChat();
              setState(() => _showMenu = false);
              _scrollToLatest();
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: showMenu
                  ? _emptyState(
                      context,
                      firstName: firstName,
                      permissions: auth.permissions,
                      features: auth.features,
                      isLoadingHistory: state.isLoadingHistory,
                      historyError: state.historyError,
                    )
                  : _messageList(context, state),
            ),
            if (state.isSending) const _TypingIndicator(),
            if (!showMenu) _backToMenuChip(context, busy),
            _inputBar(context, state),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Back to main menu
  // ---------------------------------------------------------------------------
  Widget _backToMenuChip(BuildContext context, bool busy) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
        child: ActionChip(
          onPressed: busy
              ? null
              : () {
                  _inputFocusNode.unfocus();
                  setState(() => _showMenu = true);
                },
          avatar: Icon(Icons.apps_rounded, size: 16, color: scheme.primary),
          label: Text(_t('Back to Main Menu', 'मुख्य मेनू पर वापस')),
          labelStyle: TextStyle(
            color: scheme.primary,
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
          ),
          backgroundColor: scheme.primary.withValues(alpha: 0.08),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Input bar
  // ---------------------------------------------------------------------------
  Widget _inputBar(BuildContext context, ChatbotState state) {
    final scheme = Theme.of(context).colorScheme;
    final inputEnabled =
        !state.isSending && !state.isLoadingHistory && !state.isForbidden;
    final canSend = inputEnabled && _inputController.text.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
            decoration: BoxDecoration(
              color: _card(context),
              borderRadius: BorderRadius.circular(28),
              boxShadow: _softShadow(context),
              border: _isDark(context)
                  ? Border.all(color: scheme.outlineVariant)
                  : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    focusNode: _inputFocusNode,
                    enabled: inputEnabled,
                    minLines: 1,
                    maxLines: 5,
                    maxLength: 1000,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: _t('Ask about your HR information...',
                          'अपनी HR जानकारी पूछें...'),
                      hintStyle: TextStyle(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                        fontSize: 14.5,
                      ),
                      counterText: '',
                      filled: false,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: _LanguageToggle(
                    isHindi: _hi,
                    onChanged: (hindi) => setState(() {
                      _lang = hindi ? 'hi' : 'en';
                      if (hindi) _hindiUsed = true;
                    }),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: canSend ? _send : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: canSend ? _brandGradient(scheme) : null,
                      color: canSend ? null : scheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_upward_rounded,
                      color: canSend
                          ? scheme.onPrimary
                          : scheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _t('AI answers can be wrong. Please verify important details.',
                'AI के जवाब गलत हो सकते हैं। कृपया ज़रूरी जानकारी जाँच लें।'),
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Empty state / main menu
  // ---------------------------------------------------------------------------
  Widget _emptyState(
    BuildContext context, {
    required String firstName,
    required List<String> permissions,
    required Map<String, dynamic> features,
    required bool isLoadingHistory,
    required String? historyError,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final dark = _isDark(context);

    Color tint(Color c) => dark ? c.withValues(alpha: 0.22) : c;

    final suggestions = <_Suggestion>[
      if (permissions.contains('leave.request.read') &&
          features['leaves'] == true)
        _Suggestion(
          'How many leaves do I have left?',
          'मेरी कितनी छुट्टियाँ बची हैं?',
          Icons.eco_rounded,
          tint(const Color(0xFFDDF7E6)),
        ),
      if (permissions.contains('attendance.read') &&
          features['attendance'] == true)
        _Suggestion(
          'Show my attendance this month',
          'इस महीने की मेरी अटेंडेंस दिखाओ',
          Icons.event_available_rounded,
          tint(const Color(0xFFDCE6FF)),
        ),
      if (permissions.contains('payroll.view') && features['payroll'] == true)
        _Suggestion(
          'Show my latest payslip',
          'मेरी latest पेस्लिप दिखाओ',
          Icons.receipt_long_rounded,
          tint(const Color(0xFFFFF0C9)),
        ),
      if (permissions.contains('payroll.view') && features['payroll'] == true)
        _Suggestion(
          'How much overtime do I have this month?',
          'इस महीने मेरा कितना ओवरटाइम है?',
          Icons.schedule_rounded,
          tint(const Color(0xFFE9E1FF)),
        ),
      _Suggestion(
        'When is the next holiday?',
        'अगली छुट्टी कब है?',
        Icons.celebration_rounded,
        tint(const Color(0xFFFFE1EC)),
      ),
      _Suggestion(
        'Who is my reporting manager?',
        'मेरे रिपोर्टिंग मैनेजर कौन हैं?',
        Icons.account_tree_rounded,
        tint(const Color(0xFFD9F3F7)),
      ),
      _Suggestion(
        'Any new announcements?',
        'कोई नई घोषणा?',
        Icons.campaign_rounded,
        tint(const Color(0xFFFFE6D5)),
      ),
    ];

    final cardWidth = (MediaQuery.sizeOf(context).width - 40 - 12) / 2;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero card (same style as Home greeting card)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: _brandGradient(scheme),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.support_agent_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _hi ? 'नमस्ते $firstName 👋' : 'Hi $firstName 👋',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _t(
                          'I can answer questions about your leave, attendance, '
                              'payslips, overtime, holidays and company updates.',
                          'मैं आपकी छुट्टी, अटेंडेंस, पेस्लिप, ओवरटाइम, '
                              'हॉलिडे और कंपनी अपडेट्स के बारे में जवाब दे सकता हूँ।',
                        ),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isLoadingHistory) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator()),
          ],
          if (historyError != null) ...[
            const SizedBox(height: 12),
            Center(
              child: Text(
                historyError,
                style: TextStyle(color: scheme.error, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            _t('Suggested Questions', 'सुझाए गए सवाल'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: suggestions
                .map(
                  (s) => _suggestionCard(
                    context,
                    s,
                    cardWidth,
                    dark,
                    scheme,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _suggestionCard(
    BuildContext context,
    _Suggestion s,
    double width,
    bool dark,
    ColorScheme scheme,
  ) {
    final label = _hi ? s.textHi : s.text;
    return SizedBox(
      width: width,
      child: Material(
        color: _card(context),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _send(label),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: dark ? Border.all(color: scheme.outlineVariant) : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: s.tint,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    s.icon,
                    size: 21,
                    color: dark ? scheme.onSurface : scheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  label,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Messages
  // ---------------------------------------------------------------------------
  Widget _messageList(BuildContext context, ChatbotState state) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      itemCount: state.messages.length,
      itemBuilder: (context, index) {
        final message = state.messages[index];
        if (message.isError) return _errorBubble(context, message);
        if (message.role == 'user') return _userBubble(context, message);
        return _assistantBubble(context, message);
      },
    );
  }

  /// Removes the hidden language instruction before showing a user message.
  String _displayText(String content) {
    if (content.startsWith(_hiPrefix)) {
      return content.substring(_hiPrefix.length);
    }
    if (content.startsWith(_enPrefix)) {
      return content.substring(_enPrefix.length);
    }
    return content;
  }

  Widget _userBubble(BuildContext context, ChatbotMessage message) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.8,
        ),
        margin: const EdgeInsets.only(bottom: 14, left: 40),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: _brandGradient(scheme),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(22),
            topRight: Radius.circular(22),
            bottomLeft: Radius.circular(22),
            bottomRight: Radius.circular(6),
          ),
        ),
        child: Text(
          _displayText(message.content),
          style: TextStyle(
            color: scheme.onPrimary,
            height: 1.4,
            fontSize: 14.5,
          ),
        ),
      ),
    );
  }

  Widget _botAvatar(ColorScheme scheme) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        gradient: _brandGradient(scheme),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.support_agent_rounded,
        size: 18,
        color: Colors.white,
      ),
    );
  }

  Widget _assistantBubble(BuildContext context, ChatbotMessage message) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final availableLinks = message.links
        .where((link) => _linkRoutes.containsKey(link.route))
        .toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _botAvatar(scheme),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: _card(context),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(22),
                  bottomLeft: Radius.circular(22),
                  bottomRight: Radius.circular(22),
                ),
                boxShadow: _softShadow(context),
                border: _isDark(context)
                    ? Border.all(color: scheme.outlineVariant)
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarkdownBody(
                    data: message.content,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                      p: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                        fontSize: 14.5,
                      ),
                      // Every column takes the width its content needs.
                      // flutter_markdown wraps tables in a horizontal
                      // SingleChildScrollView, so wide tables (attendance)
                      // can be swiped sideways and no column gets cropped.
                      tableColumnWidth: const IntrinsicColumnWidth(),
                      tablePadding: const EdgeInsets.only(bottom: 4),
                      tableBorder: TableBorder.all(
                        color: scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      tableCellsPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      tableHead: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                      tableBody: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                        height: 1.3,
                      ),
                      tableHeadAlign: TextAlign.center,
                    ),
                  ),
                  if (availableLinks.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availableLinks
                          .map(
                            (link) => ActionChip(
                              onPressed: () => Navigator.pushNamed(
                                context,
                                _linkRoutes[link.route]!,
                              ),
                              avatar: Icon(
                                Icons.open_in_new_rounded,
                                size: 15,
                                color: scheme.primary,
                              ),
                              label: Text(link.label),
                              labelStyle: TextStyle(
                                color: scheme.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                              backgroundColor: scheme.primary.withValues(
                                alpha: 0.08,
                              ),
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBubble(BuildContext context, ChatbotMessage message) {
    final scheme = Theme.of(context).colorScheme;
    final chat = ref.read(chatbotProvider);
    final retryDisabled =
        chat.isSending || chat.isLoadingHistory || chat.isForbidden;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.86,
        ),
        margin: const EdgeInsets.only(bottom: 14, right: 18),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 18,
                  color: scheme.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message.content,
                    style: TextStyle(
                      color: scheme.onErrorContainer,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            if (message.retryText != null) ...[
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: retryDisabled
                    ? null
                    : () => ref.read(chatbotProvider.notifier).retry(message),
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: Text(_t('Retry', 'दोबारा कोशिश करें')),
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onErrorContainer,
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------
  void _send([String? suggestion]) {
    final text = (suggestion ?? _inputController.text).trim();
    if (text.isEmpty || text.runes.length > 1000) return;

    // Hidden language instruction (stripped again in the user bubble).
    final String payload;
    if (_hi) {
      payload = '$_hiPrefix$text';
    } else if (_hindiUsed) {
      payload = '$_enPrefix$text';
    } else {
      payload = text;
    }

    _inputController.clear();
    _inputFocusNode.unfocus();
    setState(() => _showMenu = false);
    ref.read(chatbotProvider.notifier).send(payload);
    _scrollToLatest();
  }

  Future<void> _showConversationHistory() async {
    final notifier = ref.read(chatbotProvider.notifier);
    await notifier.loadConversations();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _bg(context),
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.72,
          child: Consumer(
            builder: (context, ref, child) {
              final state = ref.watch(chatbotProvider);
              final scheme = Theme.of(context).colorScheme;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _t('Chat history', 'चैट हिस्ट्री'),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: _t('Refresh history', 'हिस्ट्री रिफ्रेश करें'),
                          onPressed: state.isLoadingConversations
                              ? null
                              : () => ref
                                    .read(chatbotProvider.notifier)
                                    .loadConversations(),
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ],
                    ),
                  ),
                  if (state.historyError != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        state.historyError!,
                        style: TextStyle(color: scheme.error),
                      ),
                    ),
                  Expanded(
                    child: state.isLoadingConversations
                        ? const Center(child: CircularProgressIndicator())
                        : state.conversations.isEmpty
                        ? Center(
                            child: Text(
                              _t('No previous chats', 'कोई पुरानी चैट नहीं'),
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                            itemCount: state.conversations.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final conversation = state.conversations[index];
                              return Container(
                                decoration: BoxDecoration(
                                  color: _card(context),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: _softShadow(context),
                                ),
                                child: ListTile(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: scheme.primary.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                    child: Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      size: 20,
                                      color: scheme.primary,
                                    ),
                                  ),
                                  title: Text(
                                    conversation.title.isEmpty
                                        ? _t('Untitled chat', 'बिना नाम की चैट')
                                        : _displayText(conversation.title),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14.5,
                                    ),
                                  ),
                                  subtitle: conversation.lastMessageAt == null
                                      ? null
                                      : Text(
                                          conversation.lastMessageAt!
                                              .toLocal()
                                              .toString()
                                              .split('.')
                                              .first,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                  onTap: () {
                                    Navigator.pop(sheetContext);
                                    if (mounted) {
                                      setState(() => _showMenu = false);
                                    }
                                    ref
                                        .read(chatbotProvider.notifier)
                                        .openConversation(conversation.id);
                                  },
                                  trailing: IconButton(
                                    tooltip: _t('Delete chat', 'चैट हटाएँ'),
                                    onPressed:
                                        state.deletingConversationId != null
                                        ? null
                                        : () => _confirmDeleteConversation(
                                            sheetContext,
                                            conversation,
                                          ),
                                    icon:
                                        state.deletingConversationId ==
                                            conversation.id
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.delete_outline),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteConversation(
    BuildContext sheetContext,
    ChatbotConversation conversation,
  ) async {
    final confirmed = await showDialog<bool>(
      context: sheetContext,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(_t('Delete chat?', 'चैट हटाएँ?')),
        content: Text(_t('This conversation will be permanently deleted.',
            'यह बातचीत हमेशा के लिए हटा दी जाएगी।')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_t('Cancel', 'रद्द करें')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_t('Delete', 'हटाएँ')),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref
          .read(chatbotProvider.notifier)
          .deleteConversation(conversation.id);
    }
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }
}

// =============================================================================
// Small widgets
// =============================================================================

/// Compact "EN / हि" switch shown inside the input bar.
class _LanguageToggle extends StatelessWidget {
  final bool isHindi;
  final ValueChanged<bool> onChanged;

  const _LanguageToggle({required this.isHindi, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget segment(String label, bool selected, VoidCallback onTap) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? scheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          segment('EN', !isHindi, () => onChanged(false)),
          segment('हि', isHindi, () => onChanged(true)),
        ],
      ),
    );
  }
}

class _AppBarCircleButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color color;
  final List<BoxShadow> shadow;
  final VoidCallback? onPressed;

  const _AppBarCircleButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.shadow,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        child: Opacity(
          opacity: onPressed == null ? 0.4 : 1,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: shadow,
            ),
            child: Icon(icon, size: 21),
          ),
        ),
      ),
    );
  }
}

class _NewChatPill extends StatelessWidget {
  final String label;
  final bool enabled;
  final Gradient gradient;
  final VoidCallback onTap;

  const _NewChatPill({
    required this.label,
    required this.enabled,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded, size: 18, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatbotEntryButton extends ConsumerWidget {
  const ChatbotEntryButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final hiddenForSession = ref.watch(chatbotProvider).isForbidden;
    final isSuperAdmin = auth.roleName == 'SuperAdmin';
    final allowed =
        isSuperAdmin ||
        (auth.permissions.contains('chatbot.use') &&
            auth.featuresLoaded &&
            auth.features['chatbot'] == true);
    if (hiddenForSession || !allowed) return const SizedBox.shrink();

    return FloatingActionButton(
      heroTag: 'hr-assistant-fab',
      tooltip: 'HR Assistant',
      onPressed: () => Navigator.pushNamed(context, '/chatbot'),
      child: const Icon(Icons.chat_bubble_outline_rounded),
    );
  }
}

/// Animated three-dot typing indicator inside a white card + bot avatar.
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 2, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: dark ? scheme.surfaceContainerHigh : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: dark
              ? const []
              : [
                  BoxShadow(
                    color: const Color(0xFF5B5BE6).withValues(alpha: 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final t = (_controller.value - i * 0.18) % 1.0;
                final wave = t < 0.5 ? t * 2 : (1 - t) * 2; // 0..1..0
                return Container(
                  margin: EdgeInsets.only(right: i == 2 ? 0 : 5),
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(
                      alpha: 0.35 + 0.65 * wave,
                    ),
                    shape: BoxShape.circle,
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}