import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'web_3d_viewer.dart';

class Web3DViewerStub extends Web3DViewer {
  const Web3DViewerStub({super.key, super.modelUrl, super.frontImage, super.elements});

  @override
  Widget build(BuildContext context) {
    if (elements != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF0F5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.layers_clear_rounded,
                  size: 48,
                  color: Color(0xFFE6007E),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '3D 전체 배치도 입체 뷰어',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2B2A27),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '전체 배치도 3D 및 1인칭(FPS) 탐색 기능은 Web 환경에 최적화되어 있습니다. 모바일 앱에서는 개별 가전 3D 상세보기를 이용해 주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF5F5D58),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final resolvedUrl = modelUrl ?? 'assets/models/haier_refrigerator.glb';
    return ModelViewer(
      backgroundColor: const Color(0xFFF8F9FC),
      src: resolvedUrl,
      alt: "LG Appliance 3D model",
      ar: false,
      autoRotate: true,
      cameraControls: true,
    );
  }
}

Web3DViewer getWeb3DViewer({
  String? modelUrl,
  String? frontImage,
  List<Map<String, dynamic>>? elements,
}) {
  return Web3DViewerStub(modelUrl: modelUrl, frontImage: frontImage, elements: elements);
}

