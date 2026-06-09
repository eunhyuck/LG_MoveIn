import 'package:flutter/material.dart';
import 'package:lg_move_in/models/move_in_state.dart';

class ThinQMenuTab extends StatelessWidget {
  final VoidCallback onNavigateToMoveIn;

  const ThinQMenuTab({super.key, required this.onNavigateToMoveIn});

  @override
  Widget build(BuildContext context) {
    final state = MoveInState.instance;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F5F8),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          "LG ThinQ",
          style: TextStyle(
            color: Color(0xFF2B2A27),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Color(0xFF2B2A27)),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Color(0xFF2B2A27)),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Row(
            children: [
              Expanded(
                child: _buildThinQGridCard(
                  icon: Icons.person_outline,
                  iconColor: const Color(0xFF9061F9),
                  title: "마이페이지",
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildThinQGridCard(
                  icon: Icons.headset_mic_outlined,
                  iconColor: const Color(0xFFFF5A5F),
                  title: "고객 지원",
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildChallengeBanner(),
          const SizedBox(height: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  "이사의 모든 순간을 잇는 이사",
                  style: TextStyle(
                    color: Color(0xFF5F5D58),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              InkWell(
                onTap: onNavigateToMoveIn,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF2B2A27), width: 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2B2A27),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.local_shipping, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  "MoveIn · 이사 도우미",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2B2A27),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2B2A27),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    "NEW",
                                    style: TextStyle(
                                      color: Color(0xFFF4F3F0),
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              state.isDDayConfigured
                                  ? "D-${state.moveDate!.difference(DateTime.now()).inDays} 이사 여정이 진행 중입니다"
                                  : "이사 D-Day를 등록하고 맞춤 서비스를 받아보세요",
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF5F5D58)),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Color(0xFF2B2A27)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildMenuSection(
            title: "제품 사용과 관리",
            items: [
              _buildMenuRow(Icons.biotech_outlined, "스마트 진단", const Color(0xFF27AE60)),
              _buildMenuRow(Icons.info_outline, "제품 정보와 보증", const Color(0xFF2F80ED)),
              _buildMenuRow(Icons.description_outlined, "제품 사용설명서", const Color(0xFFE67E22)),
              _buildMenuRow(Icons.subscriptions_outlined, "LG전자 구독", const Color(0xFFE6007E)),
            ],
          ),
          const SizedBox(height: 16),
          _buildMenuSection(
            title: "제품 및 앱 활용",
            items: [
              _buildMenuRow(Icons.play_circle_outline, "ThinQ PLAY", const Color(0xFF9061F9)),
              _buildMenuRow(Icons.schedule, "스마트 루틴", const Color(0xFF27AE60)),
              _buildMenuRow(Icons.explore_outlined, "ThinQ 활용하기", const Color(0xFF2F80ED)),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildThinQGridCard({
    required IconData icon,
    required Color iconColor,
    required String title,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2B2A27),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFFE8F5E9),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text(
              "26°C",
              style: TextStyle(
                color: Color(0xFF1E88E5),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "ThinQ 26°C 챌린지 시즌3",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF2B2A27),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "에어컨 희망 온도를 높이면 선물이 한가득!",
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8A877F),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "~ 2026. 8. 31.",
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8A877F),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection({required String title, required List<Widget> items}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5F5D58),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: List.generate(items.length, (index) {
              if (index == items.length - 1) {
                return items[index];
              }
              return Column(
                children: [
                  items[index],
                  const Divider(height: 1, color: Color(0xFFF4F5F8), indent: 48),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuRow(IconData icon, String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2B2A27),
              ),
            ),
          ),
          const Icon(Icons.chevron_right, color: Color(0xFF8A877F), size: 18),
        ],
      ),
    );
  }
}
