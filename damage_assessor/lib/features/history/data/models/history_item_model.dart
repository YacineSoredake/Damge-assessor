class HistoryItem {
  final int id;
  final String plateNumber;
  final String? vehicle;
  final String? overallCondition;
  final String status;
  final DateTime createdAt;

  HistoryItem({
    required this.id,
    required this.plateNumber,
    required this.status,
    required this.createdAt,
    this.vehicle,
    this.overallCondition,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      id: json['id'] as int,
      plateNumber: json['plate_number'] as String,
      vehicle: json['vehicle'] as String?,
      overallCondition: json['overall_condition'] as String?,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}