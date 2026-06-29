import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/theme.dart';
import '../controllers/auth_controller.dart';

class OtpVerificationScreen extends GetView<AuthController> {
  const OtpVerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final codeFieldController = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text('Verify code')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Obx(() => Text(
                    'Enter the code sent to ${controller.phoneNumber.value}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  )),
              const SizedBox(height: 24),
              TextField(
                controller: codeFieldController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 8),
                decoration: const InputDecoration(counterText: '', hintText: '000000'),
              ),
              const SizedBox(height: 16),
              Obx(() {
                final msg = controller.errorMessage.value;
                if (msg == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(msg, style: const TextStyle(color: AppColors.red)),
                );
              }),
              Obx(() {
                final isVerifying = controller.status.value == AuthScreenStatus.verifying;
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isVerifying
                        ? null
                        : () => controller.verifyOtp(codeFieldController.text),
                    child: isVerifying
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Verify'),
                  ),
                );
              }),
              const SizedBox(height: 16),
              Center(
                child: Obx(() {
                  final cooldown = controller.resendCooldown.value;
                  return TextButton(
                    onPressed: cooldown > 0 ? null : controller.resendOtp,
                    child: Text(cooldown > 0 ? 'Resend in ${cooldown}s' : 'Resend code'),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
