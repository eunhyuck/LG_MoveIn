import 'package:flutter/material.dart';
import 'web_3d_viewer.dart';

class Web3DViewerStub extends Web3DViewer {
  const Web3DViewerStub({super.key, super.modelUrl, super.frontImage, super.elements});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('3D Preview is only available on Web/Mobile Webview.'),
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
