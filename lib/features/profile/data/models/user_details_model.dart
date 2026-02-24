class Userdetails {
  String? id;
  String? userId;
  String? associatesName;
  String? payrollCode;
  String? designation;

  // Department
  String? departmentId;
  String? departmentName;

  // Relations
  String? managerId;
  String? departmentHeadId;

  // Work info
  String? doj;
  String? totalExperience;
  String? workLocation;

  // Contacts
  String? contactPrimary;
  String? contactSecondary;
  String? secondaryContactName;

  String? emergencyContact;
  String? emergencyContactName;

  String? email;
  String? bloodGroup;

  // Profile
  String? profilePicture;

  // Company
  String? companyId;
  String? companyName;
  String? companyLogoFilename;

  // Permissions
  bool employeeEditEnabled = false;

  // Relations objects
  Manager? manager;
  Manager? departmentHead;

  Userdetails({
    this.id,
    this.userId,
    this.associatesName,
    this.payrollCode,
    this.designation,
    this.departmentId,
    this.departmentName,
    this.managerId,
    this.departmentHeadId,
    this.doj,
    this.totalExperience,
    this.workLocation,
    this.contactPrimary,
    this.contactSecondary,
    this.secondaryContactName,
    this.emergencyContact,
    this.emergencyContactName,
    this.email,
    this.bloodGroup,
    this.profilePicture,
    this.companyId,
    this.companyName,
    this.companyLogoFilename,
    this.employeeEditEnabled = false,
    this.manager,
    this.departmentHead,
  });

  Userdetails.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    userId = json['user_id'];
    associatesName = json['associates_name'];
    payrollCode = json['payroll_code'];
    designation = json['designation'];

    /// Department
    departmentId = json['department']?['id'];
    departmentName = json['department']?['name'];

    /// Relations
    managerId = json['manager_id'];
    departmentHeadId = json['department_head_id'];

    /// Work info
    doj = json['doj'];
    totalExperience = json['total_experience'];
    workLocation = json['work_location'];

    /// Contacts
    contactPrimary = json['contact_primary'];
    contactSecondary = json['contact_secondary'];
    secondaryContactName = json['secondary_contact_name'];

    emergencyContact = json['emergency_contact'];
    emergencyContactName = json['emergency_contact_name'];

    email = json['email'];
    bloodGroup = json['blood_group'];

    /// Profile
    profilePicture = json['profile_picture'];

    /// Company
    companyId = json['company_id'];
    companyName = json['company']?['name'];
    companyLogoFilename = json['company']?['logo_filename'];

    /// Permissions
    employeeEditEnabled = json['employee_edit_enabled'] ?? false;

    /// Relations objects
    manager = json['manager'] != null
        ? Manager.fromJson(json['manager'])
        : null;

    departmentHead = json['department_head'] != null
        ? Manager.fromJson(json['department_head'])
        : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'associates_name': associatesName,
      'payroll_code': payrollCode,
      'designation': designation,
      'department_id': departmentId,
      'department_name': departmentName,
      'manager_id': managerId,
      'department_head_id': departmentHeadId,
      'doj': doj,
      'total_experience': totalExperience,
      'work_location': workLocation,
      'contact_primary': contactPrimary,
      'contact_secondary': contactSecondary,
      'secondary_contact_name': secondaryContactName,
      'emergency_contact': emergencyContact,
      'emergency_contact_name': emergencyContactName,
      'email': email,
      'blood_group': bloodGroup,
      'profile_picture': profilePicture,
      'company_id': companyId,
      'company_name': companyName,
      'company_logo_filename': companyLogoFilename,
      'employee_edit_enabled': employeeEditEnabled,
      'manager': manager?.toJson(),
      'department_head': departmentHead?.toJson(),
    };
  }
}

class Manager {
  String? id;
  String? name;
  String? email;

  Manager({this.id, this.name, this.email});

  Manager.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    email = json['email'];
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'email': email};
  }
}
