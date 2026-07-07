import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/patient_profile.dart';
import '../../data/services/firestore_service.dart';

class CareTeamScreen extends StatelessWidget {
  const CareTeamScreen({super.key});

  Future<ClinicianContact?> _fetchClinicianContact(String userId) async {
    final clinicianId = await FirestoreService().getAssignedClinicianId(userId);
    if (clinicianId == null) return null;
    return FirestoreService().getClinicianContact(clinicianId);
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Contact Care Team')),
      body: FutureBuilder<ClinicianContact?>(
        future: userId != null
            ? _fetchClinicianContact(userId)
            : Future.value(null),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            );
          }

          final team = snapshot.data;
          final hasTeam = team != null && !team.isEmpty;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildUrgentBanner(context),
                const SizedBox(height: 24),
                if (hasTeam) ...[
                  _buildContactCard(context, team!),
                ] else ...[
                  _buildNoTeamCard(context),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildUrgentBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.riskHighBg,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.riskHigh.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emergency_outlined,
                  color: AppColors.riskHigh, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'If you have fever above 38°C or severe chills, go to the emergency room immediately — do not wait.',
                  style: TextStyle(
                    color: AppColors.riskHigh.withOpacity(0.9),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: AppColors.riskHigh.withOpacity(0.2)),
          const SizedBox(height: 12),
          _build116117Notice(context),
        ],
      ),
    );
  }

  Widget _buildContactCard(BuildContext context, ClinicianContact team) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                const Icon(Icons.groups_outlined,
                    size: 16, color: AppColors.accent),
                const SizedBox(width: 8),
                Text('Your Care Team',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
          const Divider(height: 1),
          if (team.clinicianName.isNotEmpty)
            _contactRow(
              context,
              icon: Icons.person_outlined,
              label: 'Treating physician',
              value: team.clinicianName,
            ),
          if (team.clinic.isNotEmpty)
            _contactRow(
              context,
              icon: Icons.local_hospital_outlined,
              label: 'Clinic',
              value: team.clinic,
            ),
          if (team.phone.isNotEmpty)
            _contactRow(
              context,
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: team.phone,
              phoneNumber: team.phone,
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildNoTeamCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Icon(Icons.groups_outlined,
              color: AppColors.textSecondary, size: 36),
          const SizedBox(height: 12),
          Text(
            'No care team contact yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your clinician hasn\'t added their contact details yet.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _build116117Notice(BuildContext context) {
    return GestureDetector(
      onTap: () => _call(context, '116117'),
      child: Row(
        children: [
          Icon(Icons.phone_outlined, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontSize: 12, color: AppColors.textSecondary),
                children: [
                  const TextSpan(text: 'In doubt? Call '),
                  TextSpan(
                    text: '116117',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const TextSpan(
                      text: ' — the patient service in Germany.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    String? phoneNumber,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 2),
                if (phoneNumber != null)
                  GestureDetector(
                    onTap: () => _call(context, phoneNumber),
                    onLongPress: () => _copyToClipboard(context, phoneNumber),
                    child: Text(
                      value,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  )
                else
                  Text(
                    value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _call(BuildContext context, String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the phone dialer.')),
      );
    }
  }

  void _copyToClipboard(BuildContext context, String text) {
    HapticFeedback.mediumImpact();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
