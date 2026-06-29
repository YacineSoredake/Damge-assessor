import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/config/theme.dart';
import '../controllers/history_controller.dart';
import 'widgets/history_list_item.dart';

class HistoryScreen extends GetView<HistoryController> {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scrollController = ScrollController();
    scrollController.addListener(() {
      if (scrollController.position.pixels > scrollController.position.maxScrollExtent - 200) {
        controller.loadMore();
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search by plate number',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: controller.search,
              ),
            ),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (controller.errorMessage.value != null) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(controller.errorMessage.value!, style: const TextStyle(color: AppColors.slate)),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: controller.loadFirstPage, child: const Text('Retry')),
                      ],
                    ),
                  );
                }
                if (controller.items.isEmpty) {
                  return const Center(child: Text('No assessments yet.', style: TextStyle(color: AppColors.slate)));
                }
                return RefreshIndicator(
                  onRefresh: controller.loadFirstPage,
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: controller.items.length + (controller.hasMore.value ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= controller.items.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final item = controller.items[index];
                      return HistoryListItem(item: item, onTap: () => controller.openAssessment(item));
                    },
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}