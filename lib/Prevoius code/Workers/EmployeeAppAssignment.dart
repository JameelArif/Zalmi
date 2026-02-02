class EmployeeAppAssignment {
  final int id;
  final int employeeId;
  final int appId;
  final String? appName; // For display
  final DateTime assignedDate;
  final String? assignedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  EmployeeAppAssignment({
    required this.id,
    required this.employeeId,
    required this.appId,
    this.appName,
    required this.assignedDate,
    this.assignedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EmployeeAppAssignment.fromJson(Map<String, dynamic> json) {
    return EmployeeAppAssignment(
      id: json['id'] as int,
      employeeId: json['employee_id'] as int,
      appId: json['app_id'] as int,
      appName: json['app_name'] as String?,
      assignedDate: DateTime.parse(json['assigned_date'] as String),
      assignedBy: json['assigned_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'employee_id': employeeId,
      'app_id': appId,
      'assigned_by': assignedBy,
    };
  }
}