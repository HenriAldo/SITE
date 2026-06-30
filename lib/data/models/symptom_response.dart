class SymptomResponse {
  final bool hasSymptoms;
  final bool hasFever;
  final bool hasPain;
  final bool hasSwelling;
  final bool hasRedness;
  final bool hasDrainage;
  final bool hasChills;
  final double? feverTemperature;
  final String? additionalNotes;

  const SymptomResponse({
    required this.hasSymptoms,
    this.hasFever = false,
    this.hasPain = false,
    this.hasSwelling = false,
    this.hasRedness = false,
    this.hasDrainage = false,
    this.hasChills = false,
    this.feverTemperature,
    this.additionalNotes,
  });

  factory SymptomResponse.none() => const SymptomResponse(hasSymptoms: false);

  Map<String, dynamic> toContextMap() => {
        'has_symptoms': hasSymptoms,
        'fever': hasFever,
        'fever_temperature_celsius': feverTemperature,
        'pain_at_site': hasPain,
        'swelling': hasSwelling,
        'redness': hasRedness,
        'drainage': hasDrainage,
        'chills': hasChills,
        'additional_notes': additionalNotes,
      };

  Map<String, dynamic> toJson() => {
        'has_symptoms': hasSymptoms,
        'fever': hasFever,
        'fever_temperature_celsius': feverTemperature,
        'pain': hasPain,
        'swelling': hasSwelling,
        'redness': hasRedness,
        'drainage': hasDrainage,
        'chills': hasChills,
        'additional_notes': additionalNotes,
      };

  factory SymptomResponse.fromJson(Map<String, dynamic> json) =>
      SymptomResponse(
        hasSymptoms: json['has_symptoms'] as bool? ?? false,
        hasFever: json['fever'] as bool? ?? false,
        hasPain: json['pain'] as bool? ?? false,
        hasSwelling: json['swelling'] as bool? ?? false,
        hasRedness: json['redness'] as bool? ?? false,
        hasDrainage: json['drainage'] as bool? ?? false,
        hasChills: json['chills'] as bool? ?? false,
        feverTemperature: (json['fever_temperature_celsius'] as num?)?.toDouble(),
        additionalNotes: json['additional_notes'] as String?,
      );
}
