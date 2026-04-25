class KraPerson {
  final String id;
  final String name;
  final String? email;
  final String? designation;

  const KraPerson({
    required this.id,
    required this.name,
    this.email,
    this.designation,
  });

  factory KraPerson.fromJson(Map<String, dynamic> json) {
    return KraPerson(
      id: json['id']?.toString() ?? '',
      name: (json['name'] ?? json['associates_name'] ?? 'Employee').toString(),
      email: json['email']?.toString(),
      designation:
          json['designation']?.toString() ??
          json['employee_detail']?['designation']?.toString(),
    );
  }
}

class KraDepartment {
  final String id;
  final String name;

  const KraDepartment({required this.id, required this.name});

  factory KraDepartment.fromJson(Map<String, dynamic> json) {
    return KraDepartment(
      id: json['id']?.toString() ?? '',
      name: (json['name'] ?? 'Department').toString(),
    );
  }
}

class KpiModel {
  final String id;
  final String? kraId;
  final String name;
  final String description;
  final double weightage;

  const KpiModel({
    required this.id,
    this.kraId,
    required this.name,
    required this.description,
    required this.weightage,
  });

  factory KpiModel.fromJson(Map<String, dynamic> json) {
    return KpiModel(
      id: json['id']?.toString() ?? '',
      kraId: json['kra_id']?.toString() ?? json['kraId']?.toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      weightage: _toDouble(json['weightage']),
    );
  }

  Map<String, dynamic> toPayload() {
    return {
      'name': name.trim(),
      'description': description.trim(),
      'weightage': _jsonNumber(weightage),
    };
  }
}

class KraModel {
  final String id;
  final String name;
  final String description;
  final String? departmentId;
  final String? employeeId;
  final String? companyId;
  final String? createdBy;
  final KraPerson? employee;
  final KraDepartment? department;
  final List<KpiModel> kpis;

  const KraModel({
    required this.id,
    required this.name,
    required this.description,
    this.departmentId,
    this.employeeId,
    this.companyId,
    this.createdBy,
    this.employee,
    this.department,
    this.kpis = const [],
  });

  factory KraModel.fromJson(Map<String, dynamic> json) {
    return KraModel(
      id: json['id']?.toString() ?? '',
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      departmentId:
          json['department_id']?.toString() ?? json['departmentId']?.toString(),
      employeeId:
          json['employee_id']?.toString() ?? json['employeeId']?.toString(),
      companyId:
          json['company_id']?.toString() ?? json['companyId']?.toString(),
      createdBy:
          json['created_by']?.toString() ?? json['createdBy']?.toString(),
      employee: json['employee'] is Map
          ? KraPerson.fromJson(
              Map<String, dynamic>.from(json['employee'] as Map),
            )
          : null,
      department: json['department'] is Map
          ? KraDepartment.fromJson(
              Map<String, dynamic>.from(json['department'] as Map),
            )
          : null,
      kpis: (json['kpis'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => KpiModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class KraCycle {
  final String id;
  final int month;
  final int year;
  final String status;

  const KraCycle({
    required this.id,
    required this.month,
    required this.year,
    required this.status,
  });

  factory KraCycle.fromJson(Map<String, dynamic> json) {
    return KraCycle(
      id: json['id']?.toString() ?? '',
      month: _toInt(json['month']),
      year: _toInt(json['year']),
      status: (json['status'] ?? '').toString(),
    );
  }

  String get label => '${_monthName(month)} $year';
}

class KraRating {
  final String id;
  final String kpiId;
  final double? employeeRating;
  final String? employeeRemarks;
  final double? managerRating;
  final String? managerRemarks;
  final double? hodRating;
  final String? hodRemarks;
  final KpiModel? kpi;

  const KraRating({
    required this.id,
    required this.kpiId,
    this.employeeRating,
    this.employeeRemarks,
    this.managerRating,
    this.managerRemarks,
    this.hodRating,
    this.hodRemarks,
    this.kpi,
  });

  factory KraRating.fromJson(Map<String, dynamic> json) {
    return KraRating(
      id: json['id']?.toString() ?? '',
      kpiId: json['kpi_id']?.toString() ?? json['kpiId']?.toString() ?? '',
      employeeRating: _nullableDouble(json['employee_rating']),
      employeeRemarks: json['employee_remarks']?.toString(),
      managerRating: _nullableDouble(json['manager_rating']),
      managerRemarks: json['manager_remarks']?.toString(),
      hodRating: _nullableDouble(json['hod_rating']),
      hodRemarks: json['hod_remarks']?.toString(),
      kpi: json['kpi'] is Map
          ? KpiModel.fromJson(Map<String, dynamic>.from(json['kpi'] as Map))
          : null,
    );
  }
}

class KraEvaluation {
  final String id;
  final String cycleId;
  final String employeeId;
  final String status;
  final double finalScore;
  final KraCycle? cycle;
  final KraPerson? employee;
  final List<KraRating> ratings;

  const KraEvaluation({
    required this.id,
    required this.cycleId,
    required this.employeeId,
    required this.status,
    required this.finalScore,
    this.cycle,
    this.employee,
    this.ratings = const [],
  });

  factory KraEvaluation.fromJson(Map<String, dynamic> json) {
    return KraEvaluation(
      id: json['id']?.toString() ?? '',
      cycleId:
          json['cycle_id']?.toString() ?? json['cycleId']?.toString() ?? '',
      employeeId:
          json['employee_id']?.toString() ??
          json['employeeId']?.toString() ??
          '',
      status: (json['status'] ?? '').toString(),
      finalScore: _toDouble(json['final_score'] ?? json['finalScore']),
      cycle: json['cycle'] is Map
          ? KraCycle.fromJson(Map<String, dynamic>.from(json['cycle'] as Map))
          : null,
      employee: json['employee'] is Map
          ? KraPerson.fromJson(
              Map<String, dynamic>.from(json['employee'] as Map),
            )
          : null,
      ratings: (json['ratings'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => KraRating.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

double _toDouble(dynamic value) => _nullableDouble(value) ?? 0;

double? _nullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

Object _jsonNumber(double value) {
  if (value == value.roundToDouble()) return value.toInt();
  return value;
}

String _monthName(int month) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  if (month < 1 || month > 12) return 'Month $month';
  return months[month - 1];
}
