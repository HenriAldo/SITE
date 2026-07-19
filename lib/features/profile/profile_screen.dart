import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_controller.dart';
import '../../data/models/patient_profile.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/firestore_service.dart';
import 'care_team_screen.dart';
import 'faq_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? get _user => FirebaseAuth.instance.currentUser;
  bool _sendingVerification = false;

  @override
  void initState() {
    super.initState();
    _refreshVerificationStatus();
  }

  // Picks up the verified flag if the user already clicked the email link
  // before returning to the app.
  Future<void> _refreshVerificationStatus() async {
    await FirebaseAuth.instance.currentUser?.reload();
    if (mounted) setState(() {});
  }

  Future<void> _resendVerification(BuildContext context) async {
    setState(() => _sendingVerification = true);
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email sent.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send verification email. Try again later.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingVerification = false);
    }
  }

  Future<void> _editName(BuildContext context) async {
    final controller = TextEditingController(text: _user?.displayName ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Your name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Enter your name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _user?.updateDisplayName(result);
      // The clinician's patient list reads users/{uid}.display_name in
      // Firestore, not Firebase Auth's own displayName — keep both in sync
      // so patients are identified by name rather than falling back to email.
      if (_user != null) {
        await FirestoreService().updateDisplayName(_user!.uid, result);
      }
      // Reload user so displayName is fresh
      await FirebaseAuth.instance.currentUser?.reload();
      if (mounted) setState(() {});
    }
  }


  @override
  Widget build(BuildContext context) {
    final user = _user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController.instance,
            builder: (context, mode, _) {
              final isDark = mode != ThemeMode.light;
              return IconButton(
                icon: Icon(
                    isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
                tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
                onPressed: () => ThemeController.instance
                    .setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<PatientProfile?>(
        future: user == null
            ? Future.value(null)
            : FirestoreService().getProfile(user.uid),
        builder: (context, snapshot) {
          final profile = snapshot.data;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAccountCard(context, user),
                if (user != null && !user.emailVerified) ...[
                  const SizedBox(height: 12),
                  _buildVerifyEmailBanner(context),
                ],
                const SizedBox(height: 20),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(color: AppColors.accent),
                    ),
                  )
                else if (profile != null) ...[
                  _buildCatheterCard(context, profile),
                  const SizedBox(height: 20),
                  _buildClinicalCard(context, profile),
                ] else ...[
                  _buildNoProfileCard(context, profile),
                ],
                if (snapshot.connectionState != ConnectionState.waiting &&
                    user != null) ...[
                  const SizedBox(height: 20),
                  _buildCareTeamCard(context, user),
                ],
                const SizedBox(height: 20),
                _buildFaqSection(context),
                const SizedBox(height: 28),
                _buildSignOutButton(context),
                const SizedBox(height: 16),
                _buildDisclaimer(context),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Account ───────────────────────────────────────────────────

  Widget _buildAccountCard(BuildContext context, User? user) {
    final hasName = user?.displayName != null && user!.displayName!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_outline,
                color: AppColors.accent, size: 28),
          ),
          const SizedBox(width: 16),
          // Whole name + email block opens the name editor.
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _editName(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          hasName ? user.displayName! : 'Add your name',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: hasName
                                        ? AppColors.textPrimary
                                        : AppColors.textSecondary,
                                    fontStyle: hasName
                                        ? FontStyle.normal
                                        : FontStyle.italic,
                                  ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.edit_outlined,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user?.email ?? '—',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifyEmailBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.riskModerateBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.riskModerate.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.mark_email_unread_outlined,
              color: AppColors.riskModerate, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Please verify your email address.',
              style: TextStyle(
                color: AppColors.riskModerate.withValues(alpha: 0.9),
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            onPressed: _sendingVerification
                ? null
                : () => _resendVerification(context),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.riskModerate, padding: EdgeInsets.zero),
            child: _sendingVerification
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.riskModerate),
                  )
                : const Text('Resend', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ── Catheter ──────────────────────────────────────────────────

  Widget _buildCatheterCard(BuildContext context, PatientProfile profile) {
    final insertedDate =
        DateFormat('d MMMM yyyy').format(profile.insertionDate);

    return _sectionCard(
      context,
      title: 'Catheter',
      icon: Icons.medical_services_outlined,
      children: [
        _row(context, 'Type', profile.catheterType),
        _row(context, 'Inserted', insertedDate),
        _row(context, 'Days in place', '${profile.daysSinceInsertion} days'),
      ],
    );
  }

  // ── Clinical Context ──────────────────────────────────────────

  Widget _buildClinicalCard(BuildContext context, PatientProfile profile) {
    return _sectionCard(
      context,
      title: 'Clinical Context',
      icon: Icons.local_hospital_outlined,
      children: [
        if (profile.diagnosis.isNotEmpty)
          _row(context, 'Diagnosis', profile.diagnosis),
        if (profile.age > 0)
          _row(context, 'Age', '${profile.age}'),
        _row(
          context,
          'Immunosuppressed',
          profile.isImmunosuppressed ? 'Yes' : 'No',
          valueColor: profile.isImmunosuppressed
              ? AppColors.riskModerate
              : AppColors.textPrimary,
        ),
        if (profile.comorbidities.isNotEmpty)
          _row(context, 'Comorbidities', profile.comorbidities.join(', ')),
      ],
    );
  }

  // ── Care Team ─────────────────────────────────────────────────

  Widget _buildCareTeamCard(BuildContext context, User user) {
    return FutureBuilder<ClinicianContact?>(
      future: _fetchClinicianContact(user.uid),
      builder: (context, snapshot) {
        final team = snapshot.data;
        final hasTeam = team != null && !team.isEmpty;

        return _sectionCard(
          context,
          title: 'Care Team',
          icon: Icons.groups_outlined,
          children: hasTeam
              ? [
                  if (team.clinicianName.isNotEmpty)
                    _row(context, 'Physician', team.clinicianName),
                  if (team.phone.isNotEmpty)
                    _row(context, 'Phone', team.phone),
                  if (team.clinic.isNotEmpty)
                    _row(context, 'Clinic', team.clinic),
                ]
              : [
                  Text(
                    'Your clinician hasn\'t added their contact details yet.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
        );
      },
    );
  }

  Future<ClinicianContact?> _fetchClinicianContact(String userId) async {
    final clinicianId =
        await FirestoreService().getAssignedClinicianId(userId);
    if (clinicianId == null) return null;
    return FirestoreService().getClinicianContact(clinicianId);
  }

  Widget _buildNoProfileCard(BuildContext context, PatientProfile? profile) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Icon(Icons.info_outline,
              color: AppColors.textSecondary, size: 32),
          const SizedBox(height: 12),
          Text(
            'No clinical profile set up yet.',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your care team will set up your clinical profile at catheter insertion.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  // ── Support ───────────────────────────────────────────────────

  Widget _buildFaqSection(BuildContext context) {
    return _sectionCard(
      context,
      title: 'Help & Support',
      icon: Icons.help_outline,
      children: [
        _actionRow(
          context,
          icon: Icons.groups_outlined,
          label: 'Contact your care team',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CareTeamScreen()),
          ),
        ),
        _actionRow(
          context,
          icon: Icons.quiz_outlined,
          label: 'Frequently asked questions',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FaqScreen()),
          ),
        ),
      ],
    );
  }

  // ── Sign Out ──────────────────────────────────────────────────

  Widget _buildSignOutButton(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _confirmSignOut(context),
      icon: const Icon(Icons.logout_outlined, size: 18),
      label: const Text('Sign Out'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        side: BorderSide(color: AppColors.cardBorder),
      ),
    );
  }

  Widget _buildDisclaimer(BuildContext context) {
    return Text(
      'SITE is a monitoring support tool only and does not replace clinical judgment.',
      textAlign: TextAlign.center,
      style: Theme.of(context)
          .textTheme
          .bodyMedium
          ?.copyWith(fontSize: 11),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────

  Widget _sectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
    VoidCallback? onEdit,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    title, style: Theme.of(context).textTheme.titleMedium),
              ),
              if (onEdit != null)
                GestureDetector(
                  onTap: onEdit,
                  child: Icon(Icons.edit_outlined,
                      size: 16, color: AppColors.textSecondary),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: GestureDetector(
              onLongPress: () => _copyToClipboard(context, value),
              child: Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: valueColor ?? AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    HapticFeedback.mediumImpact();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  Widget _actionRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color ?? AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: color ?? AppColors.textPrimary,
                    ),
              ),
            ),
            Icon(Icons.chevron_right,
                size: 18, color: color ?? AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to sign in again to continue monitoring your catheter site.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.riskHigh,
            ),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      // Pop all routes so AuthGate is exposed and can rebuild to LoginScreen
      if (context.mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      await AuthService().signOut();
    }
  }
}
