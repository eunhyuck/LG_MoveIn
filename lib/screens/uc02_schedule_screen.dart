import 'package:flutter/material.dart';
import 'package:lg_move_in/models/move_in_state.dart';

class UC02ScheduleScreen extends StatefulWidget {
  const UC02ScheduleScreen({super.key});

  @override
  State<UC02ScheduleScreen> createState() => _UC02ScheduleScreenState();
}

class _UC02ScheduleScreenState extends State<UC02ScheduleScreen> {
  int _step = 0;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 30));
  String _departureAddr = "서울시 서초구 서초대로 123";
  String _arrivalAddr = "경기도 성남시 분당구 판교로 456";
  String _moveType = "가정 이사";

  // ── Shared gradient used for CTA buttons ──
  static const _lgPinkGradient = LinearGradient(
    colors: [Color(0xFFE6007E), Color(0xFFFF4DA6)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F8),
      appBar: AppBar(
        title: const Text("이사 일정 등록"),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2B2A27),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildStepContent(),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget? _buildBottomNavigationBar() {
    switch (_step) {
      case 0:
        return Container(
          color: const Color(0xFFF4F5F8),
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: SafeArea(
            child: _buildGradientButton(
              label: "이사 등록 시작",
              onPressed: () => setState(() => _step = 1),
            ),
          ),
        );
      case 1:
        return Container(
          color: const Color(0xFFF4F5F8),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: SafeArea(
            child: _buildGradientButton(
              label: "다음 단계",
              onPressed: () => setState(() => _step = 2),
            ),
          ),
        );
      case 2:
        return Container(
          color: const Color(0xFFF4F5F8),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: SafeArea(
            child: _buildGradientButton(
              label: "저장하고 D-Day 만들기",
              onPressed: () {
                final state = MoveInState.instance;
                state.moveDate = _selectedDate;
                state.departureAddress = _departureAddr;
                state.arrivalAddress = _arrivalAddr;
                state.moveType = _moveType;
                state.isDDayConfigured = true;

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("이사 일정이 성공적으로 등록되었습니다!")),
                );
                Navigator.pop(context);
              },
            ),
          ),
        );
      default:
        return null;
    }
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return _buildStepOnboarding();
      case 1:
        return _buildStepDatePicker();
      case 2:
        return _buildStepAddressInput();
      default:
        return Container();
    }
  }

  // ────────────────────────────────────────────
  // Step indicator dots (onboarding)
  // ────────────────────────────────────────────
  Widget _buildStepDots(int activeIndex) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final isActive = i == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: isActive ? _lgPinkGradient : null,
            color: isActive ? null : const Color(0xFFD9D9D9),
          ),
        );
      }),
    );
  }

  // ────────────────────────────────────────────
  // Animated linear progress bar for steps 1 & 2
  // ────────────────────────────────────────────
  Widget _buildProgressBar(double fromFraction, double toFraction) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: fromFraction, end: toFraction),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      builder: (context, value, _) {
        return Container(
          height: 6,
          decoration: BoxDecoration(
            color: const Color(0xFFE8E8E8),
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: _lgPinkGradient,
              ),
            ),
          ),
        );
      },
    );
  }

  // ────────────────────────────────────────────
  // Gradient CTA button
  // ────────────────────────────────────────────
  Widget _buildGradientButton({
    required String label,
    required VoidCallback onPressed,
    double? width,
  }) {
    return SizedBox(
      width: width ?? double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: _lgPinkGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE6007E).withValues(alpha: 0.30),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 40),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────
  // Step 0 – Onboarding
  // ────────────────────────────────────────────
  Widget _buildStepOnboarding() {
    return Padding(
      key: const ValueKey(0),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Step dots
          _buildStepDots(0),
          const SizedBox(height: 6),
          Text(
            "Step 1 of 3",
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 36),

          // ── Decorative icon composition ──
          SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Large background circle
                Container(
                  width: 160,
                  height: 160,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF0F5),
                    shape: BoxShape.circle,
                  ),
                ),
                // Inner gradient circle with shipping icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _lgPinkGradient,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE6007E).withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.local_shipping_outlined, size: 38, color: Colors.white),
                ),
                // Floating calendar badge
                Positioned(
                  top: 14,
                  right: 14,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFFE6007E)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),
          const Text(
            "새 이사를 등록할까요?",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2B2A27)),
          ),
          const SizedBox(height: 12),
          const Text(
            "날짜와 주소만 입력하면 D-Day와 맞춤 일정이 자동으로 만들어져요.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Color(0xFF5F5D58), height: 1.5),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────
  // Step 1 – Date Picker
  // ────────────────────────────────────────────
  Widget _buildStepDatePicker() {
    return Padding(
      key: const ValueKey(1),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress bar
          _buildProgressBar(0.33, 0.66),
          const SizedBox(height: 18),

          // Header row with back button
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => setState(() => _step = 0),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Color(0xFF2B2A27)),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                "이사 일정을 골라주세요 (1/2)",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2B2A27)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Calendar
          Expanded(
            child: CalendarDatePicker(
              initialDate: _selectedDate,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              onDateChanged: (date) {
                setState(() {
                  _selectedDate = date;
                });
              },
            ),
          ),

          // Move-type dropdown styled with border & rounded corners
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E0E0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("이사 유형", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2B2A27))),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _moveType,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFFE6007E)),
                    style: const TextStyle(fontSize: 14, color: Color(0xFF2B2A27)),
                    items: ["가정 이사", "원룸 이사", "사무실 이사"].map((String val) {
                      return DropdownMenuItem<String>(
                        value: val,
                        child: Text(val),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _moveType = val);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────
  // Step 2 – Address Input
  // ────────────────────────────────────────────
  Widget _buildStepAddressInput() {
    return SingleChildScrollView(
      key: const ValueKey(2),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress bar
          _buildProgressBar(0.66, 1.0),
          const SizedBox(height: 18),

          // Header row with back button
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => setState(() => _step = 1),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Color(0xFF2B2A27)),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                "주소를 입력해 주세요 (2/2)",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2B2A27)),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Departure address
          Row(
            children: [
              const Icon(Icons.location_on, size: 18, color: Color(0xFFE6007E)),
              const SizedBox(width: 6),
              const Text("기존 주소 (출발지)", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5F5D58))),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE6007E), width: 1.5),
              ),
              hintText: "출발지 주소를 입력하세요",
              hintStyle: TextStyle(color: Colors.grey.shade400),
            ),
            controller: TextEditingController(text: _departureAddr),
            onChanged: (val) => _departureAddr = val,
          ),
          const SizedBox(height: 20),

          // Arrival address
          Row(
            children: [
              const Icon(Icons.location_on, size: 18, color: Color(0xFFE6007E)),
              const SizedBox(width: 6),
              const Text("신규 주소 (도착지)", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5F5D58))),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE6007E), width: 1.5),
              ),
              hintText: "도착지 주소를 입력하세요",
              hintStyle: TextStyle(color: Colors.grey.shade400),
            ),
            controller: TextEditingController(text: _arrivalAddr),
            onChanged: (val) => _arrivalAddr = val,
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}
