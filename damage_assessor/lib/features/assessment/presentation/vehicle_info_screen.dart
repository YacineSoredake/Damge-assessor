import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/config/theme.dart';
import '../controllers/capture_controller.dart';

class VehicleInfoScreen extends GetView<CaptureController> {
  const VehicleInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final plateController = TextEditingController();
    final makeModelController = TextEditingController();
    final clientRefController = TextEditingController();
    final notesController = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text('New assessment')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Plate number', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(controller: plateController, decoration: const InputDecoration(hintText: 'e.g. 123456-115-16')),
            const SizedBox(height: 16),

            const Text('Make / model (optional)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(controller: makeModelController, decoration: const InputDecoration(hintText: 'e.g. Renault Symbol 2019')),
            const SizedBox(height: 16),

            const Text('Client / policy reference (optional)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(controller: clientRefController),
            const SizedBox(height: 16),

            const Text('Notes (optional)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(controller: notesController, maxLines: 3),
            const SizedBox(height: 20),

            Obx(() {
              final msg = controller.createAssessmentError.value;
              if (msg == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(msg, style: const TextStyle(color: AppColors.red)),
              );
            }),

            Obx(() {
              final loading = controller.isCreatingAssessment.value;
              return SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: loading
                      ? null
                      : () => controller.submitVehicleInfo(
                            plateNumber: plateController.text,
                            vehicleMakeModel: makeModelController.text.trim().isEmpty
                                ? null
                                : makeModelController.text.trim(),
                            clientReference: clientRefController.text.trim().isEmpty
                                ? null
                                : clientRefController.text.trim(),
                            notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                          ),
                  child: loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Continue to capture'),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
