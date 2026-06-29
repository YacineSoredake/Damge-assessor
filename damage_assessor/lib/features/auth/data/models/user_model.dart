class UserModel {
  final String id;
  final String? name;
  final String phone;
  final String? email;
  final String? company;
  final bool freeReportUsed;
  final String subscriptionStatus; // none | active | expired | grace

  UserModel({
    required this.id,
    required this.phone,
    required this.freeReportUsed,
    required this.subscriptionStatus,
    this.name,
    this.email,
    this.company,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      phone: json['phone'] as String,
      name: json['name'] as String?,
      email: json['email'] as String?,
      company: json['company'] as String?,
      freeReportUsed: json['free_report_used'] as bool? ?? false,
      subscriptionStatus: json['subscription_status'] as String? ?? 'none',
    );
  }
}
