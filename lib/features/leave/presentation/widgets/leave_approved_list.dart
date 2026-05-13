import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:lms/features/leave/data/models/leave_approve_model.dart';

import 'leave_approve_card.dart';

class LeaveApprovedList extends StatelessWidget {
  final List<ManagerLeaveRequest> requests;

  final Future<void> Function() onRefresh;

  const LeaveApprovedList({
    super.key,
    required this.requests,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final scrollPhysics = defaultTargetPlatform == TargetPlatform.iOS
        ? const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          )
        : const AlwaysScrollableScrollPhysics();

    if (requests.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: scrollPhysics,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: const [
            SizedBox(height: 120),
            Center(child: Text("No processed leaves")),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,

      child: ListView.builder(
        physics: scrollPhysics,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),

        itemCount: requests.length,

        itemBuilder: (_, index) {
          final request = requests[index];

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),

            child: LeaveApproveCard(request: request, isPending: false),
          );
        },
      ),
    );
  }
}
