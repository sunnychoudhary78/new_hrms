class Payslip {
  final String id;
  final int month;
  final int year;
  final String status;

  final double payableDays;
  final int totalDays;

  final Map<String, dynamic> earnings;
  final Map<String, dynamic> deductions;
  final Map<String, dynamic> employerContributions;

  final double grossSalary;
  final double totalDeductions;
  final double netSalary;
  final double totalCtc;

  final Employee employee;
  final Company company;

  final DateTime createdAt;

  Payslip({
    required this.id,
    required this.month,
    required this.year,
    required this.status,
    required this.payableDays,
    required this.totalDays,
    required this.earnings,
    required this.deductions,
    required this.employerContributions,
    required this.grossSalary,
    required this.totalDeductions,
    required this.netSalary,
    required this.totalCtc,
    required this.employee,
    required this.company,
    required this.createdAt,
  });

  factory Payslip.fromJson(Map<String, dynamic> json) {
    return Payslip(
      id: json['id'],
      month: json['month'],
      year: json['year'],
      status: json['status'],

      payableDays: double.tryParse(json['payable_days'].toString()) ?? 0,
      totalDays: json['total_days'] ?? 0,

      earnings: json['earnings'] ?? {},
      deductions: json['deductions'] ?? {},
      employerContributions: json['employer_contributions'] ?? {},

      grossSalary: double.tryParse(json['gross_salary'].toString()) ?? 0,
      totalDeductions:
          double.tryParse(json['total_deductions'].toString()) ?? 0,
      netSalary: double.tryParse(json['net_salary'].toString()) ?? 0,
      totalCtc: double.tryParse(json['total_ctc'].toString()) ?? 0,

      employee: Employee.fromJson(json['employee']),
      company: Company.fromJson(json['company']),

      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

class Employee {
  final String name;
  final String email;
  final String? designation;
  final String department;

  Employee({
    required this.name,
    required this.email,
    this.designation,
    required this.department,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      name: json['user']?['name'] ?? '',
      email: json['user']?['email'] ?? '',
      designation: json['designation'],
      department: json['department']?['name'] ?? '',
    );
  }
}

class Company {
  final String name;
  final String address;
  final String? logo;

  Company({required this.name, required this.address, this.logo});

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      logo: json['logo_filename'],
    );
  }
}
