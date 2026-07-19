import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  static const List<(String, String)> _faqs = [
    (
      'What is a CLABSI?',
      'CLABSI stands for Central Line-Associated Bloodstream Infection. It occurs when bacteria enter the bloodstream through a central venous catheter. It is a serious but preventable complication that can be treated effectively when caught early.'
    ),
    (
      'What are early signs of a catheter site infection?',
      'Early signs include redness around the insertion site, swelling, warmth, pain or tenderness, and cloudy or unusual discharge (pus). Fever or chills can also indicate that bacteria have entered the bloodstream.'
    ),
    (
      'When should I go to the emergency room immediately?',
      'Go to the ER immediately if you experience fever above 38°C (100.4°F), severe chills or shaking, confusion, persistent lightheadedness, rapid heartbeat or difficulty breathing. These may indicate a bloodstream infection that requires urgent treatment. Do not wait for your next check-in.'
    ),
    (
      'How often should I do a check-in?',
      'You should complete a daily check-in once per day, ideally at the same time each morning. Consistent daily monitoring gives the AI the best chance of detecting changes early.'
    ),
    (
      'What if I\'m worried but the app says low or moderate risk?',
      'Trust your own judgment. The AI assessment does not override how you feel. If you notice new or worsening symptoms, feel unwell, or are simply concerned, contact your care team or seek emergency care regardless of what the app shows — the result is a support tool, not the final word.'
    ),
    (
      'What does "Low Risk" mean for me?',
      'Low risk means the AI did not detect signs of concern in this check-in. No action is needed beyond continuing your daily monitoring. This does not mean you are free of risk between check-ins — keep watching for new symptoms and contact your care team if anything changes.'
    ),
    (
      'What does "High Risk" mean for me?',
      'High risk means the AI detected findings consistent with a possible infection that need prompt review by your care team. If you develop fever, chills, or feel unwell before hearing from them, do not wait — go to the ER or contact your care team directly.'
    ),
    (
      'Does SITE monitor for anything other than infection?',
      'No. SITE only monitors your catheter exit site for signs of infection. It does NOT detect catheter blockage, dislodgement, or blood clots. If you notice arm or neck swelling, resistance or pain during flushing, leakage, or the catheter looking longer or shorter than usual, contact your care team right away — these are not things this app evaluates.'
    ),
    (
      'What if I cannot see the insertion site clearly?',
      'If the dressing is covering the insertion site or the photo is unclear, the app will ask you to retake it. Do not remove or change the dressing yourself — only a trained nurse should change catheter dressings. If there is no transparent dressing available, the AI will not work properly, and you should contact your care team for guidance.'
    ),
    (
      'What does "Moderate Risk" mean for me?',
      'This finding alone doesn\'t require emergency care. But this assessment doesn\'t override new or worsening symptoms — if you develop fever, chills, spreading redness, or just feel unwell, contact your care team or go to the ER regardless of this result.'
    ),
    (
      'What happens when my case is escalated?',
      'When a moderate or high risk is detected, your case is sent to a clinician dashboard where your care team can review the image in combination with your symptoms and perform an assessment. They will decide on the appropriate next step — this could range from watchful waiting to requesting an in-person evaluation.'
    ),
    (
      'Can I shower or bathe with a central line?',
      'Generally yes, but the catheter and dressing must stay dry. Use waterproof dressing covers and avoid submerging the site. Always follow the specific instructions given by your care team, as guidance may differ depending on your catheter type.'
    ),
    (
      'What should I do if my dressing comes loose?',
      'If your dressing becomes loose, wet, or visibly dirty, contact your care team as soon as possible. Do not attempt to reapply it yourself. A loose dressing increases infection risk and should be changed by a trained nurse promptly.'
    ),
    (
      'Is SITE a replacement for medical care?',
      'No. SITE is a monitoring support tool only. It helps you and your care team detect early changes but does not replace clinical judgment or in-person medical care. Always follow the advice of your treating physician.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FAQ')),
      body: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: _faqs.length,
        itemBuilder: (context, i) {
          final faq = _faqs[i];
          return _FaqTile(question: faq.$1, answer: faq.$2);
        },
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  final String question;
  final String answer;

  const _FaqTile({required this.question, required this.answer});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _expanded
              ? AppColors.accentDark.withValues(alpha: 0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _expanded
                ? AppColors.accentDark.withValues(alpha: 0.4)
                : AppColors.cardBorder,
          ),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _expanded
                            ? AppColors.accentDark
                            : AppColors.accentDark.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          'Q',
                          style: TextStyle(
                            color: _expanded
                                ? Colors.white
                                : AppColors.accentDark,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.question,
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: _expanded
                                      ? AppColors.textPrimary
                                      : AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: _expanded
                            ? AppColors.accentDark
                            : AppColors.textSecondary,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded)
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: AppColors.accentDark.withValues(alpha: 0.3)),
                      ),
                      child: const Center(
                        child: Text(
                          'A',
                          style: TextStyle(
                            color: AppColors.accentDark,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.answer,
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  height: 1.6,
                                  color: AppColors.textSecondary,
                                ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
