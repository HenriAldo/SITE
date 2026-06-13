import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
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
You are an image analysis assistant supporting a remote patient monitoring programme.
A patient has submitted a photograph of their IV line insertion site for routine review.
Your task is to describe what you observe and return a structured JSON assessment.

Use the following exit-site appearance scale to grade what you see:
- Score 0 (Normal): Skin colour normal, no swelling, no discharge
- Score 1 (Minimal): Slight skin colour change under 3 mm, trace non-cloudy moisture, no swelling
- Score 2 (Advancing): Skin colour change 3–6 mm or visibly increasing, mild swelling possible
- Score 3 (Concerning): Cloudy or opaque discharge present AND/OR skin colour change over 6 mm or rapidly spreading
- Score NV: Insertion point not visible in the image

Return ONLY this raw JSON object — no markdown, no code fences, no extra text:
{
  "central_line_detected": true,
  "clisa_score": 0,
  "risk_level": "low",
  "visual_findings": ["brief description of what is visible"],
  "reasoning": "step-by-step reasoning referencing the scale above",
  "patient_message": "direct 1-2 sentence message stating what was observed and what the patient should do next. Do NOT start with Thank you, greetings, or acknowledgements. Do NOT reference the catheter type by name. Start directly with the observation.",
  "escalate": false
}

risk_level rules:
- "low"      → score 0–1
- "moderate" → score 2
- "high"     → score 3, OR immunocompromised patient with score >= 1
escalate: true only when risk_level is "high".
If the insertion point is not visible: central_line_detected=false, risk_level="low", ask patient to retake with better framing.
''';

  Future<Assessment> analyzeImage({
    required File imageFile,
    required PatientProfile profile,
    required SymptomResponse symptoms,
  }) async {
    final imageBytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(imageBytes);
    final mimeType = _getMimeType(imageFile.path);
    final contextText = _buildContextText(profile);

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
        'maxOutputTokens': 2048,
      },
      // Disable standard safety filters — this is a supervised medical
      // monitoring tool and images of IV sites must not be blocked
      'safetySettings': [
        {'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',  'threshold': 'BLOCK_NONE'},
        {'category': 'HARM_CATEGORY_HARASSMENT',         'threshold': 'BLOCK_NONE'},
        {'category': 'HARM_CATEGORY_HATE_SPEECH',        'threshold': 'BLOCK_NONE'},
        {'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',  'threshold': 'BLOCK_NONE'},
      ],
    };

    final response = await http.post(
      Uri.parse('$_baseUrl?key=${Secrets.geminiApiKey}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    // Always log the raw response body first so we can debug any issue
    debugPrint('── Gemini raw body ──────────────────────');
    debugPrint(response.body);
    debugPrint('─────────────────────────────────────────');

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(
          error['error']?['message'] ?? 'Gemini API error ${response.statusCode}');
    }

    final responseJson = jsonDecode(response.body) as Map<String, dynamic>;

    // Check for safety block — Gemini omits 'candidates' when the prompt
    // is blocked, and instead sets promptFeedback.blockReason
    final candidates = responseJson['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      final blockReason = responseJson['promptFeedback']?['blockReason'];
      throw Exception(
          'Gemini blocked the request${blockReason != null ? ': $blockReason' : '. Try retaking the photo with better lighting.'}');
    }

    // Check finish reason — SAFETY means the response itself was filtered
    final finishReason = candidates[0]['finishReason'] as String?;
    if (finishReason != null && finishReason != 'STOP') {
      throw Exception(
          'Gemini did not complete the response (reason: $finishReason). Try retaking the photo.');
    }

    final text =
        candidates[0]['content']['parts'][0]['text'] as String;

    debugPrint('── Gemini parsed text ───────────────────');
    debugPrint(text);
    debugPrint('─────────────────────────────────────────');

    // Strip any accidental markdown code fences
    final cleaned = text
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();

    final assessmentJson = jsonDecode(cleaned) as Map<String, dynamic>;
    return Assessment.fromJson(assessmentJson, imagePath: imageFile.path);
  }

  String _buildContextText(PatientProfile profile) {
    final ctx = profile.toContextMap();

    return '''
PATIENT CONTEXT:
- Age: ${ctx['age']}
- Catheter type: ${ctx['catheter_type']}
- Days since insertion: ${ctx['days_since_insertion']}
- Diagnosis: ${ctx['diagnosis']}
- Immunosuppressed: ${ctx['immunosuppressed']}
- Comorbidities: ${(ctx['comorbidities'] as List).join(', ')}
- Last labs: ${ctx['last_lab_summary']}

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
