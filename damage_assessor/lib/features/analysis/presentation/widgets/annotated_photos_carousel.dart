import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../core/config/theme.dart';
import '../../data/models/result_model.dart';

class AnnotatedPhotosCarousel extends StatelessWidget {
  final List<AnalyzedPhoto> photos;
  const AnnotatedPhotosCarousel({super.key, required this.photos});

  @override
  Widget build(BuildContext context) {
    final withImages = photos.where((p) => p.annotatedImageBase64 != null).toList();
    if (withImages.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: withImages.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final photo = withImages[index];
          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                Image.memory(
                  base64Decode(photo.annotatedImageBase64!),
                  width: 200,
                  height: 160,
                  fit: BoxFit.cover,
                ),
                if (photo.angle != null)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: Colors.black54,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        photo.angle!.replaceAll('_', ' ').toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
