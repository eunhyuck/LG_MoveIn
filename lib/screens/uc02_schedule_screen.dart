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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("이사 일정 등록 (UC-02)"),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2B2A27),
        elevation: 0,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildStepContent(),
      ),
    );
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

  Widget _buildStepOnboarding() {
    return Padding(
      key: const ValueKey(0),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.local_shipping_outlined, size: 80, color: Color(0xFF2B2A27)),
          const SizedBox(height: 24),
          const Text(
            "새 이사를 등록할까요?",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2B2A27)),
          ),
          const SizedBox(height: 12),
          const Text(
            "날짜와 주소만 입력하면 D-Day와 맞춤 일정이 자동으로 만들어져요.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Color(0xFF5F5D58)),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () => setState(() => _step = 1),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2B2A27),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("이사 등록 시작", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildStepDatePicker() {
    return Padding(
      key: const ValueKey(1),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "이사 일정을 골라주세요 (1/2)",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2B2A27)),
          ),
          const SizedBox(height: 20),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("이사 유형", style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<String>(
                value: _moveType,
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
            ],
          ),
          const SizedBox(height: 20),
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
              child: const Text("다음 단계", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepAddressInput() {
    return SingleChildScrollView(
      key: const ValueKey(2),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "주소를 입력해 주세요 (2/2)",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2B2A27)),
          ),
          const SizedBox(height: 24),
          const Text("기존 주소 (출발지)", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5F5D58))),
          const SizedBox(height: 8),
          TextField(
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              hintText: "출발지 주소를 입력하세요",
            ),
            controller: TextEditingController(text: _departureAddr),
            onChanged: (val) => _departureAddr = val,
          ),
          const SizedBox(height: 20),
          const Text("신규 주소 (도착지)", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5F5D58))),
          const SizedBox(height: 8),
          TextField(
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              hintText: "도착지 주소를 입력하세요",
            ),
            controller: TextEditingController(text: _arrivalAddr),
            onChanged: (val) => _arrivalAddr = val,
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
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
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2B2A27),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("저장하고 D-Day 만들기", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
