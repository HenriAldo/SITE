# SITE — AI-Assisted Remote Catheter Monitoring

**System for Intelligent Telemonitoring and Early-Detection**

SITE is a Flutter-based patient app for early detection of CLABSI (Central Line-Associated Bloodstream Infections) in ambulatory oncology patients. It combines guided photo capture of catheter exit sites, a structured symptom questionnaire, and multimodal AI assessment to triage infection risk — escalating flagged cases to a clinician for asynchronous review.

---

## The Problem

Oncology patients carrying a PICC or tunneled central venous catheter (CVC) at home have no structured way to monitor their catheter exit site between clinical visits. Without guidance, patients either dismiss early warning signs (leading to delayed bacteremia) or panic over benign changes (leading to unnecessary ED visits). Clinicians rely on unreliable verbal phone triage to assess severity remotely.

## The Solution

SITE gives patients a structured daily monitoring routine and replaces phone triage with asynchronous, image-based clinician review.

```
Patient App          →    Claude Vision API     →    Risk Classification
─────────────────         ─────────────────          ───────────────────
Guided photo capture      CLISA scoring (0–3)        Low      → Reassure
Symptom questionnaire     Clinical context            Moderate → Clinician dashboard
Clinical profile          Symptom integration         High     → Urgent alert
```

---

## Features

- **Guided photo capture** — step-by-step camera flow with framing instructions
- **Symptom questionnaire** — branching checklist (fever, pain, swelling, drainage, chills)
- **AI risk assessment** — Claude Vision API scores the exit site using the CLISA rubric and integrates patient symptoms and clinical context
- **Risk triage** — Low / Moderate / High with patient-appropriate messaging
- **Assessment history** — longitudinal view of all past check-ins
- **Clinician escalation** — moderate and high-risk cases are flagged for review

---

## Tech Stack

| Layer | Technology |
|---|---|
| Patient app | Flutter (Android + iOS) |
| AI assessment | Anthropic Claude API (vision) |
| Storage | Firebase Firestore + Storage *(planned)* |
| Auth | Firebase Auth *(planned)* |
| Clinician dashboard | Flutter Web / TBD |

---

## Project Structure

```
lib/
├── main.dart                              # App entry point + navigation shell
├── core/
│   └── theme/
│       ├── app_colors.dart                # Brand color palette
│       └── app_theme.dart                 # Global Material theme
├── data/
│   ├── models/
│   │   ├── assessment.dart                # Assessment model + RiskLevel enum
│   │   ├── patient_profile.dart           # Patient clinical context
│   │   └── symptom_response.dart          # Symptom questionnaire response
│   └── services/
│       └── ai_service.dart                # Claude API integration
└── features/
    ├── home/
    │   └── home_screen.dart               # Dashboard + daily check-in card
    ├── assessment/
    │   ├── guided_capture_screen.dart     # Camera flow
    │   ├── symptom_questionnaire_screen.dart
    │   └── result_screen.dart             # Risk result + next steps
    ├── history/
    │   └── history_screen.dart            # Longitudinal assessment list
    └── shared/widgets/
        └── risk_badge.dart                # Reusable risk level indicator
```

---

## Getting Started

### Prerequisites

- Flutter 3.19+
- Dart 3.3+
- Android SDK 21+ / iOS 14+
- An [Anthropic API key](https://console.anthropic.com)

### Setup

1. **Clone the repo**
   ```bash
   git clone https://github.com/your-username/site.git
   cd site/site_app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Add your API key**

   Open `lib/data/services/ai_service.dart` and replace the placeholder:
   ```dart
   static const String _apiKey = 'YOUR_ANTHROPIC_API_KEY';
   ```

4. **Run the app**
   ```bash
   flutter run
   ```

---

## AI Assessment

The AI layer uses Claude's vision model with a structured system prompt encoding the **CLISA (Central Line Insertion Site Assessment)** scoring rubric:

| Score | Finding | Action |
|---|---|---|
| 0 | Normal — flesh-colored, no redness or drainage | Continue monitoring |
| 1 | Minimal redness < 3mm, scant non-cloudy drainage | Monitor carefully |
| 2 | Advancing redness 3–6mm or increase over 24h | Alert physician |
| 3 | Purulence, cloudy drainage, or redness > 6mm | Consider line removal |
| NV | Insertion site not visible | Replace dressing |

The model integrates image findings with patient-reported symptoms and clinical context (catheter type, days since insertion, immunosuppression status, diagnosis) to produce a structured JSON risk assessment.

---

## Disclaimer

SITE is a prototype developed as part of a university product-building course. It is **not a validated medical device** and is not intended for clinical use. All assessments are for informational purposes only and do not replace clinical judgment.

---

## Team

Henri · Philipp · Paula · Alyssa · Darius
