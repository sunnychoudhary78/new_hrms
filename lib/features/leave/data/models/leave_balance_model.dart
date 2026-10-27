class LeaveBalance {
  final String id;
  final String leaveTypeId;
  final double available;
  final double carried;
  final double pendingReserved;
  final String name;

  final bool allowHalfDay;
  final bool allowNegativeBalance;
  final bool documentRequired;

  LeaveBalance({
    required this.id,
    required this.leaveTypeId,
    required this.available,
    required this.carried,
    required this.pendingReserved,
    required this.name,
    required this.allowHalfDay,
    required this.allowNegativeBalance,
    required this.documentRequired,
  });

  bool get canApply => allowNegativeBalance || available > 0;

  factory LeaveBalance.fromJson(
    Map<String, dynamic> json,
    Map<String, dynamic>? leaveType,
  ) {
    final leaveTypeBalance = json['leave_type'];

    return LeaveBalance(
      id: json['id']?.toString() ?? '',
      leaveTypeId:
          (json['leave_type_id'] ?? leaveTypeBalance?['id'])?.toString() ?? '',
      available: (json['available'] as num?)?.toDouble() ?? 0,
      carried: (json['carried'] as num?)?.toDouble() ?? 0,
      pendingReserved: (json['pending_reserved'] as num?)?.toDouble() ?? 0,

      // Prefer leave type API values if available
      name: leaveType?['name'] ?? leaveTypeBalance?['name'] ?? '',

      allowHalfDay:
          leaveType?['allowHalfDay'] ??
          leaveTypeBalance?['allowHalfDay'] ??
          false,

      allowNegativeBalance:
          leaveType?['allowNegativeBalance'] ??
          leaveTypeBalance?['allowNegativeBalance'] ??
          false,

      documentRequired:
          leaveType?['documentRequired'] ??
          leaveTypeBalance?['documentRequired'] ??
          false,
    );
  }
}
