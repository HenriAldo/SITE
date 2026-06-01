import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../secrets.dart';
import '../models/assessment.dart';
import '../models/patient_profile.dart';
import '../models/symptom_response.dart';

class AiService {
  static const String _model = 'gemini-2.5-flash';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  // Embedded directly in content — v1 API does not support systemInstruction
  static const String _instructions = '''
You are a clinical risk assessment tool for central venous catheter (CVC/PICC) exit site monitoring (CLABSI prevention).

Score the image using CLISA criteria:
- 0 (Normal): Flesh-colored skin, no redness, swelling or drainage
- 1 (Minimal): Redness < 3mm, scant non-cloudy drainage if present, no swelling
- 2 (Advancing): Redness 3-6mm OR increase over 24h, swelling possible
- 3 (Severe): Purulence/cloudy drainage AND/OR redness > 6mm or rapid increase
- NV: Insertion site not visible

Return ONLY this raw JSON with no markdown or code fences:
{
  "central_line_detected": true,
  "clisa_score": 0,
  "risk_level": "low",
  "visual_findings": ["finding 1"],
  "reasoning": "clinical reasoning",
  "patient_message": "calm patient-facing message",
  "escalate": false
}

risk_level: low = CLISA 0-1 no symptoms | moderate = CLISA 2 or CLISA 1 + symptoms | high = CLISA 3, fever + changes, or immunocompromised + CLISA >= 1
If no central line visible: central_line_detected=false, risk_level="low", tell patient to retake photo.
''';

  Future<Assessment> analyzeImage({
    required File imageFile,
    required PatientProfile profile,
    required SymptomResponse symptoms,
  }) async {
    final imageBytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(imageBytes);
    final mimeType = _getMimeType(imageFile.path);
    final contextText = _buildContextText(profile, symptoms);

    final requestBody = {
      'contents': [
        {
          'parts': [
            // Instructions first as text
            {'text': _instructions},
            // Then the image
            {
              'inlineData': {
                'mimeType': mimeType,
                'data': base64Image,
              }
            },
            // Then the patient context
            {'text': contextText},
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.1,
        'maxOutputTokens': 1024,
      },
    };

    final response = await http.post(
      Uri.parse('$_baseUrl?key=${Secrets.geminiApiKey}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(
          error['error']?['message'] ?? 'Gemini API error ${response.statusCode}');
    }

    final responseJson = jsonDecode(response.body);
    final text =
        responseJson['candidates'][0]['content']['parts'][0]['text'] as String;

    // Strip any accidental markdown code fences
    final cleaned = text
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();

    final assessmentJson = jsonDecode(cleaned) as Map<String, dynamic>;
    return Assessment.fromJson(assessmentJson, imagePath: imageFile.path);
  }

  String _buildContextText(PatientProfile profile, SymptomResponse symptoms) {
    final ctx = profile.toContextMap();
    final sym = symptoms.toContextMap();

    return '''
PATIENT CONTEXT:
- Age: ${ctx['age']}
- Catheter type: ${ctx['catheter_type']}
- Days since insertion: ${ctx['days_since_insertion']}
- Diagnosis: ${ctx['diagnosis']}
- Immunosuppressed: ${ctx['immunosuppressed']}
- Comorbidities: ${(ctx['comorbidities'] as List).join(', ')}
- Last labs: ${ctx['last_lab_summary']}

PATIENT-REPORTED SYMPTOMS:
- Has symptoms: ${sym['has_symptoms']}
- Fever: ${sym['fever']}${sym['fever_temperature_celsius'] != null ? ' (${sym['fever_temperature_celsius']}°C)' : ''}
- Pain at site: ${sym['pain_at_site']}
- Swelling: ${sym['swelling']}
- Redness: ${sym['redness']}
- Drainage: ${sym['drainage']}
- Chills: ${sym['chills']}
- Notes: ${sym['additional_notes'] ?? 'None'}

Return only raw JSON, no markdown.
''';
  }

  String _getMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}
