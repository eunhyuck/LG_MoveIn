import 'package:flutter/material.dart';
import 'web_3d_viewer_stub.dart'
    if (dart.library.html) 'web_3d_viewer_web.dart';

abstract class Web3DViewer extends StatelessWidget {
  final String? modelUrl;
  final String? frontImage;
  final List<Map<String, dynamic>>? elements;

  const Web3DViewer({
    super.key,
    this.modelUrl,
    this.frontImage,
    this.elements,
  });

  factory Web3DViewer.create({
    String? modelUrl,
    String? frontImage,
    List<Map<String, dynamic>>? elements,
  }) {
    return getWeb3DViewer(modelUrl: modelUrl, frontImage: frontImage, elements: elements);
  }
}
