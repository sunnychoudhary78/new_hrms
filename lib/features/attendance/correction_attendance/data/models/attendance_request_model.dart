class AttendanceRequest {
  final String id;
  final String type; // CORRECTION | REMOTE
  final String status; // PENDING | APPROVED | REJECTED
  final String? reason;
  final String targetDate;

  final String userName;
  final String? userImage;

  // correction-only (proposed)
  final String? proposedCheckIn;
  final String? proposedCheckOut;

  // 🔥 NEW: original times
  final String? originalCheckIn;
  final String? originalCheckOut;

  final String? requestedAt;

  const AttendanceRequest({
    required this.id,
    required this.type,
    required this.status,
    required this.targetDate,
    required this.userName,
    this.reason,
    this.userImage,
    this.proposedCheckIn,
    this.proposedCheckOut,
    this.originalCheckIn,
    this.originalCheckOut,
    this.requestedAt,
  });

  factory AttendanceRequest.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    final profilePic = user?['profile_picture'];

    return AttendanceRequest(
      id: json['id'] as String,
      type: (json['type'] as String).toUpperCase(),
      status: (json['status'] as String).toUpperCase(),
      reason: json['reason'] as String?,
      targetDate: json['targetDate'] as String,

      // proposed
      proposedCheckIn: json['proposedCheckIn'] as String?,
      proposedCheckOut: json['proposedCheckOut'] as String?,

      // 🔥 original (NEW)
      originalCheckIn: json['originalCheckIn'] as String?,
      originalCheckOut: json['originalCheckOut'] as String?,

      requestedAt: json['createdAt'] as String?,

      userName: user?['name'] ?? '',

      userImage: profilePic != null && profilePic.toString().isNotEmpty
          ? "http://88.222.244.233/uatlms-admin/uploads/$profilePic"
          : null,
    );
  }

  bool get isCorrection => type == 'CORRECTION';
  bool get isRemote => type == 'REMOTE';
  bool get isPending => status == 'PENDING';
  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED';
}
