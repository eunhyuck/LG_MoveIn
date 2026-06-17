import 'package:flutter/material.dart';
import 'package:lg_move_in/models/move_in_state.dart';

class UC06SettlementScreen extends StatefulWidget {
  const UC06SettlementScreen({super.key});

  @override
  State<UC06SettlementScreen> createState() => _UC06SettlementScreenState();
}

class _UC06SettlementScreenState extends State<UC06SettlementScreen> {
  final state = MoveInState.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("정착 챌린지"),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2B2A27),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF4F5F8),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero Card with gradient & decorations ──
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2B2A27), Color(0xFF1E1E3F)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E1E3F).withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Decorative circles – top-right
                  Positioned(
                    top: -20,
                    right: -20,
                    child: Opacity(
                      opacity: 0.08,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 30,
                    child: Opacity(
                      opacity: 0.08,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 50,
                    right: -10,
                    child: Opacity(
                      opacity: 0.08,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  // Trophy icon – top-right
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Opacity(
                      opacity: 0.12,
                      child: Icon(
                        Icons.emoji_events,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ),
                  // Main content
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("새 동네 적응 챌린지 🏡", style: TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("누적 포인트: ${state.currentPoints} P", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                            Text("진행률: ${state.completedMissions}/30일", style: const TextStyle(color: Colors.white70)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // Progress bar with glow
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE6007E).withOpacity(0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: state.completedMissions / 30.0,
                              backgroundColor: const Color(0x33FFFFFF),
                              color: const Color(0xFFE6007E),
                              minHeight: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text("오늘의 맞춤 정착 미션", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2B2A27))),
            const SizedBox(height: 12),
            _buildMissionRow("동네 봉투 판매처 찾아보기 🗑️", 100, true),
            _buildMissionRow("주민센터 전입신고 완료하기 🏢", 300, false),
            _buildMissionRow("동네 최애 카페 찾기 ☕", 150, false),
            const SizedBox(height: 24),
            const Text("획득한 훈장/배지", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2B2A27))),
            const SizedBox(height: 12),
            // ── Badge section with gradient chips ──
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: state.badges.map((badge) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFCE4EC), Color(0xFFF3E5F5)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE6007E).withOpacity(0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Chip(
                    avatar: const Icon(Icons.military_tech, color: Color(0xFFE6007E), size: 20),
                    label: Text(badge, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2B2A27))),
                    backgroundColor: Colors.transparent,
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            // ── Motivational section ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFF0F5), Color(0xFFFFFFFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE6007E), width: 1),
              ),
              child: const Row(
                children: [
                  Expanded(
                    child: Text(
                      '꾸준히 미션을 수행하면 특별 보상이 기다려요! 🎁',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2B2A27),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionRow(String title, int points, bool isCompleted) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isCompleted ? const Color(0xFFF0FFF4) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border(
          left: BorderSide(
            color: isCompleted ? const Color(0xFF27AE60) : const Color(0xFFE6007E),
            width: 3,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isCompleted ? const Color(0xFF27AE60) : const Color(0xFF8A877F),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                      color: isCompleted ? const Color(0xFF8A877F) : const Color(0xFF2B2A27),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text("+$points P 획득", style: const TextStyle(color: Color(0xFFE6007E), fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Point badge
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isCompleted
                      ? [const Color(0xFF27AE60), const Color(0xFF2ECC71)]
                      : [const Color(0xFFE6007E), const Color(0xFFFF4DA6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isCompleted ? const Color(0xFF27AE60) : const Color(0xFFE6007E)).withOpacity(0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                '$points',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ),
            if (!isCompleted) ...[
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    state.currentPoints += points;
                    state.completedMissions += 1;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("미션 완료! $points P가 적립되었습니다.")),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2B2A27),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text("인증하기"),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
