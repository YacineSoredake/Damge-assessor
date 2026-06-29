import 'package:flutter/material.dart';
import '../../../../core/config/theme.dart';
import '../../data/models/photo_model.dart';

class CaptureProgressBar extends StatelessWidget {
  final Map<PhotoType, CapturedPhoto> capturedAngles;
  const CaptureProgressBar({super.key, required this.capturedAngles});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: requiredAngleSteps.map((step) {
        final done = capturedAngles.containsKey(step);
        return Expanded(
          child: Column(
            children: [
              Icon(
                done ? Icons.check_circle : Icons.radio_button_unchecked,
                color: done ? AppColors.green : Colors.white70,
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                step.label,
                style: const TextStyle(color: Colors.white, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
