class CustomSymptom {
  final String id;
  final String userId;
  final String symptomType;
  final String intensity;
  final DateTime date;
  final String? note;
  final List<String> relatedFactors;
  final DateTime createdAt;
  final DateTime updatedAt;

  CustomSymptom({
    required this.id,
    required this.userId,
    required this.symptomType,
    required this.intensity,
    required this.date,
    this.note,
    required this.relatedFactors,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CustomSymptom.fromJson(Map<String, dynamic> json) {
    return CustomSymptom(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      symptomType: json['symptomType'] ?? '',
      intensity: json['intensity'] ?? 'mild',
      date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
      note: json['note'],
      relatedFactors: List<String>.from(json['relatedFactors'] ?? []),
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'symptomType': symptomType,
      'intensity': intensity,
      'date': date.toIso8601String(),
      'note': note,
      'relatedFactors': relatedFactors,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}