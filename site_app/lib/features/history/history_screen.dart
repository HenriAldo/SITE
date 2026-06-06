import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/assessment.dart';
import '../../data/services/firestore_service.dart';
import '../../shared/widgets/risk_badge.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Assessment History')),
      body: userId == null
          ? const Center(child: Text('Not signed in'))
          : StreamBuilder<List<Assessment>>(
              stream: FirestoreService().assessmentStream(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  );
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final assessments = snapshot.data ?? [];
                if (assessments.isEmpty) return _buildEmpty(context);
                return ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: assessments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      _buildHistoryCard(context, assessments[index]),
                );
              },
            ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.history, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(
            'No assessments yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete your first daily check-in\nto see results here.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, Assessment assessment) {
    final dateStr =
        DateFormat('EEEE, d MMM — HH:mm').format(assessment.timestamp);
    final hasImage = assessment.imagePath != null &&
        File(assessment.imagePath!).existsSync();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo
          if (hasImage)
            _buildImageHeader(assessment.imagePath!, assessment.riskLevel)
          else
            _buildNoImagePlaceholder(assessment.riskLevel),

          // Text content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      dateStr,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontSize: 12),
                    ),
                    RiskBadge(riskLevel: assessment.riskLevel),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  assessment.patientMessage,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                ),
                if (assessment.escalate) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.person_outline,
                          size: 13, color: AppColors.riskModerate),
                      const SizedBox(width: 5),
                      Text(
                        'Escalated to clinician',
                        style: TextStyle(
                          color: AppColors.riskModerate,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageHeader(String imagePath, RiskLevel riskLevel) {
    return Stack(
      children: [
        Image.file(
          File(imagePath),
          width: double.infinity,
          height: 160,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildNoImagePlaceholder(riskLevel),
        ),
        // Subtle gradient overlay so the badge stays readable
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.3),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoImagePlaceholder(RiskLevel riskLevel) {
    return Container(
      width: double.infinity,
      height: 72,
      color: AppColors.navyLight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported_outlined,
              size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            'No photo available',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
