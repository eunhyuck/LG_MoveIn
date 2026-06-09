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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF2B2A27),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        state.isDDayConfigured ? "이사 예정 허브" : "이사 일정 등록 필요",
                        style: const TextStyle(
                          color: Color(0xFF8A877F),
                          fontSize: 13,
                        ),
                      ),
                      if (state.isDDayConfigured)
                        Text(
                          state.moveType,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    state.isDDayConfigured ? "이사까지 D-$dDay" : "아직 등록된 이사가 없습니다",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    state.isDDayConfigured
                        ? "${state.moveDate!.year}.${state.moveDate!.month.toString().padLeft(2, '0')}.${state.moveDate!.day.toString().padLeft(2, '0')} · 출발: ${state.departureAddress} ➔ 도착: ${state.arrivalAddress}"
                        : "날짜와 주소를 입력하면 D-Day에 맞춰 일정과 가전 가이드를 추천해 드려요.",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UC02ScheduleScreen(),
                        ),
                      ).then((_) => setState(() {}));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFFBEF),
                      foregroundColor: const Color(0xFF2B2A27),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      state.isDDayConfigured ? "이사 정보 변경" : "D-Day 일정 등록하기 📅",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(left: 4, bottom: 12),
                child: Text(
                  "AI 이사 특화 서비스",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2B2A27),
                  ),
                ),
              ),
            ),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.15,
              children: [
                _buildUseCaseMenuCard(
                  icon: Icons.calendar_today,
                  title: "이사 일정 관리",
                  badge: "UC-02",
                  description: "D-Day 일정 관리 및 주소 관리",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UC02ScheduleScreen(),
                      ),
                    ).then((_) => setState(() {}));
                  },
                ),
                _buildUseCaseMenuCard(
                  icon: Icons.layers_outlined,
                  title: "AI 룸 플래너",
                  badge: "UC-03",
                  description: "2D/3D 평면 가구·가전 배치",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UC03RoomPlannerScreen(),
                      ),
                    );
                  },
                ),
                _buildUseCaseMenuCard(
                  icon: Icons.swap_horizontal_circle_outlined,
                  title: "AI 트레이드인",
                  badge: "UC-04",
                  description: "기존 가전 분석 및 중고 매입",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UC04TradeInScreen(),
                      ),
                    );
                  },
                ),
                _buildUseCaseMenuCard(
                  icon: Icons.verified_user_outlined,
                  title: "안심 리포트",
                  badge: "UC-05",
                  description: "이사 전후 스크래치 하자 탐지",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UC05SafeReportScreen(),
                      ),
                    );
                  },
                ),
                _buildUseCaseMenuCard(
                  icon: Icons.emoji_events_outlined,
                  title: "정착 챌린지",
                  badge: "UC-06",
                  description: "새동네 적응 미션 & 포인트",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UC06SettlementScreen(),
                      ),
                    );
                  },
                ),
                _buildUseCaseMenuCard(
                  icon: Icons.forum_outlined,
                  title: "커뮤니티",
                  badge: "UC-07",
                  description: "동네 꿀팁 및 이사 자랑방",
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
          ],
        ),
      ),
    );
  }

  Widget _buildUseCaseMenuCard({
    required IconData icon,
    required String title,
    required String badge,
    required String description,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.01),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F5F8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: const Color(0xFF2B2A27), size: 20),
                ),
                Text(
                  badge,
                  style: const TextStyle(
                    color: Color(0xFF8A877F),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2B2A27),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              description,
              style: const TextStyle(fontSize: 11, color: Color(0xFF8A877F)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
