import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum RiskLevel { low, moderate, high }

extension RiskLevelExtension on RiskLevel {
  String get label {
    switch (this) {
      case RiskLevel.low:
        return 'Low Risk';
      case RiskLevel.moderate:
        return 'Moderate Risk';
      case RiskLevel.high:
        return 'High Risk';
    }
  }

  Color get color {
    switch (this) {
      case RiskLevel.low:
        return AppColors.riskLow;
      case RiskLevel.moderate:
        return AppColors.riskModerate;
      case RiskLevel.high:
        return AppColors.riskHigh;
    }
  }

  Color get backgroundColor {
    switch (this) {
      case RiskLevel.low:
        return AppColors.riskLowBg;
      case RiskLevel.moderate:
        return AppColors.riskModerateBg;
      case RiskLevel.high:
        return AppColors.riskHighBg;
    }
  }

  IconData get icon {
    switch (this) {
      case RiskLevel.low:
        return Icons.check_circle_outline;
      case RiskLevel.moderate:
        return Icons.warning_amber_outlined;
      case RiskLevel.high:
        return Icons.error_outline;
    }
  }

  static RiskLevel fromString(String value) {
    switch (value.toLowerCase()) {
      case 'low':
        return RiskLevel.low;
      case 'moderate':
        return RiskLevel.moderate;
      case 'high':
        return RiskLevel.high;
      default:
        return RiskLevel.low;
    }
  }
}

class Assessment {
  final String id;
  final DateTime timestamp;
  final RiskLevel riskLevel;
  final bool centralLineDetected;
  final List<String> visualFindings;
  final String reasoning;
  final String patientMessage;
  final bool escalate;
  final String? imagePath;

  const Assessment({
    required this.id,
    required this.timestamp,
    required this.riskLevel,
    required this.centralLineDetected,
    required this.visualFindings,
    required this.reasoning,
    required this.patientMessage,
    required this.escalate,
    this.imagePath,
  });

  factory Assessment.fromJson(Map<String, dynamic> json, {String? imagePath}) {
    return Assessment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      riskLevel: RiskLevelExtension.fromString(json['risk_level'] ?? 'low'),
      centralLineDetected: json['central_line_detected'] ?? false,
      visualFindings: List<String>.from(json['visual_findings'] ?? []),
      reasoning: json['reasoning'] ?? '',
      patientMessage: json['patient_message'] ?? '',
      escalate: json['escalate'] ?? false,
      imagePath: imagePath,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'risk_level': riskLevel.name,
        'central_line_detected': centralLineDetected,
        'visual_findings': visualFindings,
        'reasoning': reasoning,
        'patient_message': patientMessage,
        'escalate': escalate,
        'image_path': imagePath,
      };
}
