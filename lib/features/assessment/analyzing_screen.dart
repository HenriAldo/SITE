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

class AnalyzingScreen extends StatefulWidget {
  final File image;
  final SymptomResponse symptoms;

  const AnalyzingScreen({
    super.key,
    required this.image,
    required this.symptoms,
  });

  @override
  State<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends State<AnalyzingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  int _messageIndex = 0;

  static const _messages = [
    'Analysing your photo…',
    'Checking for visual changes…',
    'Reviewing catheter site…',
    'Preparing your result…',
  ];

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _runAnalysis();

    // Cycle status messages every 2.5 s
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 2500));
      if (!mounted) return false;
      setState(() {
        _messageIndex = (_messageIndex + 1) % _messages.length;
      });
      return true;
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _runAnalysis() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    // users/{uid}.display_name in Firestore is the name the clinician side
    // reads — fall back to Firebase Auth's displayName only if that's unset
    // (e.g. a legacy account), so patient records stay identified by name.
    final displayName = userId != null
        ? await FirestoreService().getDisplayName(userId)
        : '';
    final resolvedName = displayName.isNotEmpty
        ? displayName
        : FirebaseAuth.instance.currentUser?.displayName ?? '';

    final profile = userId != null
        ? await FirestoreService().getProfile(userId) ??
            PatientProfile(
              name: resolvedName,
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
        symptoms: widget.symptoms,
      );
      if (kDebugMode) {
        debugPrint(
            '── Step 1 done: risk=${assessment.riskLevel.name} escalate=${assessment.escalate}');
      }

      Assessment assessmentWithExtras =
          assessment.copyWith(symptoms: widget.symptoms);

      if (userId != null) {
        if (kDebugMode) debugPrint('── Step 2: Uploading image ───────────────');
        try {
          final imageUrl = await FirestoreService()
              .uploadAssessmentImage(userId, assessment.id, widget.image)
              .timeout(const Duration(seconds: 10));
          assessmentWithExtras = assessmentWithExtras.copyWith(imageUrl: imageUrl);
          if (kDebugMode) debugPrint('── Step 2 done');
        } catch (uploadError) {
          if (kDebugMode) {
            debugPrint('── Step 2 FAILED (upload): $uploadError');
            debugPrint('── Continuing without image URL');
          }
        }
      }

      if (userId != null) {
        if (kDebugMode) debugPrint('── Step 3: Saving to Firestore ──────────');
        await FirestoreService().saveAssessment(
          userId,
          assessmentWithExtras,
          patientName: resolvedName,
          patientEmail: FirebaseAuth.instance.currentUser?.email ?? '',
          patientAge: profile.age > 0 ? profile.age : null,
        );
        if (kDebugMode) debugPrint('── Step 3 done');
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => ResultScreen(assessment: assessmentWithExtras)),
      );
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('── Analysis error ───────────────────────');
        debugPrint('$e');
        debugPrint('$stack');
      }
      if (!mounted) return;
      _showError();
    }
  }

  void _showError() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Analysis failed'),
        content: const Text(
            'We could not analyse your photo. Please check your connection and try again.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(); // back to symptom screen
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, __) => Opacity(
                    opacity: 0.4 + 0.6 * _pulse.value,
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.biotech_outlined,
                        size: 44,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: Text(
                    _messages[_messageIndex],
                    key: ValueKey(_messageIndex),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'This usually takes 10–20 seconds.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
