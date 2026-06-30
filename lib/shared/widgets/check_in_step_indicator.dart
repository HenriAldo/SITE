import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class CheckInStepIndicator extends StatelessWidget {
  final int currentStep; // 1 = Photo, 2 = Symptoms, 3 = Result
  final bool photoDone;

  const CheckInStepIndicator({
    super.key,
    required this.currentStep,
    this.photoDone = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _step(1, 'Photo', isCompleted: photoDone || currentStep > 1),
        _line(),
        _step(2, 'Symptoms', isCompleted: currentStep > 2),
        _line(),
        _step(3, 'Result', isCompleted: currentStep > 3),
      ],
    );
  }

  Widget _step(int number, String label,
      {required bool isCompleted}) {
    final isActive = currentStep == number;
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isCompleted
                ? AppColors.accent
                : isActive
                    ? AppColors.accent.withValues(alpha: 0.2)
                    : AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive || isCompleted
                  ? AppColors.accent
                  : AppColors.cardBorder,
            ),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text(
                    '$number',
                    style: TextStyle(
                      color:
                          isActive ? AppColors.accent : AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isActive ? AppColors.accent : AppColors.textSecondary,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _line() {
    return Expanded(
      child: Container(
        height: 1,
        margin: const EdgeInsets.only(bottom: 20, left: 4, right: 4),
        color: AppColors.divider,
      ),
    );
  }
}
