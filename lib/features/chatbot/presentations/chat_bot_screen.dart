import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:lms/features/auth/presentation/providers/auth_provider.dart';
import 'package:lms/features/chatbot/data/chatbot_api_service.dart';
import 'package:lms/features/chatbot/presentation/providers/chatbot_provider.dart';

class ChatBotScreen extends ConsumerStatefulWidget {
  const ChatBotScreen({super.key});

  @override
  ConsumerState<ChatBotScreen> createState() => _ChatBotScreenState();
}

class _ChatBotScreenState extends ConsumerState<ChatBotScreen> {
  final _inputController = TextEditingController();
  final _inputFocusNode = FocusNode();
  final _scrollController = ScrollController();

  static const _linkRoutes = <String, String>{
    '/leaves': '/leave-status',
    '/attendance': '/view-attendance',
    '/corrections': '/view-corrections',
    '/my-payslips': '/payslip',
    '/policies': '/policies',
    '/org-chart': '/profile',
  };

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
        _scrollToLatest();
      }
    });

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'HR Assistant',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text(
              'Answers about your own HR data',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Chat history',
            onPressed: state.isSending || state.isLoadingHistory
                ? null
                : _showConversationHistory,
            icon: const Icon(Icons.history_rounded),
          ),
          TextButton.icon(
            onPressed: state.isSending || state.isLoadingHistory
                ? null
                : () {
                    ref.read(chatbotProvider.notifier).startNewChat();
                    _scrollToLatest();
                  },
            icon: const Icon(Icons.add_comment_outlined, size: 18),
            label: const Text('New chat'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: state.messages.isEmpty
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
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          focusNode: _inputFocusNode,
                          enabled:
                              !state.isSending &&
                              !state.isLoadingHistory &&
                              !state.isForbidden,
                          minLines: 1,
                          maxLines: 5,
                          maxLength: 1000,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: 'Ask about your HR information...',
                            counterText: '',
                            filled: true,
                            fillColor: scheme.surfaceContainerLow,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: 'Send',
                        onPressed:
                            state.isSending ||
                                state.isLoadingHistory ||
                                state.isForbidden ||
                                _inputController.text.trim().isEmpty
                            ? null
                            : _send,
                        icon: const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'AI answers can be wrong. Please verify important details.',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(
    BuildContext context, {
    required String firstName,
    required List<String> permissions,
    required Map<String, dynamic> features,
    required bool isLoadingHistory,
    required String? historyError,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final suggestions = <String>[
      if (permissions.contains('leave.request.read') &&
          features['leaves'] == true)
        'How many leaves do I have left?',
      if (permissions.contains('attendance.read') &&
          features['attendance'] == true)
        'Show my attendance this month',
      if (permissions.contains('payroll.view') && features['payroll'] == true)
        'Show my latest payslip',
      if (permissions.contains('payroll.view') && features['payroll'] == true)
        'How much overtime do I have this month?',
      'When is the next holiday?',
      'Who is my reporting manager?',
      'Any new announcements?',
    ];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.support_agent_rounded,
                size: 34,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Hi $firstName!',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'I can answer questions about your own leave, attendance, '
              'payslips, overtime, holidays and company updates.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.45),
            ),
            if (isLoadingHistory) ...[
              const SizedBox(height: 18),
              const CircularProgressIndicator(),
            ],
            if (historyError != null) ...[
              const SizedBox(height: 12),
              Text(
                historyError,
                style: TextStyle(color: scheme.error, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 22),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: suggestions
                  .map(
                    (suggestion) => ActionChip(
                      label: Text(suggestion),
                      onPressed: () => _send(suggestion),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageList(BuildContext context, ChatbotState state) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
      itemCount: state.messages.length,
      itemBuilder: (context, index) {
        final message = state.messages[index];
        if (message.isError) return _errorBubble(context, message);
        if (message.role == 'user') return _userBubble(context, message);
        return _assistantBubble(context, message);
      },
    );
  }

  Widget _userBubble(BuildContext context, ChatbotMessage message) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Text(
          message.content,
          style: TextStyle(color: scheme.onPrimary, height: 1.4),
        ),
      ),
    );
  }

  Widget _assistantBubble(BuildContext context, ChatbotMessage message) {
    final scheme = Theme.of(context).colorScheme;
    final availableLinks = message.links
        .where((link) => _linkRoutes.containsKey(link.route))
        .toList();

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14, right: 18),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MarkdownBody(
              data: message.content,
              selectable: true,
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                  .copyWith(
                    p: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(height: 1.45),
                    tableBorder: TableBorder.all(color: scheme.outlineVariant),
                  ),
            ),
            if (availableLinks.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: availableLinks
                    .map(
                      (link) => OutlinedButton.icon(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          _linkRoutes[link.route]!,
                        ),
                        icon: const Icon(Icons.open_in_new_rounded, size: 15),
                        label: Text(link.label),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _errorBubble(BuildContext context, ChatbotMessage message) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.86,
        ),
        margin: const EdgeInsets.only(bottom: 14, right: 18),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: TextStyle(color: scheme.onErrorContainer, height: 1.4),
            ),
            if (message.retryText != null) ...[
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed:
                    ref.read(chatbotProvider).isSending ||
                        ref.read(chatbotProvider).isLoadingHistory ||
                        ref.read(chatbotProvider).isForbidden
                    ? null
                    : () => ref.read(chatbotProvider.notifier).retry(message),
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('Retry'),
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

  void _send([String? suggestion]) {
    final text = (suggestion ?? _inputController.text).trim();
    if (text.isEmpty || text.runes.length > 1000) return;
    _inputController.clear();
    _inputFocusNode.unfocus();
    ref.read(chatbotProvider.notifier).send(text);
  }

  Future<void> _showConversationHistory() async {
    final notifier = ref.read(chatbotProvider.notifier);
    await notifier.loadConversations();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.72,
          child: Consumer(
            builder: (context, ref, child) {
              final state = ref.watch(chatbotProvider);
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Chat history',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Refresh history',
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
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  Expanded(
                    child: state.isLoadingConversations
                        ? const Center(child: CircularProgressIndicator())
                        : state.conversations.isEmpty
                        ? const Center(child: Text('No previous chats'))
                        : ListView.separated(
                            itemCount: state.conversations.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final conversation = state.conversations[index];
                              return ListTile(
                                title: Text(
                                  conversation.title.isEmpty
                                      ? 'Untitled chat'
                                      : conversation.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: conversation.lastMessageAt == null
                                    ? null
                                    : Text(
                                        conversation.lastMessageAt!
                                            .toLocal()
                                            .toString()
                                            .split('.')
                                            .first,
                                      ),
                                onTap: () {
                                  Navigator.pop(sheetContext);
                                  ref
                                      .read(chatbotProvider.notifier)
                                      .openConversation(conversation.id);
                                },
                                trailing: IconButton(
                                  tooltip: 'Delete chat',
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
        title: const Text('Delete chat?'),
        content: const Text('This conversation will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
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

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 2, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          '•••',
          style: TextStyle(
            color: scheme.primary,
            fontSize: 18,
            letterSpacing: 3,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
