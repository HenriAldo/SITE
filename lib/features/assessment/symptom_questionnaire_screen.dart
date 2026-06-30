import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/assessment.dart';
import '../../data/models/patient_profile.dart';
import '../../data/models/symptom_response.dart';
import '../../data/services/ai_service.dart';
import '../../data/services/firestore_service.dart';
import 'result_screen.dart';

class SymptomQuestionnaireScreen extends StatefulWidget {
  final File image;

  const SymptomQuestionnaireScreen({super.key, required this.image});

  @override
  State<SymptomQuestionnaireScreen> createState() =>
      _SymptomQuestionnaireScreenState();
}

class _SymptomQuestionnaireScreenState
    extends State<SymptomQuestionnaireScreen> {
  bool? _hasSymptoms;
  bool _hasFever = false;
  bool _hasPain = false;
  bool _hasSwelling = false;
  bool _hasRedness = false;
  bool _hasDrainage = false;
  bool _hasChills = false;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Symptom Check')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How are you feeling?',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Think about the last 24 hours.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 28),
                    _buildMainQuestion(context),
                    if (_hasSymptoms == true) ...[
                      const SizedBox(height: 24),
                      _buildSymptomChecklist(context),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: ElevatedButton(
                onPressed: _hasSymptoms == null ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Analyse'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainQuestion(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Did you notice any symptoms in the last 24 hours?',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildChoiceCard(
                context,
                label: 'Yes',
                icon: Icons.check,
                isSelected: _hasSymptoms == true,
                onTap: () => setState(() => _hasSymptoms = true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildChoiceCard(
                context,
                label: 'No',
                icon: Icons.close,
                isSelected: _hasSymptoms == false,
                onTap: () => setState(() => _hasSymptoms = false),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChoiceCard(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent.withOpacity(0.15)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.cardBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.accent : AppColors.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.accent : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSymptomChecklist(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Which symptoms are you experiencing?',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Select all that apply.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        _buildSymptomTile(
          'Fever',
          'Temperature above 38°C',
          Icons.thermostat_outlined,
          _hasFever,
          (v) => setState(() => _hasFever = v),
        ),
        _buildSymptomTile(
          'Chills or shivering',
          'Sudden cold feeling or shaking',
          Icons.ac_unit_outlined,
          _hasChills,
          (v) => setState(() => _hasChills = v),
        ),
        _buildSymptomTile(
          'Pain at the catheter site',
          'Tenderness or discomfort around the line',
          Icons.pin_drop_outlined,
          _hasPain,
          (v) => setState(() => _hasPain = v),
        ),
        _buildSymptomTile(
          'Redness',
          'Skin around the catheter appears red',
          Icons.circle_outlined,
          _hasRedness,
          (v) => setState(() => _hasRedness = v),
        ),
        _buildSymptomTile(
          'Swelling',
          'Area around catheter feels puffy',
          Icons.water_outlined,
          _hasSwelling,
          (v) => setState(() => _hasSwelling = v),
        ),
        _buildSymptomTile(
          'Discharge or leaking',
          'Fluid or crusting around the catheter',
          Icons.opacity_outlined,
          _hasDrainage,
          (v) => setState(() => _hasDrainage = v),
        ),
      ],
    );
  }

  Widget _buildSymptomTile(
    String label,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: value ? AppColors.accent.withOpacity(0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value ? AppColors.accent.withOpacity(0.5) : AppColors.cardBorder,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: value ? AppColors.accent : AppColors.textSecondary,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: value ? AppColors.textPrimary : AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: AppColors.accent,
              side: BorderSide(color: AppColors.textSecondary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);

    final symptoms = SymptomResponse(
      hasSymptoms: _hasSymptoms ?? false,
      hasFever: _hasFever,
      hasChills: _hasChills,
      hasPain: _hasPain,
      hasRedness: _hasRedness,
      hasSwelling: _hasSwelling,
      hasDrainage: _hasDrainage,
    );

    // Load real profile from Firestore
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final profile = userId != null
        ? await FirestoreService().getProfile(userId) ??
            PatientProfile(
              name: FirebaseAuth.instance.currentUser?.displayName ?? '',
              age: 0,
              catheterType: 'Unknown',
              insertionDate: DateTime.now(),
              diagnosis: 'Not provided',
              isImmunosuppressed: false,
            )
        : PatientProfile(
            name: '',
            age: 0,
            catheterType: 'Unknown',
            insertionDate: DateTime.now(),
            diagnosis: 'Not provided',
            isImmunosuppressed: false,
          );

    try {
      if (kDebugMode) debugPrint('── Step 1: Starting AI analysis ─────────');
      final assessment = await AiService().analyzeImage(
        imageFile: widget.image,
        profile: profile,
        symptoms: symptoms,
      );
      if (kDebugMode) {
        debugPrint('── Step 1 done: risk=${assessment.riskLevel.name} escalate=${assessment.escalate}');
      }

      final userId = FirebaseAuth.instance.currentUser?.uid;
      Assessment assessmentWithUrl = assessment;

      // Upload image to Firebase Storage (with 30s timeout)
      if (userId != null) {
        if (kDebugMode) debugPrint('── Step 2: Uploading image to Storage ───');
        try {
          final imageUrl = await FirestoreService()
              .uploadAssessmentImage(userId, assessment.id, widget.image)
              .timeout(const Duration(seconds: 10));
          assessmentWithUrl = assessment.copyWith(imageUrl: imageUrl);
          if (kDebugMode) debugPrint('── Step 2 done');
        } catch (uploadError) {
          // Storage upload failed — continue without the image URL
          // so the assessment result is still shown to the patient
          if (kDebugMode) {
            debugPrint('── Step 2 FAILED (storage upload): $uploadError');
            debugPrint('── Continuing without image URL');
          }
        }
      }

      // Save to Firestore
      if (userId != null) {
        if (kDebugMode) debugPrint('── Step 3: Saving to Firestore ──────────');
        await FirestoreService().saveAssessment(
          userId,
          assessmentWithUrl,
          patientName: FirebaseAuth.instance.currentUser?.displayName ?? '',
          patientEmail: FirebaseAuth.instance.currentUser?.email ?? '',
          patientAge: profile.age > 0 ? profile.age : null,
        );
        if (kDebugMode) debugPrint('── Step 3 done');
      }

      if (kDebugMode) debugPrint('── Step 4: Navigating to result ─────────');
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ResultScreen(assessment: assessmentWithUrl)),
      );
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('── Assessment error ─────────────────────');
        debugPrint('$e');
        debugPrint('$stack');
        debugPrint('─────────────────────────────────────────');
      }
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'We could not analyse your photo. Please check your connection and try again.'),
          backgroundColor: AppColors.riskHigh,
        ),
      );
    }
  }
}
