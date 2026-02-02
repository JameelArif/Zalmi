class Employee {
  final int id;
  final String email;
  final String name;
  final String contact;
  final String? uid;
  final bool isActive;
  final DateTime hiredDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  Employee({
    required this.id,
    required this.email,
    required this.name,
    required this.contact,
    this.uid,
    required this.isActive,
    required this.hiredDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'] as int,
      email: json['email'] as String,
      name: json['name'] as String,
      contact: json['contact'] as String,
      uid: json['uid'] as String?,
      isActive: json['is_active'] as bool,
      hiredDate: DateTime.parse(json['hired_date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'name': name,
      'contact': contact,
      'uid': uid,
      'is_active': isActive,
      'hired_date': hiredDate.toIso8601String(),
    };
  }
}