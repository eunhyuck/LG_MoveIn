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
        title: const Text("정착 챌린지 (UC-06)"),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2B2A27),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: const Color(0xFF2B2A27), borderRadius: BorderRadius.circular(20)),
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
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: state.completedMissions / 30.0,
                    backgroundColor: const Color(0x33FFFFFF),
                    color: const Color(0xFFE6007E),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text("오늘의 맞춤 정착 미션", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildMissionRow("동네 봉투 판매처 찾아보기 🗑️", 100, true),
            _buildMissionRow("주민센터 전입신고 완료하기 🏢", 300, false),
            _buildMissionRow("동네 최애 카페 찾기 ☕", 150, false),
            const SizedBox(height: 24),
            const Text("획득한 훈장/배지", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: state.badges.map((badge) {
                return Chip(
                  avatar: const Icon(Icons.stars, color: Color(0xFFE6007E), size: 18),
                  label: Text(badge),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFE2E4E8)),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionRow(String title, int points, bool isCompleted) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isCompleted ? const Color(0xFF27AE60) : const Color(0xFF8A877F),
          ),
          const SizedBox(width: 16),
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
                Text("+$points P 획득", style: const TextStyle(color: Color(0xFFE6007E), fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          if (!isCompleted)
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
              ),
              child: const Text("인증하기"),
            ),
        ],
      ),
    );
  }
}
