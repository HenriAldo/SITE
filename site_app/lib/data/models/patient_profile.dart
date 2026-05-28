class PatientProfile {
  final String name;
  final int age;
  final String catheterType;
  final DateTime insertionDate;
  final String diagnosis;
  final bool isImmunosuppressed;
  final List<String> comorbidities;
  final String? lastLabSummary;

  const PatientProfile({
    required this.name,
    required this.age,
    required this.catheterType,
    required this.insertionDate,
    required this.diagnosis,
    required this.isImmunosuppressed,
    this.comorbidities = const [],
    this.lastLabSummary,
  });

  int get daysSinceInsertion =>
      DateTime.now().difference(insertionDate).inDays;

  Map<String, dynamic> toContextMap() => {
        'age': age,
        'catheter_type': catheterType,
        'days_since_insertion': daysSinceInsertion,
        'diagnosis': diagnosis,
        'immunosuppressed': isImmunosuppressed,
        'comorbidities': comorbidities,
        'last_lab_summary': lastLabSummary ?? 'Not provided',
      };

  factory PatientProfile.fromJson(Map<String, dynamic> json) {
    return PatientProfile(
      name: json['name'] ?? '',
      age: json['age'] ?? 0,
      catheterType: json['catheter_type'] ?? '',
      insertionDate: DateTime.parse(json['insertion_date']),
      diagnosis: json['diagnosis'] ?? '',
      isImmunosuppressed: json['immunosuppressed'] ?? false,
      comorbidities: List<String>.from(json['comorbidities'] ?? []),
      lastLabSummary: json['last_lab_summary'],
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'age': age,
        'catheter_type': catheterType,
        'insertion_date': insertionDate.toIso8601String(),
        'diagnosis': diagnosis,
        'immunosuppressed': isImmunosuppressed,
        'comorbidities': comorbidities,
        'last_lab_summary': lastLabSummary,
      };
}
