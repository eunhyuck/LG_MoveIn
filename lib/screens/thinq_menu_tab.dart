import 'package:flutter/material.dart';
import 'package:lg_move_in/models/move_in_state.dart';

class ThinQMenuTab extends StatelessWidget {
  final VoidCallback onNavigateToMoveIn;

  const ThinQMenuTab({super.key, required this.onNavigateToMoveIn});

  @override
  Widget build(BuildContext context) {
    final state = MoveInState.instance;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FB),
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
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFFFFFF),
                        Color(0xFFFCFBF8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFE2E4E8).withValues(alpha: 0.5),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 16,
                        spreadRadius: -2,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Decorative dots pattern on the right
                      Positioned(
                        right: -8,
                        top: -8,
                        child: _buildDecorativeDots(),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFFF06292),
                                  Color(0xFFE91E63),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFE91E63).withValues(alpha: 0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
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
                                        color: Color(0xFF1A1A1E),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE6007E),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Text(
                                        "NEW",
                                        style: TextStyle(
                                          color: Colors.white,
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

  /// Decorative dots pattern used in the MoveIn banner
  Widget _buildDecorativeDots() {
    return SizedBox(
      width: 60,
      height: 60,
      child: CustomPaint(
        painter: _DotPatternPainter(),
      ),
    );
  }

  Widget _buildThinQGridCard({
    required IconData icon,
    required Color iconColor,
    required String title,
  }) {
    // Determine gradient colors based on iconColor
    final bool isPurple = iconColor == const Color(0xFF9061F9);
    final List<Color> gradientColors = isPurple
        ? const [Color(0xFFFFFFFF), Color(0xFFF8F4FF), Color(0xFFF3EEFF)]
        : const [Color(0xFFFFFFFF), Color(0xFFFFF5F5), Color(0xFFFFEEEE)];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0x08000000),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 32),
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
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE8F8F5),
            Color(0xFFE3F2FD),
            Color(0xFFE0F7FA),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0A000000),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative leaf icon in top-right
          Positioned(
            right: -4,
            top: -4,
            child: Icon(
              Icons.eco_outlined,
              size: 36,
              color: const Color(0x1527AE60),
            ),
          ),
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF42A5F5),
                      Color(0xFF26C6DA),
                      Color(0xFF66BB6A),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x3342A5F5),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Text(
                  "26°C",
                  style: TextStyle(
                    color: Colors.white,
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
                        color: Color(0xFF6B6860),
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
            boxShadow: [
              BoxShadow(
                color: const Color(0x06000000),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: List.generate(items.length, (index) {
              if (index == items.length - 1) {
                return items[index];
              }
              return Column(
                children: [
                  items[index],
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      height: 1,
                      margin: const EdgeInsets.only(left: 32),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F0F0),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
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
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Subtle left accent line
            Container(
              width: 3,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: color.withAlpha(50),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(2),
                  bottomRight: Radius.circular(2),
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 16, top: 14, bottom: 14),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// CustomPainter that draws a subtle dot pattern
class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x15C9A032)
      ..style = PaintingStyle.fill;

    const spacing = 14.0;
    const radius = 2.5;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
