import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LgTradeInScreen extends StatelessWidget {
  final String productName;
  final String category;
  final String modelCode;
  final int estimatedPrice;

  const LgTradeInScreen({
    super.key,
    required this.productName,
    required this.category,
    required this.modelCode,
    required this.estimatedPrice,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3EE),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1918),
        foregroundColor: Colors.white,
        title: const Text('LG 트레이드인', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더 배너
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE6007E), Color(0xFFAD005E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 36),
                  const SizedBox(height: 12),
                  const Text(
                    'LG 트레이드인',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '헌 가전을 반납하고 LG 신제품으로\n중고 보상가 + 추가 보상 최대 10만원',
                    style: TextStyle(color: Color(0xFFFFCCE8), fontSize: 14, height: 1.6),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '이벤트 기간: 2026년 상반기 (예정)',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 내 제품 요약
            _sectionTitle('내 보상 제품'),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE0DED8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (productName.isNotEmpty)
                    _specRow('제품명', productName),
                  if (category.isNotEmpty)
                    _specRow('카테고리', category),
                  if (modelCode.isNotEmpty)
                    _specRow('모델코드', modelCode),
                  _specRow(
                    '예상 중고 보상가',
                    estimatedPrice > 0 ? '${_fmt(estimatedPrice)}원' : '감정 필요',
                    highlight: true,
                  ),
                  _specRow('추가 보상', '최대 100,000원', highlight: true),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 혜택 안내
            _sectionTitle('트레이드인 혜택'),
            const SizedBox(height: 12),
            ...[
              (Icons.attach_money_rounded, '중고 보상가 지급', '현재 중고 시세 기준으로 보상가를 산정합니다.'),
              (Icons.redeem_rounded, '추가 보상 최대 10만원', 'LG 신제품 구매 시 추가 바우처를 지급합니다.'),
              (Icons.local_shipping_rounded, '무료 수거·배송', '방문 수거 후 신제품 배달까지 한 번에 처리합니다.'),
              (Icons.eco_rounded, '친환경 폐가전 처리', '환경부 인증 방식으로 안전하게 폐기합니다.'),
            ].map((item) => _benefitTile(item.$1, item.$2, item.$3)),

            const SizedBox(height: 24),

            // 진행 절차
            _sectionTitle('신청 절차'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE0DED8)),
              ),
              child: Column(
                children: [
                  _stepRow('1', '온라인 신청', '제품 정보 입력 및 예상 보상가 확인'),
                  _stepDivider(),
                  _stepRow('2', '방문 감정', 'LG 전문가가 방문하여 최종 보상가 확정'),
                  _stepDivider(),
                  _stepRow('3', '헌 제품 수거', '기존 가전을 무료로 수거합니다'),
                  _stepDivider(),
                  _stepRow('4', '신제품 구매', '보상금 + 추가 바우처로 LG 신제품 구매'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 주의사항
            _sectionTitle('유의사항'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFE082)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• 본 서비스는 LG전자 이벤트 기간에만 운영됩니다.', style: TextStyle(fontSize: 12, height: 1.7, color: Color(0xFF5D4037))),
                  Text('• 보상가는 방문 감정 후 최종 확정되며 예상가와 다를 수 있습니다.', style: TextStyle(fontSize: 12, height: 1.7, color: Color(0xFF5D4037))),
                  Text('• 제품 상태(파손, 침수 등)에 따라 보상이 제한될 수 있습니다.', style: TextStyle(fontSize: 12, height: 1.7, color: Color(0xFF5D4037))),
                  Text('• 추가 보상 바우처는 LG전자 공식몰에서만 사용 가능합니다.', style: TextStyle(fontSize: 12, height: 1.7, color: Color(0xFF5D4037))),
                ],
              ),
            ),

            const SizedBox(height: 120),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F3EE),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 신청 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final uri = Uri.parse('https://www.lge.co.kr/event');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('LG 트레이드인 신청하기', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE6007E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2B2A27),
                  side: const BorderSide(color: Color(0xFFCCCAC4)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('돌아가기', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
    title,
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1918)),
  );

  Widget _specRow(String label, String value, {bool highlight = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF8A877F))),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
              color: highlight ? const Color(0xFFE6007E) : const Color(0xFF2B2A27),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _benefitTile(IconData icon, String title, String desc) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE0DED8)),
    ),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFFCE4F0),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFFE6007E), size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 2),
              Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xFF8A877F), height: 1.4)),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _stepRow(String num, String title, String desc) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: Color(0xFFE6007E),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(num, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 2),
            Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xFF8A877F))),
          ],
        ),
      ),
    ],
  );

  Widget _stepDivider() => Padding(
    padding: const EdgeInsets.only(left: 13, top: 4, bottom: 4),
    child: Container(width: 2, height: 20, color: const Color(0xFFE0DED8)),
  );

  String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
