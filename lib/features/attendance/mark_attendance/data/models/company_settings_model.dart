class CompanySettings {
  final String? officeStart;
  final String? officeEnd;
  final int autoCloseBufferMinutes;

  final double? officeLat;
  final double? officeLng;
  final double? officeRadius;

  CompanySettings({
    this.officeStart,
    this.officeEnd,
    this.autoCloseBufferMinutes = 30,
    this.officeLat,
    this.officeLng,
    this.officeRadius,
  });

  factory CompanySettings.fromJson(Map<String, dynamic> json) {
    return CompanySettings(
      officeStart: json['office_start_time']?.toString(),
      officeEnd: json['office_end_time']?.toString(),
      autoCloseBufferMinutes:
          int.tryParse(json['auto_close_buffer_minutes']?.toString() ?? '') ??
          30,

      officeLat: json['office_lat'] != null
          ? double.tryParse(json['office_lat'].toString())
          : null,

      officeLng: json['office_lng'] != null
          ? double.tryParse(json['office_lng'].toString())
          : null,

      officeRadius: json['office_radius_meters'] != null
          ? double.tryParse(json['office_radius_meters'].toString())
          : null,
    );
  }
}
