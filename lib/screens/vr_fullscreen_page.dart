import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/vr_room_viewer_stub.dart';

class VRFullScreenPage extends StatefulWidget {
  final List<Map<String, dynamic>> elements;
  final Map<String, List<dynamic>>? productsDatabase;

  const VRFullScreenPage({
    super.key,
    required this.elements,
    this.productsDatabase,
  });

  @override
  State<VRFullScreenPage> createState() => _VRFullScreenPageState();
}

class _VRFullScreenPageState extends State<VRFullScreenPage> {
  @override
  void initState() {
    super.initState();
    // 전체화면 (상/하단 네비게이션 및 노티 바 숨김) 및 가로 모드 강제 설정
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    // 세로 모드 복구 및 시스템 UI 정상 복구
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 3D VR 뷰어 (전체화면)
          Positioned.fill(
            child: VRRoomViewer(
              elements: widget.elements,
              productsDatabase: widget.productsDatabase,
            ),
          ),

          // 반투명 플로팅 뒤로가기/닫기 버튼 (VR 헤드셋 탈착 후 복구용)
          Positioned(
            top: 16,
            left: 16,
            child: SafeArea(
              child: ClipOval(
                child: Material(
                  color: Colors.black.withOpacity(0.5), // 반투명 검정 배경
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
