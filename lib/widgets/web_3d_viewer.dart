import 'package:flutter/material.dart';
import 'web_3d_viewer_stub.dart'
    if (dart.library.html) 'web_3d_viewer_web.dart';

abstract class Web3DViewer extends StatelessWidget {
  final String? modelUrl;
  final String? frontImage;
  final List<Map<String, dynamic>>? elements;
  final Map<String, List<dynamic>>? productsDatabase;
  final void Function(
    String id,
    String code,
    String name,
    String? model3DUrl,
    double dx,
    double dy,
    double dz,
  )? onApplianceSwapped;

  const Web3DViewer({
    super.key,
    this.modelUrl,
    this.frontImage,
    this.elements,
    this.productsDatabase,
    this.onApplianceSwapped,
  });

  factory Web3DViewer.create({
    String? modelUrl,
    String? frontImage,
    List<Map<String, dynamic>>? elements,
    Map<String, List<dynamic>>? productsDatabase,
    void Function(
      String id,
      String code,
      String name,
      String? model3DUrl,
      double dx,
      double dy,
      double dz,
    )? onApplianceSwapped,
  }) {
    return getWeb3DViewer(
      modelUrl: modelUrl,
      frontImage: frontImage,
      elements: elements,
      productsDatabase: productsDatabase,
      onApplianceSwapped: onApplianceSwapped,
    );
  }
}
