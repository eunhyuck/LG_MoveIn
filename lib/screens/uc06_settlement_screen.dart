import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lg_move_in/models/move_in_state.dart';

class UC06SettlementScreen extends StatefulWidget {
  const UC06SettlementScreen({super.key});

  @override
  State<UC06SettlementScreen> createState() => _UC06SettlementScreenState();
}

class _UC06SettlementScreenState extends State<UC06SettlementScreen> {
  final state = MoveInState.instance;

  int _activeTab = 0; // 0: 오늘의 미션, 1: 정착 현황
  int? _selectedMissionIndex;
  String? _verificationPhotoUrl;
  bool _isPhotoUploading = false;

  late List<Map<String, dynamic>> _missions;

  @override
  void initState() {
    super.initState();
    _missions = [
      {
        "title": "첫 빨래 돌리기 🧺",
        "desc": "LG ThinQ 앱에 이사 갈 집의 세탁기를 연동해 등록하고 첫 빨래 코스를 실행해 보세요.",
        "points": 100,
        "isCompleted": false,
        "badge": "첫빨래",
        "icon": Icons.local_laundry_service_outlined,
        "actionDesc": "LG ThinQ 앱 등록 또는 수동 코스 완료",
        "image": null
      },
      {
        "title": "동네 산책 20분 🚶‍♂️",
        "desc": "가까운 동네 골목길이나 공원을 20분 이상 산책하며 주변 지리를 파악해 보세요.",
        "points": 150,
        "isCompleted": false,
        "badge": "산책",
        "icon": Icons.directions_walk_outlined,
        "actionDesc": "위치 인증 또는 수동 사진 업로드",
        "image": null
      },
      {
        "title": "단골 카페 찾기 ☕",
        "desc": "이웃 주민들이 추천하는 숨겨진 동네 커피 맛집이나 디저트 카페를 방문해 보세요.",
        "points": 120,
        "isCompleted": false,
        "badge": "카페",
        "icon": Icons.local_cafe_outlined,
        "actionDesc": "카페 방문 인증 영수증 또는 매장 사진 업로드",
        "image": null
      },
      {
        "title": "주민센터 전입신고 🏢",
        "desc": "이사 후 14일 이내 관할 주민센터를 방문하거나 정부24 웹을 통해 전입신고를 마쳐보세요.",
        "points": 300,
        "isCompleted": false,
        "badge": "전입신고",
        "icon": Icons.domain_outlined,
        "actionDesc": "전입신고 완료증 접수증 캡쳐본 인증",
        "image": null
      },
      {
        "title": "이웃 주민 소통 💬",
        "desc": "입주민 전용 소통 커뮤니티에 이웃 가전 매물 정보나 이사 팁을 남겨보세요.",
        "points": 100,
        "isCompleted": false,
        "badge": "소통",
        "icon": Icons.chat_bubble_outline_rounded,
        "actionDesc": "커뮤니티 게시물 등록 또는 댓글 소통 완료",
        "image": null
      }
    ];
  }

  Future<void> _pickVerificationPhoto() async {
    setState(() {
      _isPhotoUploading = true;
    });

    try {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("인증 사진 등록", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: const Text("인증 샷 제출 방식을 선택해 주세요. 시뮬레이션 버튼을 누르면 해당 미션에 어울리는 예시 사진이 자동으로 입력됩니다."),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.image,
                    allowMultiple: false,
                    withData: true,
                  );
                  if (result != null && result.files.isNotEmpty) {
                    final bytes = result.files.first.bytes;
                    if (bytes != null) {
                      setState(() {
                        _verificationPhotoUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                      });
                    }
                  }
                } catch (e) {
                  _useMockPhoto();
                }
              },
              child: const Text("갤러리에서 선택"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _useMockPhoto();
              },
              child: const Text("시뮬레이션 등록 (권장)", style: TextStyle(color: Color(0xFFE6007E), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } catch (_) {
      _useMockPhoto();
    } finally {
      setState(() {
        _isPhotoUploading = false;
      });
    }
  }

  void _useMockPhoto() {
    final m = _missions[_selectedMissionIndex!];
    final badge = m['badge'] as String;

    String mockImg = "laundry";
    if (badge == "산책") mockImg = "walking";
    if (badge == "카페") mockImg = "cafe";
    if (badge == "전입신고") mockImg = "office";
    if (badge == "소통") mockImg = "chat";

    setState(() {
      _verificationPhotoUrl = "mock_$mockImg";
    });
  }

  Widget _buildMockPhotoWidget(String key) {
    String title = "인증 사진";
    String subtitle = "";
    IconData icon = Icons.camera_alt_outlined;
    List<Color> gradient = [const Color(0xFFE2E8F0), const Color(0xFFCBD5E1)];

    if (key == "mock_laundry") {
      title = "세탁 코스 완료 🧺";
      subtitle = "ThinQ Smart 세탁 연동 완료";
      icon = Icons.local_laundry_service;
      gradient = [const Color(0xFFE0F2FE), const Color(0xFFBAE6FD)];
    } else if (key == "mock_walking") {
      title = "동네 산책 완료 🚶‍♂️";
      subtitle = "분당 중앙공원 2.4km GPS 인증 완료";
      icon = Icons.directions_walk_rounded;
      gradient = [const Color(0xFFE6F4EA), const Color(0xFFCEEAD6)];
    } else if (key == "mock_cafe") {
      title = "동네 카페 방문 완료 ☕";
      subtitle = "동네 영수증 및 위치 인증 완료";
      icon = Icons.local_cafe_rounded;
      gradient = [const Color(0xFFFDF0ED), const Color(0xFFFBE4DC)];
    } else if (key == "mock_office") {
      title = "전입신고 완료증 접수 🏢";
      subtitle = "정부24 민원 접수 번호 인증 완료";
      icon = Icons.domain_verification_rounded;
      gradient = [const Color(0xFFEEF2F6), const Color(0xFFD8E2EF)];
    } else if (key == "mock_chat") {
      title = "커뮤니티 소통 완료 💬";
      subtitle = "중고마켓 소통 피드 작성 완료";
      icon = Icons.chat_bubble_rounded;
      gradient = [const Color(0xFFF3E8FF), const Color(0xFFE9D5FF)];
    }

    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            right: -10,
            bottom: -10,
            child: Opacity(
              opacity: 0.15,
              child: Icon(icon, size: 120, color: const Color(0xFF2B2A27)),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Icon(icon, color: const Color(0xFFE6007E), size: 36),
              ),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2B2A27))),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF5F5D58))),
            ],
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFF27AE60), borderRadius: BorderRadius.circular(12)),
              child: const Row(
                children: [
                  Icon(Icons.check, color: Colors.white, size: 10),
                  SizedBox(width: 4),
                  Text("인증됨", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _completeActiveMission() {
    if (_selectedMissionIndex == null) return;
    final m = _missions[_selectedMissionIndex!];
    final points = m['points'] as int;
    final badge = m['badge'] as String;

    setState(() {
      m['isCompleted'] = true;
      m['image'] = _verificationPhotoUrl;
      state.currentPoints += points;
      state.completedMissions += 1;
      if (!state.badges.contains(badge)) {
        state.badges.add(badge);
      }
    });

    final isAllCompleted = _missions.every((x) => x['isCompleted'] == true);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(color: Color(0xFFF0FFF4), shape: BoxShape.circle),
              child: const Icon(Icons.emoji_events_rounded, color: Color(0xFF27AE60), size: 48),
            ),
            const SizedBox(height: 20),
            const Text(
              "미션 완료! 🎉",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF2B2A27)),
            ),
            const SizedBox(height: 10),
            Text(
              "'${m['title']}' 미션 수행이 확인되었습니다.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF5F5D58)),
            ),
            const SizedBox(height: 4),
            Text(
              "+$points P가 성공적으로 적립되었습니다.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFE6007E)),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFFFECEF), borderRadius: BorderRadius.circular(12)),
              child: Text(
                "🎖️ '$badge' 획득!",
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFE6007E)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _selectedMissionIndex = null;
                _verificationPhotoUrl = null;
                if (isAllCompleted) {
                  _activeTab = 1; // Auto switch to status tab to show final report
                }
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2B2A27),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("확인", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showFinalReportSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E2F),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)),
                margin: const EdgeInsets.only(bottom: 24),
              ),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 28),
                  SizedBox(width: 8),
                  Text(
                    "D+30 정착 완료 리포트",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "새보금자리 이사 후 30일간의 여정 기록",
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    _buildReportRow("정착 적응 진행률", "100% 완료", const Color(0xFF10B981)),
                    const Divider(color: Colors.white12),
                    _buildReportRow("클리어한 정착 미션", "총 ${_missions.length}개", Colors.white),
                    const Divider(color: Colors.white12),
                    _buildReportRow("총 누적 정착 포인트", "${state.currentPoints} P", const Color(0xFFE6007E)),
                    const Divider(color: Colors.white12),
                    _buildReportRow("최종 획득 명예 칭호", "🏆 분당 정착의 제왕", const Color(0xFFFFD700)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "LG MoveIn 스마트 가전 연동과 활발한 이웃 커뮤니티 소통을 통해 새로운 보금자리에 성공적으로 정착하셨습니다. 입주 완료 기념 특별 보상이 발급되었습니다!",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12.5, height: 1.5),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("입주 정착 축하 보상이 지급되었습니다! 🎁")),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE6007E),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text("보상 수령 완료 및 리포트 저장", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReportRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
          Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isStarted = state.isChallengeStarted;

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedMissionIndex != null ? "미션 수행" : "정착 챌린지"),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2B2A27),
        elevation: 0,
        centerTitle: true,
        leading: _selectedMissionIndex != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _selectedMissionIndex = null;
                    _verificationPhotoUrl = null;
                  });
                },
              )
            : null,
      ),
      backgroundColor: const Color(0xFFF8F9FC),
      body: !isStarted
          ? _buildStep1Activation()
          : _selectedMissionIndex != null
              ? _buildStep3MissionDetail()
              : _activeTab == 0
                  ? _buildStep2MissionsList()
                  : _buildStep4ChallengeStatus(),
      bottomNavigationBar: _buildStickyBottomCTA(),
    );
  }

  // ─── Step 1: 챌린지 시작 대기 화면 ───
  Widget _buildStep1Activation() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 10),
          Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF0F5), Color(0xFFE8F0FE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: 20,
                  left: 30,
                  child: Icon(Icons.star_rounded, color: const Color(0xFFFFD700).withValues(alpha: 0.6), size: 36),
                ),
                Positioned(
                  bottom: 30,
                  right: 40,
                  child: Icon(Icons.favorite_rounded, color: const Color(0xFFE6007E).withValues(alpha: 0.4), size: 48),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                      ),
                      child: const Icon(Icons.home_work_rounded, color: Color(0xFFE6007E), size: 64),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Welcome to 분당 🏡",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2B2A27)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          const Text(
            "새집 정착, 시작해 볼까요?",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2B2A27),
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          const Text(
            "30일 동안 매일 제안되는 작은 미션을 통해\n새로운 보금자리와 낯선 동네에 완벽히 적응해 보세요.",
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF8A877F),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Color(0xFF3B82F6), size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "D-Day 이사 완료 후 자동으로 활성화됩니다. 미션을 수행하면 이웃과의 교류와 정착 포인트를 쌓으실 수 있습니다.",
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF475569),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // ─── Step 2: 오늘의 맞춤 미션 리스트 화면 ───
  Widget _buildStep2MissionsList() {
    return Column(
      children: [
        _buildTabsHeader(),
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    "오늘의 미션",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2B2A27)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6007E),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "맞춤 미션",
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Color(0xFFE6007E), size: 14),
                  SizedBox(width: 4),
                  Text(
                    "AI 가구 구성·반려동물·생활 패턴 기반 맞춤 제안",
                    style: TextStyle(fontSize: 11, color: Color(0xFFE6007E), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            itemCount: _missions.length,
            padding: const EdgeInsets.only(bottom: 24),
            itemBuilder: (context, index) {
              return _buildMissionItemCard(_missions[index], index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTabsHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _activeTab = 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _activeTab == 0 ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: _activeTab == 0
                        ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "오늘의 미션",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: _activeTab == 0 ? const Color(0xFF2B2A27) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _activeTab = 1),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _activeTab == 1 ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: _activeTab == 1
                        ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "정착 현황",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: _activeTab == 1 ? const Color(0xFF2B2A27) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionItemCard(Map<String, dynamic> mission, int index) {
    final bool isCompleted = mission['isCompleted'] as bool;
    final icon = mission['icon'] as IconData;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMissionIndex = index;
          _verificationPhotoUrl = mission['image'] as String?;
        });
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
          ],
          border: Border.all(
            color: isCompleted ? const Color(0xFFE2E8F0) : const Color(0xFFF3E5F5),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: isCompleted ? const Color(0xFF27AE60) : const Color(0xFFD0D3D4),
                size: 24,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mission['title'] as String,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: isCompleted ? const Color(0xFF8A877F) : const Color(0xFF2B2A27),
                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(icon, size: 12, color: const Color(0xFF8A877F)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            mission['actionDesc'] as String,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF8A877F)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isCompleted ? const Color(0xFFF0FFF4) : const Color(0xFFFFF0F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "+${mission['points']} P",
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: isCompleted ? const Color(0xFF27AE60) : const Color(0xFFE6007E),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFBCC6CC), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Step 3: 미션 상세 수행 및 인증 화면 ───
  Widget _buildStep3MissionDetail() {
    final m = _missions[_selectedMissionIndex!];
    final bool isCompleted = m['isCompleted'] as bool;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFFFF0F5), borderRadius: BorderRadius.circular(12)),
            child: Text(
              "🎖️ ${m['badge']} 미션",
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFE6007E)),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            m['title'] as String,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2B2A27)),
          ),
          const SizedBox(height: 6),
          Text(
            m['desc'] as String,
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF5F5D58), height: 1.4),
          ),
          const SizedBox(height: 24),
          const Text("미션 인증 자료 제출", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2B2A27))),
          const SizedBox(height: 10),
          _verificationPhotoUrl == null
              ? GestureDetector(
                  onTap: isCompleted ? null : _pickVerificationPhoto,
                  child: Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _isPhotoUploading
                            ? const CircularProgressIndicator(color: Color(0xFFE6007E))
                            : const Icon(Icons.add_a_photo_outlined, size: 40, color: Color(0xFF8A877F)),
                        const SizedBox(height: 12),
                        const Text("인증 사진 등록하기", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2B2A27))),
                        const SizedBox(height: 6),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            "미션 수행을 증명할 수 있는 현장 사진을 촬영하거나 갤러리에서 업로드해 주세요.",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11, color: Color(0xFF8A877F), height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Stack(
                  children: [
                    _verificationPhotoUrl!.startsWith("mock_")
                        ? _buildMockPhotoWidget(_verificationPhotoUrl!)
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.memory(
                              base64Decode(_verificationPhotoUrl!.split(',')[1]),
                              width: double.infinity,
                              height: 200,
                              fit: BoxFit.cover,
                            ),
                          ),
                    if (!isCompleted)
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: ElevatedButton.icon(
                          onPressed: _pickVerificationPhoto,
                          icon: const Icon(Icons.refresh, size: 14),
                          label: const Text("사진 변경", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF2B2A27),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                          ),
                        ),
                      ),
                  ],
                ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFF8F9FC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Row(
              children: [
                const Icon(Icons.verified_outlined, color: Color(0xFF27AE60), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("인증 방식 안내", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2B2A27))),
                      const SizedBox(height: 2),
                      Text(
                        m['actionDesc'] as String,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF5F5D58)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  // ─── Step 4: 정착 현황 화면 ───
  Widget _buildStep4ChallengeStatus() {
    final bool isAllCompleted = _missions.every((x) => x['isCompleted'] == true);

    return Column(
      children: [
        _buildTabsHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                        color: const Color(0xFF1E1E3F).withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: -20,
                        right: -20,
                        child: Opacity(
                          opacity: 0.08,
                          child: Container(width: 120, height: 120, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                        ),
                      ),
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Opacity(
                          opacity: 0.12,
                          child: const Icon(Icons.emoji_events, color: Colors.white, size: 48),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("분당 정착 적응 챌린지 진행도 🏡", style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("누적 포인트: ${state.currentPoints} P", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 19)),
                                Text("진행률: ${state.completedMissions}/30", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFE6007E).withValues(alpha: 0.35),
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
                                  minHeight: 8,
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
                const Text("획득한 훈장/배지", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2B2A27))),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ...state.badges.map((badge) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFFFF0F5), Color(0xFFF3E5F5)]),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(color: const Color(0xFFE6007E).withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Chip(
                            avatar: const Icon(Icons.military_tech, color: Color(0xFFE6007E), size: 18),
                            label: Text(badge, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2B2A27), fontSize: 12)),
                            backgroundColor: Colors.transparent,
                            side: BorderSide.none,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        );
                      }),
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.add, color: Color(0xFF64748B), size: 18),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isAllCompleted ? const Color(0xFFE6007E) : const Color(0xFFE2E8F0),
                      width: isAllCompleted ? 1.5 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isAllCompleted ? Icons.emoji_events_rounded : Icons.lock_outline_rounded,
                            color: isAllCompleted ? const Color(0xFFE6007E) : const Color(0xFF94A3B8),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "D+30 정착 완료 리포트 + 보상",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isAllCompleted ? const Color(0xFFE6007E) : const Color(0xFF2B2A27),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "30일 동안의 모든 맞춤 정착 미션(5개 완료)을 마쳐 최종 입주 적응 상태 리포트를 발급받고, 특별 정착 보상 혜택을 수령해 보세요.",
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF5F5D58), height: 1.4),
                      ),
                      if (!isAllCompleted) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Color(0xFF64748B), size: 13),
                              const SizedBox(width: 6),
                              Text(
                                "남은 미션: ${_missions.where((x) => !x['isCompleted']).length}개를 모두 완료해야 활성화됩니다.",
                                style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 120),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget? _buildStickyBottomCTA() {
    final bool isStarted = state.isChallengeStarted;

    if (!isStarted) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () {
                setState(() {
                  state.isChallengeStarted = true;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("정착 챌린지가 시작되었습니다! 🏡 미션을 확인하고 참여해 보세요.")),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2B2A27),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text("챌린지 시작", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ],
        ),
      );
    }

    if (_selectedMissionIndex != null) {
      final m = _missions[_selectedMissionIndex!];
      final bool isCompleted = m['isCompleted'] as bool;

      return Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: isCompleted
                  ? null
                  : () {
                      if (_verificationPhotoUrl == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("인증 사진을 업로드해 주세요!")),
                        );
                        return;
                      }
                      _completeActiveMission();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE6007E),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(
                isCompleted ? "미션 수행 완료됨" : "완료 체크",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            if (!isCompleted) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _selectedMissionIndex = null;
                    _verificationPhotoUrl = null;
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("이 미션 건너뛰기", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              ),
            ],
          ],
        ),
      );
    }

    if (_activeTab == 1) {
      final bool isAllCompleted = _missions.every((x) => x['isCompleted'] == true);

      return Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: isAllCompleted ? _showFinalReportSheet : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2B2A27),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text("D+30 정착 리포트 보기", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ],
        ),
      );
    }

    return null;
  }
}
