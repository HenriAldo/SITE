import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/firestore_service.dart';
import '../profile/profile_edit_screen.dart';

class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  late Future<List<PatientSummary>> _patientsFuture;
  bool _showMyOnly = true;
  String get _clinicianId => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _patientsFuture = _showMyOnly
          ? FirestoreService().getMyPatients(_clinicianId)
          : FirestoreService().getPatients();
    });
  }

  Future<void> _assign(PatientSummary patient) async {
    await FirestoreService().assignPatientToClinician(patient.userId, _clinicianId);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patients'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _buildFilterBar(),
        ),
      ),
      body: FutureBuilder<List<PatientSummary>>(
        future: _patientsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            );
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final patients = snapshot.data ?? [];
          if (patients.isEmpty) {
            return _buildEmpty(context);
          }

          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: patients.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) =>
                _buildPatientCard(context, patients[i]),
          );
        },
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _filterChip('My Patients', true),
          const SizedBox(width: 8),
          _filterChip('All Patients', false),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool value) {
    final selected = _showMyOnly == value;
    return GestureDetector(
      onTap: () {
        if (_showMyOnly != value) {
          _showMyOnly = value;
          _load();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_outline,
              size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(
            _showMyOnly
                ? 'No patients assigned to you'
                : 'No patients registered yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _showMyOnly
                ? 'Switch to "All Patients" to find and assign patients to yourself.'
                : 'Patients appear here once they register\nand log in to the app.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildPatientCard(BuildContext context, PatientSummary patient) {
    final profile = patient.profile;
    final profileComplete = patient.hasProfile &&
        profile != null &&
        profile.catheterType.isNotEmpty &&
        profile.diagnosis.isNotEmpty;

    final isMyPatient = patient.clinicianId == _clinicianId;
    final isAssignedElsewhere =
        patient.clinicianId != null && !isMyPatient;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: profileComplete
              ? AppColors.cardBorder
              : AppColors.accent.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_outline,
                    color: AppColors.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (patient.displayName.isNotEmpty &&
                        patient.email.isNotEmpty)
                      Text(
                        patient.email,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontSize: 12),
                      ),
                  ],
                ),
              ),
              _assignmentBadge(isMyPatient, isAssignedElsewhere),
            ],
          ),

          if (profile != null && profile.catheterType.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                _infoChip(Icons.medical_services_outlined,
                    profile.catheterType),
                const SizedBox(width: 8),
                _infoChip(Icons.calendar_today_outlined,
                    'Day ${profile.daysSinceInsertion}'),
                if (profile.diagnosis.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _infoChip(
                        Icons.local_hospital_outlined, profile.diagnosis,
                        expand: true),
                  ),
                ],
              ],
            ),
          ],

          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final saved = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfileEditScreen(
                          existing: patient.profile,
                          targetUserId: patient.userId,
                          patientLabel: patient.name,
                        ),
                      ),
                    );
                    if (saved == true) _load();
                  },
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(patient.hasProfile
                      ? 'Edit Profile'
                      : 'Set Up Profile'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: BorderSide(
                      color: profileComplete
                          ? AppColors.cardBorder
                          : AppColors.accent.withOpacity(0.5),
                    ),
                    minimumSize: const Size(0, 40),
                  ),
                ),
              ),
              if (!isMyPatient) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: isAssignedElsewhere ? null : () => _assign(patient),
                  icon: const Icon(Icons.link, size: 16),
                  label: const Text('Assign to me'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: BorderSide(
                        color: AppColors.accent.withOpacity(0.5)),
                    minimumSize: const Size(0, 40),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _assignmentBadge(bool isMyPatient, bool isAssignedElsewhere) {
    final Color bg;
    final Color border;
    final Color text;
    final String label;

    if (isMyPatient) {
      bg = AppColors.riskLowBg;
      border = AppColors.riskLow.withOpacity(0.4);
      text = AppColors.riskLow;
      label = 'My patient';
    } else if (isAssignedElsewhere) {
      bg = AppColors.surface;
      border = AppColors.cardBorder;
      text = AppColors.textSecondary;
      label = 'Other clinician';
    } else {
      bg = AppColors.riskModerateBg;
      border = AppColors.riskModerate.withOpacity(0.4);
      text = AppColors.riskModerate;
      label = 'Unassigned';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, {bool expand = false}) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        expand
            ? Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
              ),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(6),
      ),
      child: content,
    );
  }
}
