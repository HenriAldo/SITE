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
      insertionDate: DateTime.tryParse(json['insertion_date'] ?? '') ??
          DateTime.now(),
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

  PatientProfile copyWith({
    String? name,
    int? age,
    String? catheterType,
    DateTime? insertionDate,
    String? diagnosis,
    bool? isImmunosuppressed,
    List<String>? comorbidities,
    String? lastLabSummary,
  }) {
    return PatientProfile(
      name: name ?? this.name,
      age: age ?? this.age,
      catheterType: catheterType ?? this.catheterType,
      insertionDate: insertionDate ?? this.insertionDate,
      diagnosis: diagnosis ?? this.diagnosis,
      isImmunosuppressed: isImmunosuppressed ?? this.isImmunosuppressed,
      comorbidities: comorbidities ?? this.comorbidities,
      lastLabSummary: lastLabSummary ?? this.lastLabSummary,
    );
  }
}

/// A clinician's own contact details — stored once per clinician and
/// looked up via the patient's assigned clinicianId, so updating it
/// automatically propagates to every patient the clinician is treating.
class ClinicianContact {
  final String clinicianName;
  final String phone;
  final String clinic;

  const ClinicianContact({
    this.clinicianName = '',
    this.phone = '',
    this.clinic = '',
  });

  bool get isEmpty =>
      clinicianName.isEmpty && phone.isEmpty && clinic.isEmpty;

  factory ClinicianContact.fromJson(Map<String, dynamic> json) =>
      ClinicianContact(
        clinicianName: json['clinician_name'] ?? '',
        phone: json['phone'] ?? '',
        clinic: json['clinic'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'clinician_name': clinicianName,
        'phone': phone,
        'clinic': clinic,
      };
}
