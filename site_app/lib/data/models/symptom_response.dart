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
}
