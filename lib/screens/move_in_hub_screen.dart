import 'package:flutter/material.dart';
import 'package:lg_move_in/models/move_in_state.dart';
import 'package:lg_move_in/screens/uc02_schedule_screen.dart';
import 'package:lg_move_in/screens/uc03_room_planner_screen.dart';
import 'package:lg_move_in/screens/uc04_trade_in_screen.dart';
import 'package:lg_move_in/screens/uc05_safe_report_screen.dart';
import 'package:lg_move_in/screens/uc06_settlement_screen.dart';
import 'package:lg_move_in/screens/uc07_community_screen.dart';

class MoveInHubScreen extends StatefulWidget {
  const MoveInHubScreen({super.key});

  @override
  State<MoveInHubScreen> createState() => _MoveInHubScreenState();
}

class _MoveInHubScreenState extends State<MoveInHubScreen> {
  final state = MoveInState.instance;

  @override
  Widget build(BuildContext context) {
    int dDay = 0;
    if (state.moveDate != null) {
      dDay = state.moveDate!.difference(DateTime.now()).inDays;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("MoveIn · 이사 여정 허브"),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: const Color(0xFF2B2A27),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── D-Day Hero Card ──
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF131316), Color(0xFF2B2B33)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE6007E).withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Violet glow aura top-right
                  Positioned(
                    top: -40,
                    right: -20,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF7C4DFF).withValues(alpha: 0.2),
                            const Color(0xFF7C4DFF).withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Pink glow aura bottom-right
                  Positioned(
                    bottom: -40,
                    right: -40,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFE6007E).withValues(alpha: 0.25),
                            const Color(0xFFE6007E).withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Main content
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              state.isDDayConfigured ? "MY MOVING DASHBOARD" : "이사 일정 미등록",
                              style: const TextStyle(
                                color: Color(0xFF8A877F),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            if (state.isDDayConfigured)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE6007E).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFE6007E).withValues(alpha: 0.3),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  state.moveType,
                                  style: const TextStyle(
                                    color: Color(0xFFE6007E),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (state.isDDayConfigured)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                dDay == 0 ? "D - DAY" : "D - ",
                                style: const TextStyle(
                                  color: Color(0xFFE6007E),
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              if (dDay != 0)
                                Text(
                                  "${dDay.abs()}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 40,
                                    fontWeight: FontWeight.w300,
                                    letterSpacing: -1.0,
                                  ),
                                ),
                              const SizedBox(width: 8),
                              Text(
                                dDay == 0 ? "TODAY" : "DAYS LEFT",
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          )
                        else
                          const Text(
                            "아직 등록된 이사가 없습니다",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                color: Colors.white.withValues(alpha: 0.6),
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  state.isDDayConfigured
                                      ? "출발: ${state.departureAddress} ➔ 도착: ${state.arrivalAddress}"
                                      : "날짜와 주소를 입력하면 D-Day 스케줄과 스마트 미션을 제공해 드려요.",
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.75),
                                    fontSize: 11.5,
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const UC02ScheduleScreen(),
                              ),
                            ).then((_) => setState(() {}));
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.25),
                              width: 0.8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          child: Text(
                            state.isDDayConfigured ? "이사 정보 변경" : "이사 D-Day 설정하기",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            // ── Section Title ──
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 16,
                      color: Color(0xFFE6007E),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      "AI 이사 특화 서비스",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1E),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Asymmetrical layout: 2 wide hero cards at the top
            _buildWideServiceCard(
              icon: Icons.layers_rounded,
              title: "AI 룸 플래너",
              badge: "AI 추천",
              badgeColor: const Color(0xFFE6007E),
              iconGradientColors: const [Color(0xFFF06292), Color(0xFFE91E63)],
              description: "우리집 공간에 가전/가구를 2D/3D로 미리 배치해보세요",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UC03RoomPlannerScreen(),
                  ),
                );
              },
            ),

            _buildWideServiceCard(
              icon: Icons.swap_horizontal_circle_rounded,
              title: "AI 트레이드인",
              badge: "AI 분석",
              badgeColor: const Color(0xFFE6007E),
              iconGradientColors: const [Color(0xFFFFA726), Color(0xFFFB8C00)],
              description: "기존 가전의 상태를 간편 분석하고 중고 매입을 진행하세요",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UC04TradeInScreen(),
                  ),
                );
              },
            ),
            _buildWideServiceCard(
              icon: Icons.verified_user_rounded,
              title: "안심 리포트",
              badge: "하자 진단",
              badgeColor: const Color(0xFFE6007E),
              iconGradientColors: const [Color(0xFF81C784), Color(0xFF4CAF50)],
              description: "이사 전후 스크래치 하자 탐지와 증빙 리포트 생성",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UC05SafeReportScreen(),
                  ),
                );
              },
            ),
            _buildWideServiceCard(
              icon: Icons.emoji_events_rounded,
              title: "정착 챌린지",
              badge: "적립 미션",
              badgeColor: const Color(0xFFFF9800),
              iconGradientColors: const [Color(0xFFFFD54F), Color(0xFFFFB300)],
              description: "새로운 동네 적응을 돕는 유용한 미션 수행하고 포인트 적립",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UC06SettlementScreen(),
                  ),
                );
              },
            ),
            _buildWideServiceCard(
              icon: Icons.forum_rounded,
              title: "커뮤니티",
              badge: "이웃 소통",
              badgeColor: const Color(0xFF7C4DFF),
              iconGradientColors: const [Color(0xFFBA68C8), Color(0xFF8E24AA)],
              description: "동네 이웃 주민들과 정보 공유 및 새집 자랑방 소통",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UC07CommunityScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWideServiceCard({
    required IconData icon,
    required String title,
    required String badge,
    required Color badgeColor,
    required List<Color> iconGradientColors,
    required String description,
    required VoidCallback onTap,
  }) {
    final bool isPinkBadge = badgeColor == const Color(0xFFE6007E);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFE2E4E8).withValues(alpha: 0.4),
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
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: iconGradientColors,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: iconGradientColors.last.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1E),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: isPinkBadge
                              ? badgeColor
                              : badgeColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            color: isPinkBadge ? Colors.white : badgeColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF6B6860),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF8A877F),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
