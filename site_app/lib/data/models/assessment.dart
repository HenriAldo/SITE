import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum RiskLevel { undetected, low, moderate, high }

extension RiskLevelExtension on RiskLevel {
  String get label {
    switch (this) {
      case RiskLevel.undetected:
        return 'Not Detected';
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
      case RiskLevel.undetected:
        return AppColors.textSecondary;
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
      case RiskLevel.undetected:
        return AppColors.surface;
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
      case RiskLevel.undetected:
        return Icons.image_search_outlined;
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
      case 'undetected':
        return RiskLevel.undetected;
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
  final String? imageUrl;

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
    this.imageUrl,
  });

  factory Assessment.fromJson(Map<String, dynamic> json, {String? imagePath}) {
    final centralLineDetected = json['central_line_detected'] ?? false;

    // If no central line was detected, override to undetected regardless
    // of what risk_level the model returned
    final riskLevel = centralLineDetected
        ? RiskLevelExtension.fromString(json['risk_level'] ?? 'low')
        : RiskLevel.undetected;

    return Assessment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      riskLevel: riskLevel,
      centralLineDetected: centralLineDetected,
      visualFindings: List<String>.from(json['visual_findings'] ?? []),
      reasoning: json['reasoning'] ?? '',
      patientMessage: json['patient_message'] ?? '',
      escalate: centralLineDetected && (json['escalate'] ?? false),
      imagePath: imagePath,
      imageUrl: json['image_url'] as String?,
    );
  }

  Assessment copyWith({String? imageUrl}) => Assessment(
        id: id,
        timestamp: timestamp,
        riskLevel: riskLevel,
        centralLineDetected: centralLineDetected,
        visualFindings: visualFindings,
        reasoning: reasoning,
        patientMessage: patientMessage,
        escalate: escalate,
        imagePath: imagePath,
        imageUrl: imageUrl ?? this.imageUrl,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'risk_level': riskLevel.name,
        'central_line_detected': centralLineDetected,
        'visual_findings': visualFindings,
        'reasoning': reasoning,
        'patient_message': patientMessage,
        'escalate': escalate,
        'image_path': imagePath,
        'image_url': imageUrl,
      };
}
