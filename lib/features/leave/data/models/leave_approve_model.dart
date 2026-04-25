class ManagerLeaveRequest {
  final String id;
  final String status;
  final String startDate;
  final String endDate;
  final double days;
  final bool isHalfDay;
  final String? halfDayPart;
  final String reason;

  final String leaveType;

  final String employeeName;
  final String employeeCode;
  final String designation;
  final String department;
  final String profilePicture;

  /// ✅ FIXED TYPE
  final List<Map<String, dynamic>> requestedDates;

  final List<String> revocationRequestedDates;

  /// ✅ NEW FIELD (for revoke reason)
  final String? revocationReason;

  ManagerLeaveRequest({
    required this.id,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.isHalfDay,
    this.halfDayPart,
    required this.reason,
    required this.leaveType,
    required this.employeeName,
    required this.employeeCode,
    required this.designation,
    required this.department,
    required this.profilePicture,
    required this.requestedDates,
    required this.revocationRequestedDates,

    /// ✅ NEW
    this.revocationReason,
  });

  factory ManagerLeaveRequest.fromJson(Map<String, dynamic> json) {
    final start = json['startDate'];
    final end = json['endDate'];

    /// ✅ PARSE REQUESTED DATES CORRECTLY
    final requestedDatesJson = json['requestedDates'] as List? ?? [];

    final requestedDates = requestedDatesJson.map<Map<String, dynamic>>((e) {
      if (e is Map) {
        return {"date": e['date'], "halfDayPart": e['halfDayPart']};
      }

      return {"date": e.toString(), "halfDayPart": null};
    }).toList();

    /// calculate days
    double calculatedDays = 1;

    if (requestedDates.isNotEmpty) {
      calculatedDays = requestedDates.length.toDouble();
    } else if (json['isHalfDay'] == true) {
      calculatedDays = 0.5;
    } else if (start != null && end != null) {
      final startDate = DateTime.parse(start);
      final endDate = DateTime.parse(end);
      calculatedDays = endDate.difference(startDate).inDays + 1;
    }

    return ManagerLeaveRequest(
      id: json['id'] ?? '',
      status: json['status'] ?? '',
      startDate: start ?? '',
      endDate: end ?? '',
      days: calculatedDays,
      isHalfDay: json['isHalfDay'] ?? false,
      halfDayPart: json['halfDayPart'],
      reason: json['reason'] ?? '',
      leaveType: json['leave_type']?['name'] ?? '',
      employeeName: json['user']?['name'] ?? '',
      employeeCode: json['user']?['employee_detail']?['payroll_code'] ?? '',
      designation: json['user']?['employee_detail']?['designation'] ?? '',
      department: json['user']?['employee_detail']?['department_name'] ?? '',
      profilePicture:
          json['user']?['employee_detail']?['profile_picture'] ?? '',

      /// ✅ FIXED TYPE
      requestedDates: requestedDates,

      revocationRequestedDates:
          (json['revocationRequestedDates'] as List?)
              ?.map<String>((e) => e.toString())
              .toList() ??
          [],

      /// ✅ NEW (safe parsing)
      revocationReason: json['revocationReason']?.toString(),
    );
  }
}
