import 'dart:async';
import 'package:flutter/material.dart';

class UC05SafeReportScreen extends StatefulWidget {
  const UC05SafeReportScreen({super.key});

  @override
  State<UC05SafeReportScreen> createState() => _UC05SafeReportScreenState();
}

class _UC05SafeReportScreenState extends State<UC05SafeReportScreen> {
  int _step = 0;
  bool _isScanning = false;
  bool _livingRoomUploaded = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("안심 리포트 (UC-05)"),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2B2A27),
        elevation: 0,
      ),
      body: _buildSafeReportBody(),
    );
  }

  Widget _buildSafeReportBody() {
    if (_isScanning) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFFE6007E)),
            SizedBox(height: 20),
            Text("✦ 이미지 전/후 대조 분석 중...", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text("픽셀 단위 정밀 분석으로 스크래치 및 하자 의심 영역을 식별 중입니다.", style: TextStyle(color: Color(0xFF8A877F), fontSize: 12), textAlign: TextAlign.center),
          ],
        ),
      );
    }
    switch (_step) {
      case 0:
        return _buildStepPreMove();
      case 1:
        return _buildStepPostMoveGuide();
      case 2:
        return _buildStepAnalysisReport();
      default:
        return Container();
    }
  }

  Widget _buildStepPreMove() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("이사 전 상태 기록", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("주요 공간의 이사 전 사진을 저장해 두시면, 이사 후 생기는 스크래치 분쟁을 예방할 수 있어요.", style: TextStyle(color: Color(0xFF8A877F), fontSize: 13)),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildPhotoCard("거실 벽면", _livingRoomUploaded, () {
                  setState(() => _livingRoomUploaded = true);
                }),
                _buildPhotoCard("다용도실 타일", false, null),
                _buildPhotoCard("현관 도어", false, null),
                _buildPhotoCard("주방 아일랜드 식탁", false, null),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _livingRoomUploaded ? () => setState(() => _step = 1) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2B2A27),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("이사 전 상태 기록 완료", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoCard(String name, bool isUploaded, VoidCallback? onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E4E8)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isUploaded ? Icons.check_circle : Icons.add_a_photo_outlined,
              color: isUploaded ? const Color(0xFF27AE60) : const Color(0xFF8A877F),
              size: 36,
            ),
            const SizedBox(height: 12),
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            Text(isUploaded ? "촬영완료" : "촬영하기", style: const TextStyle(fontSize: 11, color: Color(0xFF8A877F))),
          ],
        ),
      ),
    );
  }

  Widget _buildStepPostMoveGuide() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("이사 후 매칭 촬영", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("이전 사진의 반투명 가이드를 활용해 같은 각도와 앵글로 촬영해 주세요.", style: TextStyle(color: Color(0xFF8A877F), fontSize: 13)),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: 0.3,
                    child: Container(
                      padding: const EdgeInsets.all(30),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.crop_original, size: 80, color: Color(0xFF2B2A27)),
                          Text("이사 전 촬영된 앵글 가이드라인"),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() => _isScanning = true);
                        Timer(const Duration(seconds: 3), () {
                          setState(() {
                            _isScanning = false;
                            _step = 2;
                          });
                        });
                      },
                      icon: const Icon(Icons.camera_alt),
                      label: const Text("매칭 사진 찍기"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE6007E),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepAnalysisReport() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("✦ 이사 후 안심 리포트 완료", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text("하자 위험도 점수", style: TextStyle(color: Color(0xFF8A877F))),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFECEC),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        "72점 (주의)",
                        style: TextStyle(color: Color(0xFFFF5A5F), fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text("총 3곳의 미세 스크래치 및 하자가 감지되었습니다.", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text("확인 체크리스트", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildCheckItem("거실 하부 몰딩 긁힘 의심 (일치율 94%)"),
          _buildCheckItem("문고리 주변 도장 파손 (일치율 88%)"),
          _buildCheckItem("다용도실 바닥 타일 미세 실금 (일치율 76%)"),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("LG전자 서비스센터 AS 접수로 연결되었습니다.")),
                    );
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE6007E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("AS 접수 및 케어 서비스 신청"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCheckItem(String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF5A5F), size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
