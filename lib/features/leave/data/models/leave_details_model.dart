class LeaveDetails {
  final String id;
  final String reference;
  final String status;

  final String startDate;
  final String endDate;

  final double days;

  final String? leaveType;
  final String? reason;

  final String? managerName;
  final String? managerEmail;

  final DateTime? appliedAt;

  final List<LeaveHistory> histories;

  const LeaveDetails({
    required this.id,
    required this.reference,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.days,
    this.leaveType,
    this.reason,
    this.managerName,
    this.managerEmail,
    this.appliedAt,
    required this.histories,
  });

  factory LeaveDetails.fromJson(Map<String, dynamic> json) {
    return LeaveDetails(
      id: json['id']?.toString() ?? '',

      reference: json['refId']?.toString() ?? '-',

      status: json['status']?.toString() ?? '',

      startDate: json['startDate']?.toString() ?? '',
      endDate: json['endDate']?.toString() ?? '',

      days: (json['days'] is num) ? (json['days'] as num).toDouble() : 0,

      leaveType: json['leaveType']?['name']?.toString(),

      reason: json['reason']?.toString(),

      managerName: json['manager']?['name']?.toString(),

      managerEmail: json['manager']?['email']?.toString(),

      appliedAt: json['appliedAt'] != null
          ? DateTime.tryParse(json['appliedAt'].toString())
          : null,

      histories:
          (json['histories'] as List?)
              ?.map((e) => LeaveHistory.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class LeaveHistory {
  final String action;
  final String? comment;
  final DateTime? at;
  final String? actorName;

  LeaveHistory({required this.action, this.comment, this.at, this.actorName});

  factory LeaveHistory.fromJson(Map<String, dynamic> json) {
    return LeaveHistory(
      action: json['action']?.toString() ?? '',

      comment: json['comment']?.toString(),

      at: json['at'] != null ? DateTime.tryParse(json['at'].toString()) : null,

      actorName: json['actor']?['name']?.toString(),
    );
  }
}
