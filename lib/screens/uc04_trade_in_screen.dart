import 'dart:async';
import 'package:flutter/material.dart';

class UC04TradeInScreen extends StatefulWidget {
  const UC04TradeInScreen({super.key});

  @override
  State<UC04TradeInScreen> createState() => _UC04TradeInScreenState();
}

class _UC04TradeInScreenState extends State<UC04TradeInScreen> {
  int _step = 0;
  bool _isAnalyzing = false;
  String _detectedAppliance = "냉장고 · LG전자";
  String _modelNumber = "S833SS35 (추정)";
  String _purchaseYear = "2021년";
  String _status = "A급 (작동양호, 외관우수)";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI 트레이드인 (UC-04)"),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2B2A27),
        elevation: 0,
      ),
      body: _buildTradeInContent(),
    );
  }

  Widget _buildTradeInContent() {
    if (_isAnalyzing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFFE6007E)),
            SizedBox(height: 20),
            Text("✦ 기존 가전 사진 판독 중...", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text("AI가 브랜드, 상태 및 시세 데이터를 매칭하고 있습니다.", style: TextStyle(color: Color(0xFF8A877F), fontSize: 12)),
          ],
        ),
      );
    }

    switch (_step) {
      case 0:
        return _buildStepCapture();
      case 1:
        return _buildStepResultCheck();
      case 2:
        return _buildStepQuoteChart();
      default:
        return Container();
    }
  }

  Widget _buildStepCapture() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.photo_camera_outlined, size: 80, color: Color(0xFF2B2A27)),
          const SizedBox(height: 24),
          const Text("처분할 가전을 촬영해 주세요", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text(
            "사진 한 장이면 AI가 가전 모델명과 상태를 인지해\n중고 시세와 최적 처분 방식을 추천합니다.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF5F5D58), fontSize: 13),
          ),
          const SizedBox(height: 40),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _isAnalyzing = true);
                    Timer(const Duration(seconds: 2), () {
                      setState(() {
                        _isAnalyzing = false;
                        _step = 1;
                      });
                    });
                  },
                  icon: const Icon(Icons.camera_alt),
                  label: const Text("사진 촬영 / 업로드"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2B2A27),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepResultCheck() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("✦ AI 분석 결과 확인 (1/2)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFE6007E))),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                _buildEditableInfoRow("제품군 / 브랜드", _detectedAppliance, (val) => _detectedAppliance = val),
                _buildEditableInfoRow("모델명", _modelNumber, (val) => _modelNumber = val),
                _buildEditableInfoRow("구매 연도", _purchaseYear, (val) => _purchaseYear = val),
                _buildEditableInfoRow("보완 상태", _status, (val) => _status = val),
              ],
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => setState(() => _step = 2),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2B2A27),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("예상 중고 시세 확인하기", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepQuoteChart() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("예상 시세 및 처분 방식 (2/2)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2B2A27)),
              ),
              child: const Column(
                children: [
                  Text("예상 중고 매입 시세", style: TextStyle(color: Color(0xFF5F5D58), fontSize: 13)),
                  SizedBox(height: 8),
                  Text("28만원 ~ 34만원", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2B2A27))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text("✦ 시세 분포 그래프 (유사 거래 기준)", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: CustomPaint(
                size: Size.infinite,
                painter: PriceChartPainter(),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("폐가전 무료수거가 예약되었습니다.")),
                    );
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2B2A27),
                    side: const BorderSide(color: Color(0xFF2B2A27)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("무료 수거 신청"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("LG전자 트레이드인(보상판매) 신청이 완료되었습니다.")),
                    );
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE6007E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("트레이드인 신청"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditableInfoRow(String title, String val, Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5F5D58))),
          Text(val, style: const TextStyle(color: Color(0xFF2B2A27))),
        ],
      ),
    );
  }
}

class PriceChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE6007E)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = const Color(0xFFE6007E).withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height * 0.8);
    path.quadraticBezierTo(size.width * 0.25, size.height * 0.6, size.width * 0.5, size.height * 0.2);
    path.quadraticBezierTo(size.width * 0.75, size.height * 0.6, size.width, size.height * 0.85);

    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    final pX = size.width * 0.5;
    final pY = size.height * 0.2;
    canvas.drawCircle(Offset(pX, pY), 6, Paint()..color = const Color(0xFF2B2A27));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
