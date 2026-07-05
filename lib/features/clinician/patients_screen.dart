import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/firestore_service.dart';
import '../profile/profile_edit_screen.dart';
import 'patient_detail_screen.dart';

class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  late Future<List<PatientSummary>> _patientsFuture;
  bool _showMyOnly = true;
  String? _assigningUserId;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String get _clinicianId => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _patientsFuture = _fetchPatients();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<PatientSummary> _applySearch(List<PatientSummary> patients) {
    if (_searchQuery.isEmpty) return patients;
    return patients
        .where((p) =>
            p.name.toLowerCase().contains(_searchQuery) ||
            p.email.toLowerCase().contains(_searchQuery))
        .toList();
  }

  Future<List<PatientSummary>> _fetchPatients() => _showMyOnly
      ? FirestoreService().getMyPatients(_clinicianId)
      : FirestoreService().getPatients();

  Future<void> _load() async {
    setState(() {
      _patientsFuture = _fetchPatients();
    });
    // Await so that RefreshIndicator spins until data lands
    await _patientsFuture;
  }

  Future<void> _assign(PatientSummary patient) async {
    setState(() => _assigningUserId = patient.userId);
    try {
      await FirestoreService()
          .assignPatientToClinician(patient.userId, _clinicianId);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${patient.name} assigned to you'),
            backgroundColor: AppColors.riskLow,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.riskHigh,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _assigningUserId = null);
    }
  }

  Future<void> _openAddPatientDialog() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add patient'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Patient name'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Please enter a name' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Patient email'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Please enter an email';
                  if (!v.contains('@')) return 'Please enter a valid email';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _createPatient(
      name: nameController.text.trim(),
      email: emailController.text.trim(),
    );
  }

  Future<void> _createPatient({
    required String name,
    required String email,
  }) async {
    final tempPassword = AuthService().generateTempPassword();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      ),
    );

    try {
      final uid = await AuthService().createPatientAuthAccount(
        email: email,
        password: tempPassword,
      );
      await FirestoreService().createPatientRecord(
        uid,
        email: email,
        displayName: name,
        clinicianId: _clinicianId,
      );
      if (mounted) Navigator.pop(context); // close loading dialog
      await _load();
      if (mounted) _showTempPasswordDialog(name, email, tempPassword);
    } on FirebaseAuthException catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AuthService.errorMessage(e)),
            backgroundColor: AppColors.riskHigh,
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not create patient: $e'),
            backgroundColor: AppColors.riskHigh,
          ),
        );
      }
    }
  }

  void _showTempPasswordDialog(String name, String email, String tempPassword) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Patient added'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$name ($email) can now sign in with:'),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      tempPassword,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    tooltip: 'Copy password',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: tempPassword));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Hand this password to the patient in person. They\'ll be asked '
              'to set their own password the first time they sign in.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patients'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_outlined),
            tooltip: 'Add patient',
            onPressed: _openAddPatientDialog,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _buildFilterBar(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) =>
                  setState(() => _searchQuery = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search by name or email…',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<PatientSummary>>(
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

                final patients = _applySearch(snapshot.data ?? []);

                return RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.accent,
                  child: patients.isEmpty
                      ? _buildEmpty(context)
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(24),
                          itemCount: patients.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) =>
                              _buildPatientCard(context, patients[i]),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      decoration: BoxDecoration(
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
    // Wrap in scrollable so pull-to-refresh works on an empty list
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                  _searchQuery.isNotEmpty
                      ? Icons.search_off
                      : Icons.people_outline,
                  size: 48, color: AppColors.textSecondary),
              const SizedBox(height: 16),
              Text(
                _searchQuery.isNotEmpty
                    ? 'No patients match your search'
                    : _showMyOnly
                        ? 'No patients assigned to you'
                        : 'No patients registered yet',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _searchQuery.isNotEmpty
                    ? 'Try a different name or email.'
                    : _showMyOnly
                        ? 'Switch to "All Patients" to find and assign patients to yourself.'
                        : 'Patients appear here once they register\nand log in to the app.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
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
    final isAssigning = _assigningUserId == patient.userId;

    final age = profile?.age;
    final hasAge = age != null && age > 0;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PatientDetailScreen(patient: patient),
        ),
      ),
      child: Container(
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
                    if (hasAge)
                      Text(
                        '$age y',
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
                  onPressed: (isAssignedElsewhere || isAssigning)
                      ? null
                      : () => _assign(patient),
                  icon: isAssigning
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.accent),
                        )
                      : const Icon(Icons.link, size: 16),
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
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              )
            : Text(
                label,
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
              ),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: content,
    );
  }
}
