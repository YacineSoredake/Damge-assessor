import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/config/theme.dart';
import '../controllers/auth_controller.dart';

class LoginScreen extends GetView<AuthController> {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final phoneFieldController = TextEditingController();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Damage Assessor', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Sign in with your phone number to start assessing vehicles.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: phoneFieldController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  hintText: '0X XX XX XX XX',
                  prefixText: '+213 ',
                ),
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
                final isSending = controller.status.value == AuthScreenStatus.sendingOtp;
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isSending
                        ? null
                        : () => controller.sendOtp(phoneFieldController.text),
                    child: isSending
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Send code'),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
