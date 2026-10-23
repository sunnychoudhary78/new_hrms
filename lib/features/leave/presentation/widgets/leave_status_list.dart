import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lms/core/theme/app_design.dart';
import 'package:lms/features/leave/data/models/leave_status_model.dart';
import 'package:lms/shared/widgets/app_form_widgets.dart';
import 'leave_status_card.dart';

class LeaveStatusList extends StatefulWidget {
  final List<LeaveStatus> leaves;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String, List<String>) onRevoke;
  final String? expandLeaveId;

  const LeaveStatusList({
    super.key,
    required this.leaves,
    required this.onRefresh,
    required this.onRevoke,
    this.expandLeaveId,
  });

  @override
  State<LeaveStatusList> createState() => _LeaveStatusListState();
}

class _LeaveStatusListState extends State<LeaveStatusList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant LeaveStatusList oldWidget) {
    super.didUpdateWidget(oldWidget);

    _scrollToExpanded();
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToExpanded();
    });
  }

  void _scrollToExpanded() {
    if (widget.expandLeaveId == null) return;

    final index = widget.leaves.indexWhere((e) => e.id == widget.expandLeaveId);

    if (index == -1) return;

    final offset = index * 140.0;

    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scrollPhysics = defaultTargetPlatform == TargetPlatform.iOS
        ? const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          )
        : const AlwaysScrollableScrollPhysics();

    if (widget.leaves.isEmpty) {
      return RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: ListView(
          physics: scrollPhysics,
          padding: appScreenPadding,
          children: [
            SizedBox(height: 80),
            Center(
              child: Text(
                "No leave requests found",
                style: TextStyle(color: AppColors.muted),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.builder(
        controller: _scrollController,
        physics: scrollPhysics,
        padding: appScreenPadding,
        itemCount: widget.leaves.length,
        itemBuilder: (context, index) {
          final leave = widget.leaves[index];

          final canRevoke =
              leave.status == "Pending" ||
              leave.status == "Approved" ||
              leave.status == "PartiallyApproved";

          final shouldExpand = leave.id == widget.expandLeaveId;

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: LeaveStatusCard(
              leave: leave,
              isInitiallyExpanded: shouldExpand,
              onRevoke: canRevoke
                  ? () => widget.onRevoke(leave.id, [])
                  : null,
            ),
          );
        },
      ),
    );
  }
}
