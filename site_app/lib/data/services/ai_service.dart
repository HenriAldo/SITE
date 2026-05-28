import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/assessment.dart';
import '../models/patient_profile.dart';
import '../models/symptom_response.dart';

class AiService {
  static const String _baseUrl = 'https://api.anthropic.com/v1/messages';
  static const String _model = 'claude-haiku-4-5-20251001';

  // Set your API key here or load from secure storage
  static const String _apiKey = 'YOUR_ANTHROPIC_API_KEY';

  static const String _systemPrompt = '''
You are a clinical risk assessment tool for monitoring central venous catheter (CVC/PICC) exit sites for signs of infection (CLABSI - Central Line Associated Bloodstream Infection).

You will receive:
1. An image of a central line insertion/exit site
2. Patient clinical context (age, catheter type, days since insertion, diagnosis, immunosuppression status)
3. Patient-reported symptoms

Your task is to assess the image using the CLISA (Central Line Insertion Site Assessment) scoring criteria:
- Score 0 (Normal): Skin is flesh-colored, no redness, localized swelling, or drainage
- Score 1 (Minimal Redness): Redness < 1 catheter width (3mm), drainage/crusting scant and non-cloudy if present, no localized swelling
- Score 2 (Advancing Redness): Redness 1-2 catheter widths (3-6mm) OR increase over 24h, swelling may be present, drainage non-cloudy if present
- Score 3 (Severe/Cloudy Drainage): Purulence, cloudy drainage AND/OR redness > 2 catheter widths (6mm) or rapid increase, swelling may be present
- NV (Not Visible): Insertion site obscured by dressing or not visible

Respond ONLY with valid JSON in this exact format:
{
  "central_line_detected": true or false,
  "clisa_score": 0, 1, 2, 3, or "NV",
  "risk_level": "low", "moderate", or "high",
  "visual_findings": ["finding 1", "finding 2"],
  "reasoning": "Brief clinical reasoning integrating image + symptoms + context",
  "patient_message": "A calm, clear, reassuring message for the patient (non-technical)",
  "escalate": true or false
}

Risk level mapping:
- low: CLISA 0-1, no concerning symptoms → reassure and continue monitoring
- moderate: CLISA 2, or CLISA 1 with concerning symptoms → escalate to clinician dashboard
- high: CLISA 3, or fever + any site changes, or immunocompromised with any CLISA ≥ 1 → urgent medical attention

If no central line is visible, set central_line_detected to false, risk_level to "low", and advise the patient to retake the photo.

Important: You are a decision-support tool only. Always keep patient_message calm and clear. Never alarm unnecessarily. Never replace clinical judgment.
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
      'model': _model,
      'max_tokens': 1024,
      'system': _systemPrompt,
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': mimeType,
                'data': base64Image,
              },
            },
            {
              'type': 'text',
              'text': contextText,
            },
          ],
        }
      ],
    };

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': _apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200) {
      throw Exception('AI service error: ${response.statusCode}');
    }

    final responseJson = jsonDecode(response.body);
    final content = responseJson['content'][0]['text'] as String;
    final assessmentJson = jsonDecode(content) as Map<String, dynamic>;

    return Assessment.fromJson(assessmentJson, imagePath: imageFile.path);
  }

  String _buildContextText(PatientProfile profile, SymptomResponse symptoms) {
    final ctx = profile.toContextMap();
    final sym = symptoms.toContextMap();

    return '''
Please assess this catheter exit site image.

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
- Redness noticed: ${sym['redness']}
- Drainage: ${sym['drainage']}
- Chills: ${sym['chills']}
- Notes: ${sym['additional_notes'] ?? 'None'}

Provide your assessment as JSON.
''';
  }

  String _getMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    } else if (lower.endsWith('.png')) {
      return 'image/png';
    } else if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }
}
