import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lg_move_in/utils/paste_helper.dart';

class UC05SafeReportScreen extends StatefulWidget {
  const UC05SafeReportScreen({super.key});

  @override
  State<UC05SafeReportScreen> createState() => _UC05SafeReportScreenState();
}

class _UC05SafeReportScreenState extends State<UC05SafeReportScreen>
    with SingleTickerProviderStateMixin {
  int _step = 0;
  bool _isScanning = false;
  bool _isFlashActive = false;
  double _overlayOpacity = 0.4;
  String _selectedCategory = '거실 벽면';

  // Paste helper and dialog state tracking
  late PasteHelper _pasteHelper;
  bool _isDialogOpen = false;
  String? _activeDialogCategory;
  String? _activeDialogImageTarget; // 'before' or 'after'

  // Track upload status of before and after photos
  final Map<String, bool> _uploadedBeforePhotos = {
    '거실 벽면': false,
    '현관 도어': false,
    '다용도실 타일': false,
    '거실 바닥재': false,
  };
  final Map<String, bool> _uploadedAfterPhotos = {
    '거실 벽면': false,
    '현관 도어': false,
    '다용도실 타일': false,
    '거실 바닥재': false,
  };

  // Store custom test image paths (handles URL, local blob, and base64)
  final Map<String, String?> _customBeforeImageUrls = {
    '거실 벽면': null,
    '현관 도어': null,
    '다용도실 타일': null,
    '거실 바닥재': null,
  };
  final Map<String, String?> _customAfterImageUrls = {
    '거실 벽면': null,
    '현관 도어': null,
    '다용도실 타일': null,
    '거실 바닥재': null,
  };

  // Track which categories have been scanned/analyzed
  final Map<String, bool> _scannedCategories = {
    '거실 벽면': false,
    '현관 도어': false,
    '다용도실 타일': false,
    '거실 바닥재': false,
  };

  // Store detailed defect analysis results
  final Map<String, DefectAnalysis?> _defectAnalyses = {
    '거실 벽면': null,
    '현관 도어': null,
    '다용도실 타일': null,
    '거실 바닥재': null,
  };

  // Checklist state tracking
  final Map<String, List<bool>> _checklistState = {
    '거실 벽면': [false, false, false],
    '거실 바닥재': [false, false, false],
    '현관 도어': [false, false, false],
    '다용도실 타일': [false, false, false],
  };

  // Checklist questions
  final Map<String, List<String>> _checklistQuestions = {
    '거실 벽면': [
      '스위치/콘센트 주변 벽지 찢김이 있나요?',
      '대형 가구/가전 배치 구역 뒤 벽지에 얼룩이 있나요?',
      '벽을 눌렀을 때 삐걱거리거나 덜컹거림이 있나요?',
    ],
    '거실 바닥재': [
      '가구/가전 끌림으로 인한 마루판 스크래치가 있나요?',
      '마루판 사이 벌어짐 또는 특정 구역 들뜸이 있나요?',
      '외부 충격으로 깊게 파인 찍힘 자국이 있나요?',
    ],
    '현관 도어': [
      '중문 또는 현관문 몰딩 도장 부위에 손상이 있나요?',
      '현관 도어락 작동이 원활하고 유격이 없나요?',
      '문 하단부에 심한 긁힘이나 녹이 슨 부위가 있나요?',
    ],
    '다용도실 타일': [
      '세탁기 설치 공간 주변 타일에 미세 실금이 있나요?',
      '타일 표면을 노크했을 때 내부가 빈 소리가 나나요?',
      '타일 사이 줄눈(백시멘트)에 깨짐이나 오염이 있나요?',
    ],
  };

  late AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // Initialize Clipboard paste and drag-drop listener
    _pasteHelper = PasteHelper();
    _pasteHelper.initPasteListener((imagePathOrBase64) {
      if (_isDialogOpen && _activeDialogCategory != null) {
        final category = _activeDialogCategory!;
        final target = _activeDialogImageTarget ?? 'before';
        setState(() {
          if (target == 'before') {
            _uploadedBeforePhotos[category] = true;
            _customBeforeImageUrls[category] = imagePathOrBase64;
          } else {
            _uploadedAfterPhotos[category] = true;
            _customAfterImageUrls[category] = imagePathOrBase64;
          }
          _isDialogOpen = false;
          _activeDialogCategory = null;
          _activeDialogImageTarget = null;
        });
        if (mounted) {
          Navigator.of(context).pop(); // Close the dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text("[$category] ${target == 'before' ? '이사 전' : '이사 후'} 이미지가 클립보드/드롭으로 등록되었습니다."),
                ],
              ),
              backgroundColor: const Color(0xFFE6007E),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _scanController.dispose();
    _pasteHelper.dispose();
    super.dispose();
  }

  DefectAnalysis _calculateDefectAnalysis({
    required String category,
    required String defectType,
    required double discrepancyArea,
  }) {
    if (defectType == '없음') {
      return DefectAnalysis(
        category: category,
        defectType: defectType,
        discrepancyArea: 0.0,
        severityWeight: 0.0,
        similarity: 100.0,
        riskScore: 0.0,
        title: '$category: 신규 하자 없음',
        description: '이사 전 사진과 비교 시 동일한 이미지로 판정되어 신규 발생 하자가 감지되지 않았습니다. 상태가 안전하게 보존되었습니다.',
      );
    }

    // 1. Defect Type Weights (하자의 종류 가중치)
    double typeWeight = 1.0;
    if (defectType == '균열/파손') {
      typeWeight = 9.0;
    } else if (defectType == '스크래치/긁힘') {
      typeWeight = 4.5;
    } else if (defectType == '오염/얼룩') {
      typeWeight = 1.5;
    }

    // 2. Category Safety Weights (하자의 위치 가중치)
    double locationWeight = 1.0;
    if (category == '다용도실 타일') {
      locationWeight = 1.3; // 누수 위험
    } else if (category == '거실 벽면') {
      locationWeight = 1.2; // 벽체 구조 및 석고보드 침하 위험
    } else if (category == '거실 바닥재') {
      locationWeight = 1.1; // 바닥재 긁힘 및 찍힘 파손 위험
    } else if (category == '현관 도어') {
      locationWeight = 1.0; // 문틀 몰딩 스크래치 및 찍힘
    }

    // 3. Risk Score Formula:
    // Base Risk (가중치 기반 기본 점수) = typeWeight * locationWeight * 8.0
    // Area Risk (면적 대비 위험도 점수) = discrepancyArea * typeWeight * 0.4
    // Total Risk Score = (Base Risk + Area Risk) clamped between 0 and 100.
    double baseRisk = typeWeight * locationWeight * 8.0;
    double areaRisk = discrepancyArea * typeWeight * 0.4;
    double riskScore = (baseRisk + areaRisk).clamp(0.0, 100.0);

    double similarity = (100.0 - discrepancyArea).clamp(0.0, 100.0);

    // Dynamic Title and Description reflecting the algorithm
    String title = '';
    String description = '';

    if (defectType == '균열/파손') {
      title = '$category 균열 및 자재 파손 감지';
      description = '$category 부위에 약 ${discrepancyArea.toStringAsFixed(1)}% 면적의 미세 균열이 검출되었습니다. 단순 오염이 아닌 구조 및 내구성과 관련된 파손 결함으로 분류되어 높은 가중치(${typeWeight.toStringAsFixed(1)}배)와 안전 중요도 가중치(${locationWeight.toStringAsFixed(1)}배)가 복합 적용된 고위험 하자입니다.';
    } else if (defectType == '스크래치/긁힘') {
      title = '$category 표면 스크래치 및 흠집';
      description = '$category 부위에 약 ${discrepancyArea.toStringAsFixed(1)}% 범위의 스크래치가 검출되었습니다. 짐 이동 과정에서 생긴 긁힘으로 자재 내부 노출 및 2차 부식이 생길 수 있어 중간 가중치(${typeWeight.toStringAsFixed(1)}배)가 반영되었습니다.';
    } else if (defectType == '오염/얼룩') {
      title = '$category 표면 오염 및 변색';
      description = '$category 부위에 약 ${discrepancyArea.toStringAsFixed(1)}% 범위의 얼룩이 관측되었습니다. 변색 범위는 상대적으로 넓을 수 있으나 구조적 영향이 없고 세척으로 복구가 용이해 낮은 가중치(${typeWeight.toStringAsFixed(1)}배)가 적용되었습니다.';
    }

    return DefectAnalysis(
      category: category,
      defectType: defectType,
      discrepancyArea: discrepancyArea,
      severityWeight: double.parse((typeWeight * locationWeight).toStringAsFixed(2)),
      similarity: similarity,
      riskScore: double.parse(riskScore.toStringAsFixed(1)),
      title: title,
      description: description,
    );
  }

  void _triggerScan() {
    setState(() {
      _isFlashActive = true;
    });

    // Camera flash effect (150ms)
    Timer(const Duration(milliseconds: 150), () {
      setState(() {
        _isFlashActive = false;
        _isScanning = true;
      });
      _scanController.repeat(reverse: true);

      // Scanner simulation for 3 seconds
      Timer(const Duration(seconds: 3), () {
        _scanController.stop();

        // Calculate similarity and structural defect risk using the weighted algorithm
        final beforeUrl = _customBeforeImageUrls[_selectedCategory];
        final afterUrl = _customAfterImageUrls[_selectedCategory];
        
        DefectAnalysis analysis;

        if (beforeUrl != null && afterUrl != null && beforeUrl == afterUrl) {
          analysis = _calculateDefectAnalysis(
            category: _selectedCategory,
            defectType: '없음',
            discrepancyArea: 0.0,
          );
        } else {
          // Deterministically generate analysis parameters using combined hash
          int hash = ((beforeUrl?.hashCode ?? 0) ^ (afterUrl?.hashCode ?? 0)).abs();
          if (hash == 0) hash = _selectedCategory.hashCode.abs();

          // We alternate between Low Severity (Stain/Contamination) and High/Medium Severity (Scratch or Crack)
          bool isCritical = hash % 2 == 0; 
          
          if (isCritical) {
            // Option B: High-severity or structural defects (Small discrepancy area, high risk!)
            if (_selectedCategory == '다용도실 타일') {
              analysis = _calculateDefectAnalysis(category: _selectedCategory, defectType: '균열/파손', discrepancyArea: 2.4);
            } else if (_selectedCategory == '거실 벽면') {
              analysis = _calculateDefectAnalysis(category: _selectedCategory, defectType: '균열/파손', discrepancyArea: 3.2);
            } else if (_selectedCategory == '현관 도어') {
              analysis = _calculateDefectAnalysis(category: _selectedCategory, defectType: '스크래치/긁힘', discrepancyArea: 6.5);
            } else { // 거실 바닥재
              analysis = _calculateDefectAnalysis(category: _selectedCategory, defectType: '스크래치/긁힘', discrepancyArea: 5.0);
            }
          } else {
            // Option A: Low-severity defects (Large discrepancy area, but low risk!)
            if (_selectedCategory == '다용도실 타일') {
              analysis = _calculateDefectAnalysis(category: _selectedCategory, defectType: '오염/얼룩', discrepancyArea: 18.2);
            } else if (_selectedCategory == '거실 벽면') {
              analysis = _calculateDefectAnalysis(category: _selectedCategory, defectType: '오염/얼룩', discrepancyArea: 12.5);
            } else if (_selectedCategory == '현관 도어') {
              analysis = _calculateDefectAnalysis(category: _selectedCategory, defectType: '오염/얼룩', discrepancyArea: 15.0);
            } else { // 거실 바닥재
              analysis = _calculateDefectAnalysis(category: _selectedCategory, defectType: '오염/얼룩', discrepancyArea: 14.5);
            }
          }
        }

        setState(() {
          _isScanning = false;
          _scannedCategories[_selectedCategory] = true;
          _defectAnalyses[_selectedCategory] = analysis;
          _step = 3; // Move to report screen (Step 3)
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        leading: _step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _step--;
                  });
                },
              )
            : null,
        title: const Text(
          "이사 안심 리포트 (UC-05)",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2B2A27),
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(
            color: const Color(0xFFE2E4E8),
            height: 1,
          ),
        ),
      ),
      body: Stack(
        children: [
          _buildSafeReportBody(),
          if (_isFlashActive)
            Container(
              color: Colors.white,
            ),
        ],
      ),
    );
  }

  Widget _buildSafeReportBody() {
    if (_isScanning) {
      return _buildScanningIndicator();
    }
    switch (_step) {
      case 0:
        return _buildStepPreMoveChecklist();
      case 1:
        return _buildStepPreMove();
      case 2:
        return _buildStepPostMoveGuide();
      case 3:
        return _buildStepAnalysisReport();
      default:
        return Container();
    }
  }

  // AI scanning laser animation widget
  Widget _buildScanningIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE6007E), width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  _buildBaseCameraView(defect: true),
                  AnimatedBuilder(
                    animation: _scanController,
                    builder: (context, child) {
                      double offset = _scanController.value * 280;
                      return Positioned(
                        top: offset,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 4,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Color(0xFFFF5A5F),
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFFFF5A5F),
                                blurRadius: 8,
                                spreadRadius: 2,
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome, color: Color(0xFFE6007E), size: 20),
              SizedBox(width: 8),
              Text(
                "픽셀 단위 전/후 비교 대조 중...",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2B2A27)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "이미지 분석을 통해 이사 중 발생한\n미세 스크래치와 타일 균열을 추적하고 있습니다.",
            style: TextStyle(color: Color(0xFF8A877F), fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Helper to build camera view with or without defects
  Widget _buildBaseCameraView({required bool defect}) {
    return CustomPaint(
      painter: RoomPainter(roomType: _selectedCategory, showDefect: defect),
    );
  }

  // Safe image widget builder that handles base64, networks, and blobs,
  // providing a secure placeholder on load failure without exposing raw paths/URLs.
  Widget _buildImageWidget(String path, {BoxFit fit = BoxFit.cover}) {
    if (path.startsWith('data:image/')) {
      try {
        final base64Content = path.split(',')[1];
        final Uint8List bytes = base64Decode(base64Content);
        return Image.memory(
          bytes,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _buildFallbackErrorView(),
        );
      } catch (e) {
        return _buildFallbackErrorView();
      }
    } else {
      return Image.network(
        path,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildFallbackErrorView(),
      );
    }
  }

  Widget _buildFallbackErrorView() {
    return Container(
      color: const Color(0xFFF0F1F4),
      padding: const EdgeInsets.all(12),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported_outlined, color: Color(0xFF8A877F), size: 32),
            SizedBox(height: 6),
            Text(
              "이미지를 불러올 수 없습니다.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Color(0xFF8A877F), fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 2),
            Text(
              "보안 제한 또는 지원하지 않는 형식입니다.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9, color: Color(0xFFB0AEB9)),
            ),
          ],
        ),
      ),
    );
  }

  // STEP 0: Pre-move inspection checklist screen
  Widget _buildStepPreMoveChecklist() {
    int totalItems = 12;
    int checkedCount = 0;
    _checklistState.forEach((key, list) {
      for (var checked in list) {
        if (checked) checkedCount++;
      }
    });
    double progress = totalItems > 0 ? checkedCount / totalItems : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6007E).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  "STEP 01",
                  style: TextStyle(
                    color: Color(0xFFE6007E),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                "이사 전 상태 점검 체크리스트",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2B2A27)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "이삿짐 이동 전에 영역별 핵심 점검 요소를 직접 살펴보고 꼼꼼하게 현재 상태를 기록해 주세요.",
            style: TextStyle(color: Color(0xFF8A877F), fontSize: 13),
          ),
          const SizedBox(height: 20),
          
          // Progress Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E4E8)),
              boxShadow: const [
                BoxShadow(color: Color(0x02000000), blurRadius: 10, offset: Offset(0, 4))
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "사전 점검 진행률",
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2B2A27)),
                    ),
                    Text(
                      "$checkedCount / $totalItems 항목 완료 (${(progress * 100).toInt()}%)",
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFE6007E)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFF0F1F4),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE6007E)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Category Cards with Checkboxes
          ..._checklistQuestions.keys.map((category) {
            final questions = _checklistQuestions[category]!;
            final state = _checklistState[category]!;

            IconData categoryIcon = Icons.home_work_outlined;
            if (category == '거실 벽면') {
              categoryIcon = Icons.wallpaper_outlined;
            } else if (category == '거실 바닥재') {
              categoryIcon = Icons.layers_outlined;
            } else if (category == '현관 도어') {
              categoryIcon = Icons.door_sliding_outlined;
            } else if (category == '다용도실 타일') {
              categoryIcon = Icons.grid_on_outlined;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E4E8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(categoryIcon, color: const Color(0xFFE6007E), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        category,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2B2A27)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  ...List.generate(questions.length, (index) {
                    return CheckboxListTile(
                      value: state[index],
                      onChanged: (val) {
                        setState(() {
                          state[index] = val ?? false;
                        });
                      },
                      title: Text(
                        questions[index],
                        style: const TextStyle(fontSize: 12, color: Color(0xFF2B2A27)),
                      ),
                      activeColor: const Color(0xFFE6007E),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    );
                  }),
                ],
              ),
            );
          }),

          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _step = 1; // Go to Pre-move photo registration
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE6007E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text("체크리스트 확인 완료 및 사진 등록", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // STEP 1: Pre-move recording screen
  Widget _buildStepPreMove() {
    bool canProceed = _uploadedBeforePhotos.values.any((uploaded) => uploaded);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6007E).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  "STEP 02",
                  style: TextStyle(
                    color: Color(0xFFE6007E),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                "이사 전 상태 사진 기록",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2B2A27)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "나중에 스크래치 분쟁을 예방할 수 있도록 이사 전 상태를 촬영해 두세요.",
            style: TextStyle(color: Color(0xFF8A877F), fontSize: 13),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: _uploadedBeforePhotos.keys.map((category) {
                return _buildPhotoCard(category, _uploadedBeforePhotos[category]!, () {
                  if (_uploadedBeforePhotos[category]!) {
                    // Toggling off (removing photo)
                    setState(() {
                      _uploadedBeforePhotos[category] = false;
                      _customBeforeImageUrls[category] = null;
                    });
                  } else {
                    // Show Sample Angle and Guide Dialog
                    _showAngleGuideDialog(category);
                  }
                });
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canProceed
                  ? () {
                      // Find the first category that is uploaded to use as active matching target
                      String activeCat = _uploadedBeforePhotos.keys.firstWhere(
                        (k) => _uploadedBeforePhotos[k]!,
                        orElse: () => '거실 벽면',
                      );
                      setState(() {
                        _selectedCategory = activeCat;
                        _step = 2; // Go to Post-move match & scan (Step 2)
                      });
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2B2A27),
                disabledBackgroundColor: const Color(0xFFE2E4E8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text("이사 전 상태 기록 완료", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoCard(String category, bool isUploaded, VoidCallback onTap) {
    final customUrl = _customBeforeImageUrls[category];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUploaded ? const Color(0xFFE6007E) : const Color(0xFFE2E4E8),
          width: isUploaded ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          children: [
            if (isUploaded)
              Positioned.fill(
                child: Opacity(
                  opacity: 0.8,
                  child: customUrl != null
                      ? _buildImageWidget(customUrl, fit: BoxFit.cover)
                      : CustomPaint(
                          painter: RoomPainter(roomType: category, showDefect: false),
                        ),
                ),
              ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isUploaded
                              ? const Color(0xFFE6007E)
                              : const Color(0xFFF0F1F4),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isUploaded ? Icons.delete_outline : Icons.add_a_photo_outlined,
                          color: isUploaded ? Colors.white : const Color(0xFF8A877F),
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        category,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isUploaded ? "터치하여 삭제" : "예시 앵글 보기",
                        style: TextStyle(
                          fontSize: 11,
                          color: isUploaded ? const Color(0xFFE6007E) : const Color(0xFF8A877F),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Dialog showing Sample Angle Guide and Option to enter custom image URL (Gallery & Web Paste only, no camera)
  void _showAngleGuideDialog(String category) {
    final TextEditingController urlController = TextEditingController();
    String instructions = "";
    switch (category) {
      case "거실 벽면":
        instructions = "벽면의 수평을 맞추고, 바닥 몰딩 부분이 흐려지지 않게 밝은 조명 아래서 촬영해 주세요.";
        break;
      case "현관 도어":
        instructions = "문 전체의 외곽 프레임이 모두 뷰파인더 안에 들어오도록 현관 밖 1.5m 거리에서 촬영해 주세요.";
        break;
      case "다용도실 타일":
        instructions = "타일 줄눈의 수직/수평이 맞도록 위에서 아래 방향으로 비스듬히 촬영해 주세요.";
        break;
      case "거실 바닥재":
        instructions = "바닥 몰딩 및 모퉁이가 잘 보이도록 대각선 위 방향에서 바닥면을 평평하게 촬영해 주세요.";
        break;
    }

    setState(() {
      _isDialogOpen = true;
      _activeDialogCategory = category;
      _activeDialogImageTarget = 'before';
    });

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.camera_alt_outlined, color: Color(0xFFE6007E)),
                        const SizedBox(width: 8),
                        Text(
                          "$category 권장 촬영 가이드",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Large visual illustration of the correct angle
                    Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE2E4E8)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: CustomPaint(
                          size: const Size(double.infinity, 150),
                          painter: RoomPainter(roomType: category, showDefect: false),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      instructions,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF2B2A27), height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 10),
                    const Text(
                      "📷 사진 등록하기 (이사 전)",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF2B2A27)),
                    ),
                    const SizedBox(height: 8),
                    // Premium click / paste / drag-drop upload zone
                    GestureDetector(
                      onTap: () async {
                        final picker = ImagePicker();
                        final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                        if (image != null) {
                          setState(() {
                            _uploadedBeforePhotos[category] = true;
                            _customBeforeImageUrls[category] = image.path;
                          });
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F8FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE6007E).withOpacity(0.4),
                            style: BorderStyle.solid,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.cloud_upload_outlined, color: Color(0xFFE6007E), size: 28),
                            const SizedBox(height: 8),
                            const Text(
                              "여기를 클릭하여 사진 파일 선택",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2B2A27)),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "또는 이미지 복사 후 붙여넣기(Ctrl+V) / 파일 드래그앤드롭",
                              style: TextStyle(fontSize: 9, color: Color(0xFF8A877F)),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: urlController,
                      decoration: InputDecoration(
                        hintText: "또는 인터넷 이미지 URL 주소를 직접 입력",
                        hintStyle: const TextStyle(fontSize: 11),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("닫기", style: TextStyle(color: Color(0xFF8A877F))),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            if (urlController.text.trim().isNotEmpty) {
                              setState(() {
                                _uploadedBeforePhotos[category] = true;
                                _customBeforeImageUrls[category] = urlController.text.trim();
                              });
                            }
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE6007E),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            elevation: 0,
                          ),
                          child: const Text("등록 완료", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ).then((_) {
      setState(() {
        _isDialogOpen = false;
        _activeDialogCategory = null;
        _activeDialogImageTarget = null;
      });
    });
  }

  // Dialog showing Option to enter AFTER image details (gallery, copy-paste, drop, URL)
  void _showAfterUploadDialog(String category) {
    final TextEditingController urlController = TextEditingController();

    setState(() {
      _isDialogOpen = true;
      _activeDialogCategory = category;
      _activeDialogImageTarget = 'after';
    });

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.cloud_upload_outlined, color: Color(0xFFE6007E)),
                        const SizedBox(width: 8),
                        Text(
                          "$category 이사 후 사진 등록",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "가이드라인에 최대한 일치하는 각도의 사진을 선택해 주세요.",
                      style: TextStyle(fontSize: 11, color: Color(0xFF8A877F)),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () async {
                        final picker = ImagePicker();
                        final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                        if (image != null) {
                          setState(() {
                            _uploadedAfterPhotos[category] = true;
                            _customAfterImageUrls[category] = image.path;
                          });
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F8FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE6007E).withOpacity(0.4),
                            style: BorderStyle.solid,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.cloud_upload_outlined, color: Color(0xFFE6007E), size: 28),
                            const SizedBox(height: 8),
                            const Text(
                              "여기를 클릭하여 사진 파일 선택",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2B2A27)),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "또는 이미지 복사 후 붙여넣기(Ctrl+V) / 파일 드래그앤드롭",
                              style: TextStyle(fontSize: 9, color: Color(0xFF8A877F)),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: urlController,
                      decoration: InputDecoration(
                        hintText: "또는 인터넷 이미지 URL 주소를 직접 입력",
                        hintStyle: const TextStyle(fontSize: 11),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("닫기", style: TextStyle(color: Color(0xFF8A877F))),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            if (urlController.text.trim().isNotEmpty) {
                              setState(() {
                                _uploadedAfterPhotos[category] = true;
                                _customAfterImageUrls[category] = urlController.text.trim();
                              });
                            }
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE6007E),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            elevation: 0,
                          ),
                          child: const Text("등록 완료", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ).then((_) {
      setState(() {
        _isDialogOpen = false;
        _activeDialogCategory = null;
        _activeDialogImageTarget = null;
      });
    });
  }

  // STEP 1: Post-move matching shot screen (camera with transparent overlay)
  Widget _buildStepPostMoveGuide() {
    final hasBeforeImage = _customBeforeImageUrls[_selectedCategory] != null;
    final hasAfterImage = _customAfterImageUrls[_selectedCategory] != null;

    // Get list of categories that have before photos uploaded
    final uploadedBeforeCategories = _uploadedBeforePhotos.keys
        .where((k) => _uploadedBeforePhotos[k]!)
        .toList();

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6007E).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      "STEP 03",
                      style: TextStyle(
                        color: Color(0xFFE6007E),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "이사 후 매칭 및 대조 촬영",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2B2A27)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                "대조 촬영할 공간을 선택하고 이사 후 사진을 등록해 주세요:",
                style: TextStyle(color: Color(0xFF8A877F), fontSize: 12),
              ),
              const SizedBox(height: 8),
              // Category Choice Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: uploadedBeforeCategories.map((cat) {
                    bool selected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          cat,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: selected ? Colors.white : const Color(0xFF2B2A27),
                          ),
                        ),
                        selected: selected,
                        selectedColor: const Color(0xFFE6007E),
                        backgroundColor: const Color(0xFFF0F1F4),
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              _selectedCategory = cat;
                            });
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: Colors.black,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 1. Post-move "camera image"
                Positioned.fill(
                  child: hasAfterImage
                      ? _buildImageWidget(
                          _customAfterImageUrls[_selectedCategory]!,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: const Color(0xFF1E1E24),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.camera_alt_outlined, color: Colors.white38, size: 48),
                                const SizedBox(height: 12),
                                const Text(
                                  "이사 후 사진을 촬영하거나 등록해 주세요.",
                                  style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  "위 가이드에 따라 동일한 각도로 입력하시는 것이 정확합니다.",
                                  style: TextStyle(color: Colors.white30, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),

                // 2. Pre-move Ghost Overlay (No pink holographic color filter!)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: _overlayOpacity,
                      child: hasBeforeImage
                          ? _buildImageWidget(
                              _customBeforeImageUrls[_selectedCategory]!,
                              fit: BoxFit.cover,
                            )
                          : CustomPaint(
                              painter: RoomPainter(
                                  roomType: _selectedCategory,
                                  showDefect: false,
                                  isWireframe: true),
                            ),
                    ),
                  ),
                ),

                // 3. Camera crosshair grid lines
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Overlay Opacity Slider
                Positioned(
                  bottom: 150,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.opacity, color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        const Text(
                          "이전 가이드 투명도",
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        Expanded(
                          child: Slider(
                            value: _overlayOpacity,
                            onChanged: (val) {
                              setState(() {
                                _overlayOpacity = val;
                              });
                            },
                            min: 0.0,
                            max: 1.0,
                            activeColor: const Color(0xFFE6007E),
                            inactiveColor: Colors.white24,
                          ),
                        ),
                        Text(
                          "${(_overlayOpacity * 100).toInt()}%",
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
                ),

                // Upload & Control Buttons
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!hasAfterImage)
                        // Options to upload/capture after photo
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.camera_alt, size: 16),
                                  label: const Text("실시간 촬영", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  onPressed: () async {
                                    final picker = ImagePicker();
                                    final XFile? image = await picker.pickImage(source: ImageSource.camera);
                                    if (image != null) {
                                      setState(() {
                                        _uploadedAfterPhotos[_selectedCategory] = true;
                                        _customAfterImageUrls[_selectedCategory] = image.path;
                                      });
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFE6007E),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.photo_library, size: 16),
                                  label: const Text("갤러리/파일 등록", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  onPressed: () {
                                    _showAfterUploadDialog(_selectedCategory);
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: Colors.white54),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        // Actions when after photo is registered
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.replay, size: 16, color: Colors.white),
                              label: const Text("다시 촬영/등록", style: TextStyle(color: Colors.white, fontSize: 12)),
                              onPressed: () {
                                setState(() {
                                  _uploadedAfterPhotos[_selectedCategory] = false;
                                  _customAfterImageUrls[_selectedCategory] = null;
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white54),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                            const SizedBox(width: 16),
                            GestureDetector(
                              onTap: _triggerScan,
                              child: Container(
                                width: 70,
                                height: 70,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black38,
                                      blurRadius: 10,
                                    )
                                  ],
                                ),
                                child: Center(
                                  child: Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.black,
                                        width: 2,
                                      ),
                                    ),
                                    child: Center(
                                      child: Container(
                                        width: 52,
                                        height: 52,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFE6007E),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.search, color: Colors.white, size: 28),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 86), // Spacer to balance layout
                          ],
                        ),
                    ],
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                    onPressed: () {
                      setState(() {
                        _step = 1;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // STEP 2: Report dashboard screen
  Widget _buildStepAnalysisReport() {
    final scanned = _scannedCategories.keys.where((k) => _scannedCategories[k]!).toList();
    final uploadedBeforeCategories = _uploadedBeforePhotos.keys
        .where((k) => _uploadedBeforePhotos[k]!)
        .toList();
    final hasMoreToScan = uploadedBeforeCategories.length > scanned.length;

    int riskScore = _getDynamicOverallRiskScore();
    String riskLabel = "안심";
    Color riskColor = const Color(0xFF2B2A27);
    Color riskBg = const Color(0xFFF0F1F4);
    if (riskScore > 0) {
      if (riskScore >= 60) {
        riskLabel = "위험";
        riskColor = const Color(0xFFFF5A5F);
        riskBg = const Color(0xFFFFECEC);
      } else {
        riskLabel = "주의";
        riskColor = const Color(0xFFFF9500);
        riskBg = const Color(0xFFFFF4E5);
      }
    } else {
      riskLabel = "안전";
      riskColor = const Color(0xFF4CD964);
      riskBg = const Color(0xFFE8F9EC);
    }

    int defectCount = 0;
    for (var cat in scanned) {
      if ((_defectAnalyses[cat]?.similarity ?? 100.0) < 99.0) {
        defectCount++;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6007E).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  "STEP 04",
                  style: TextStyle(
                    color: Color(0xFFE6007E),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                "안심 리포트 완료",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2B2A27)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E4E8)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x05000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                )
              ],
            ),
            child: Column(
              children: [
                const Text(
                  "하자 위험도 지수",
                  style: TextStyle(color: Color(0xFF8A877F), fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: CircularProgressIndicator(
                        value: riskScore / 100.0,
                        strokeWidth: 8,
                        backgroundColor: riskBg,
                        color: riskColor,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "$riskScore점",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: riskColor,
                          ),
                        ),
                        Text(
                          riskLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: riskColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 10),
                Text(
                  scanned.isEmpty
                      ? "대조 분석된 항목이 없습니다."
                      : "이사 전/후 픽셀 대조 검사 결과\n총 $defectCount곳의 미세 스크래치 및 하자가 감지되었습니다.",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, height: 1.4),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // AI Weighted Verification Algorithm Info Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F7FB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E9F3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6007E).withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.insights_outlined, color: Color(0xFFE6007E), size: 16),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "AI 정밀 검증 및 가중치 알고리즘 안내",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF2B2A27),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  "단순 이미지 일치율(면적)만으로 하자를 진단할 경우, 넓은 벽지 오염이 좁은 미세 균열보다 높은 위험도로 오판될 수 있습니다. 이를 방지하기 위해 본 리포트는 하자 유형의 성격과 자재별 안전 중요도 가중치를 반영한 검증 알고리즘을 적용합니다.",
                  style: TextStyle(fontSize: 11, color: Color(0xFF6B6E75), height: 1.4),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFEAEDF1)),
                  ),
                  child: Column(
                    children: [
                      _buildAlgoWeightRow("하자 유형 가중치", "균열/파손 (9.0배) | 스크래치/긁힘 (4.5배) | 오염/얼룩 (1.5배)"),
                      const Divider(height: 16, thickness: 0.5, color: Color(0xFFEAEDF1)),
                      _buildAlgoWeightRow("안전 중요 가중치", "타일 (1.3배) | 벽면 (1.2배) | 바닥 (1.1배) | 도어 (1.0배)"),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 10, color: Color(0xFF8A877F), height: 1.3),
                    children: [
                      TextSpan(text: "※ 평가식: ", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE6007E))),
                      TextSpan(text: "최종 위험도 점수 = (유형 가중치 × 안전 가중치 × 8) + (차이 면적 % × 유형 가중치 × 0.4) [최대 100점]", style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "하자 정밀 분석 및 대조 내역",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2B2A27)),
          ),
          const SizedBox(height: 4),
          const Text(
            "항목을 선택하여 이전/이후 상세 대조 사진을 확인할 수 있습니다.",
            style: TextStyle(fontSize: 12, color: Color(0xFF8A877F)),
          ),
          const SizedBox(height: 12),
          if (scanned.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E4E8)),
              ),
              child: const Center(
                child: Text("대조 완료된 공간이 없습니다.", style: TextStyle(color: Color(0xFF8A877F))),
              ),
            )
          else
            Column(
              children: scanned.map((cat) {
                final analysis = _defectAnalyses[cat];
                return _buildCheckItem(
                  categoryName: cat,
                  analysis: analysis,
                );
              }).toList(),
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _step = 0;
                      _uploadedBeforePhotos.updateAll((key, value) => false);
                      _uploadedAfterPhotos.updateAll((key, value) => false);
                      _customBeforeImageUrls.updateAll((key, value) => null);
                      _customAfterImageUrls.updateAll((key, value) => null);
                      _scannedCategories.updateAll((key, value) => false);
                      _defectAnalyses.updateAll((key, value) => null);
                      _checklistState.updateAll((key, value) => [false, false, false]);
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2B2A27),
                    side: const BorderSide(color: Color(0xFFE2E4E8)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("처음으로 돌아가기"),
                ),
              ),
              const SizedBox(width: 12),
              if (hasMoreToScan)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      String nextCat = uploadedBeforeCategories.firstWhere(
                        (c) => !_scannedCategories[c]!,
                        orElse: () => uploadedBeforeCategories.first,
                      );
                      setState(() {
                        _selectedCategory = nextCat;
                        _step = 2; // Go to Post-move match & scan (Step 3)
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE6007E),
                      side: const BorderSide(color: Color(0xFFE6007E)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("다른 공간 추가 분석"),
                  ),
                )
              else
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("이삿짐업체 제출용 하자 대조 증빙 리포트 및 해결 신청이 접수되었습니다. (접수 번호: MOVE-IN-UC05-8291)"),
                          backgroundColor: Color(0xFFE6007E),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE6007E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text("이사 분쟁 조정 및 AS 접수", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildCheckItem({
    required String categoryName,
    required DefectAnalysis? analysis,
  }) {
    if (analysis == null) return const SizedBox.shrink();
    bool isNormal = analysis.similarity >= 99.0;
    
    // Determine risk level color for badge
    Color badgeColor = const Color(0xFF4CD964); // normal
    if (!isNormal) {
      if (analysis.riskScore >= 60.0) {
        badgeColor = const Color(0xFFFF5A5F); // warning
      } else {
        badgeColor = const Color(0xFFFF9500); // caution
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E4E8)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              _showCompareDialog(categoryName, analysis);
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      isNormal ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                      color: badgeColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                analysis.title,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2B2A27)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Risk level badge
                            if (!isNormal)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: badgeColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  "${analysis.defectType} (가중치 ${analysis.severityWeight})",
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: badgeColor,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          analysis.description,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF8A877F), height: 1.4),
                        ),
                        if (!isNormal) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                "차이 면적: ${analysis.discrepancyArea.toStringAsFixed(1)}%",
                                style: const TextStyle(fontSize: 10, color: Color(0xFF8A877F)),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                "위험도 점수: ${analysis.riskScore.toStringAsFixed(1)}점",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: badgeColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Align(
                    alignment: Alignment.center,
                    child: Icon(Icons.chevron_right, color: Color(0xFF8A877F), size: 20),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Dialog showing before/after split screen with pulsing defect beacon (using actual before and after images)
  void _showCompareDialog(String category, DefectAnalysis analysis) {
    final beforeUrl = _customBeforeImageUrls[category];
    final afterUrl = _customAfterImageUrls[category];
    final isNormal = analysis.similarity >= 99.0;

    showDialog(
      context: context,
      builder: (context) {
        // Determine risk level color
        Color riskColor = const Color(0xFF4CD964);
        if (!isNormal) {
          riskColor = analysis.riskScore >= 60.0 ? const Color(0xFFFF5A5F) : const Color(0xFFFF9500);
        }

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    analysis.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // Before Image
                      Expanded(
                        child: Column(
                          children: [
                            const Text("이사 전 (Before)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF8A877F))),
                            const SizedBox(height: 8),
                            Container(
                              height: 150,
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFFE2E4E8)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(7),
                                child: beforeUrl != null
                                    ? _buildImageWidget(beforeUrl, fit: BoxFit.cover)
                                    : CustomPaint(
                                        size: const Size(double.infinity, 150),
                                        painter: RoomPainter(roomType: category, showDefect: false),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // After Image (with defect & pulsing beacon if not normal)
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              "이사 후 (After)",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: riskColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 150,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isNormal ? const Color(0xFFE8F9EC) : (analysis.riskScore >= 60.0 ? const Color(0xFFFFECEC) : const Color(0xFFFFF4E5)),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(7),
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: afterUrl != null
                                          ? Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                _buildImageWidget(afterUrl, fit: BoxFit.cover),
                                                if (!isNormal)
                                                  CustomPaint(
                                                    painter: DefectOverlayPainter(roomType: category),
                                                  ),
                                              ],
                                            )
                                          : CustomPaint(
                                              painter: RoomPainter(roomType: category, showDefect: !isNormal),
                                            ),
                                    ),
                                    if (!isNormal)
                                      const Positioned.fill(
                                        child: IgnorePointer(
                                          child: PulsingBeaconWidget(),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    analysis.description,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF8A877F), height: 1.4),
                  ),
                  if (!isNormal) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: riskColor.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: riskColor.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.calculate_outlined,
                                color: riskColor,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "AI 위험도 점수 검증 세부 산정 내역",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: riskColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildDetailScoreRow(
                            "하자 유형 가중치",
                            "${analysis.defectType} (${analysis.defectType == '균열/파손' ? '9.0' : (analysis.defectType == '스크래치/긁힘' ? '4.5' : '1.5')}배)",
                            riskColor,
                          ),
                          _buildDetailScoreRow(
                            "자재 중요도 가중치",
                            "${analysis.category} (${analysis.category == '다용도실 타일' ? '1.3' : (analysis.category == '거실 벽면' ? '1.2' : (analysis.category == '거실 바닥재' ? '1.1' : '1.0'))}배)",
                            riskColor,
                          ),
                          _buildDetailScoreRow(
                            "결함 차이 면적 비율",
                            "${analysis.discrepancyArea.toStringAsFixed(1)}% (영향 가중율 ×0.4)",
                            riskColor,
                          ),
                          const Divider(height: 12, thickness: 0.5),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "종합 위험도 점수 (Weighted Risk)",
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: riskColor),
                              ),
                              Text(
                                "${analysis.riskScore.toStringAsFixed(1)}점 / 100점",
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: riskColor),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("확인", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE6007E))),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAlgoWeightRow(String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            title,
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF2B2A27)),
          ),
        ),
        Expanded(
          child: Text(
            desc,
            style: const TextStyle(fontSize: 10, color: Color(0xFF6B6E75)),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailScoreRow(String label, String value, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.85)),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textColor),
          ),
        ],
      ),
    );
  }

  // Get dynamic overall risk score (average riskScore of scanned categories)
  int _getDynamicOverallRiskScore() {
    final scanned = _scannedCategories.keys.where((k) => _scannedCategories[k]!).toList();
    if (scanned.isEmpty) return 0;
    double totalRisk = 0.0;
    int count = 0;
    for (var cat in scanned) {
      totalRisk += _defectAnalyses[cat]?.riskScore ?? 0.0;
      count++;
    }
    double avgRisk = totalRisk / count;
    return avgRisk.clamp(0.0, 100.0).toInt();
  }
}

// Custom painter to draw room sketches and defect lines dynamically
class RoomPainter extends CustomPainter {
  final String roomType;
  final bool showDefect;
  final bool isWireframe;

  RoomPainter({
    required this.roomType,
    this.showDefect = false,
    this.isWireframe = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    if (!isWireframe) {
      // Draw background
      paint.style = PaintingStyle.fill;
      paint.color = const Color(0xFFF7F8FA);
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    }

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = const Color(0xFFB0AEB9); // Neutral guide wireframe (gray)

    final fillPaint = Paint()..style = PaintingStyle.fill;

    if (roomType == '거실 벽면') {
      if (!isWireframe) {
        // Wall background (Soft warm grey)
        fillPaint.color = const Color(0xFFEFECE7);
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), fillPaint);

        // Bottom skirting moulding
        fillPaint.color = const Color(0xFFD7CFC7);
        canvas.drawRect(Rect.fromLTWH(0, size.height - 20, size.width, 20), fillPaint);

        // TV Frame on wall
        fillPaint.color = const Color(0xFF333333);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(size.width / 2, size.height / 2 - 10),
              width: size.width * 0.65,
              height: size.height * 0.45,
            ),
            const Radius.circular(8),
          ),
          fillPaint,
        );

        // TV Screen reflection accent
        fillPaint.color = const Color(0xFF444444);
        final reflection = Path()
          ..moveTo(size.width / 2 - size.width * 0.325 + 5, size.height / 2 - 10 - size.height * 0.225 + 5)
          ..lineTo(size.width / 2 + size.width * 0.325 - 5, size.height / 2 - 10 - size.height * 0.225 + 5)
          ..lineTo(size.width / 2 - size.width * 0.1, size.height / 2 - 10 + size.height * 0.225 - 5)
          ..close();
        canvas.drawPath(reflection, fillPaint);
      } else {
        // Draw wireframe outlines only
        // Skirting line
        canvas.drawLine(Offset(0, size.height - 20), Offset(size.width, size.height - 20), strokePaint);
        // TV outline
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(size.width / 2, size.height / 2 - 10),
              width: size.width * 0.65,
              height: size.height * 0.45,
            ),
            const Radius.circular(8),
          ),
          strokePaint,
        );
      }

      if (showDefect) {
        // Red scratch on the bottom molding
        final defectPaint = Paint()
          ..color = const Color(0xFFFF5A5F)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        final path = Path()
          ..moveTo(size.width * 0.35, size.height - 13)
          ..lineTo(size.width * 0.45, size.height - 6)
          ..lineTo(size.width * 0.55, size.height - 11);
        canvas.drawPath(path, defectPaint);
      }
    } else if (roomType == '현관 도어') {
      if (!isWireframe) {
        // Door frame
        fillPaint.color = const Color(0xFF4E5968);
        canvas.drawRect(Rect.fromLTWH(15, 15, size.width - 30, size.height - 15), fillPaint);

        // Door surface (Modern Navy)
        fillPaint.color = const Color(0xFF2B3A55);
        canvas.drawRect(Rect.fromLTWH(20, 20, size.width - 40, size.height - 20), fillPaint);

        // Doorknob lock plate
        fillPaint.color = const Color(0xFF1E2638);
        canvas.drawRect(
          Rect.fromLTWH(size.width - 45, size.height / 2 - 25, 12, 45),
          fillPaint,
        );

        // Door lever handle
        fillPaint.color = const Color(0xFFC5A880); // Gold bronze
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width - 55, size.height / 2 - 5, 20, 10),
            const Radius.circular(2),
          ),
          fillPaint,
        );
      } else {
        // Wireframe outlines only
        canvas.drawRect(Rect.fromLTWH(20, 20, size.width - 40, size.height - 20), strokePaint);
        canvas.drawRect(Rect.fromLTWH(size.width - 45, size.height / 2 - 25, 12, 45), strokePaint);
      }

      if (showDefect) {
        // Red scratch around doorknob
        final defectPaint = Paint()
          ..color = const Color(0xFFFF5A5F)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        canvas.drawArc(
          Rect.fromCircle(center: Offset(size.width - 40, size.height / 2 - 15), radius: 10),
          0,
          3.14,
          false,
          defectPaint,
        );
      }
    } else if (roomType == '다용도실 타일') {
      if (!isWireframe) {
        // Tiles background (Light warm grey)
        fillPaint.color = const Color(0xFFE2E6EA);
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), fillPaint);

        // Grout lines
        paint.color = Colors.white;
        paint.style = PaintingStyle.stroke;
        paint.strokeWidth = 2.5;

        // Draw grid
        for (double i = 0; i <= size.width; i += size.width / 3) {
          canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
        }
        for (double j = 0; j <= size.height; j += size.height / 3) {
          canvas.drawLine(Offset(0, j), Offset(size.width, j), paint);
        }
      } else {
        // Wireframe grid lines
        for (double i = 0; i <= size.width; i += size.width / 3) {
          canvas.drawLine(Offset(i, 0), Offset(i, size.height), strokePaint);
        }
        for (double j = 0; j <= size.height; j += size.height / 3) {
          canvas.drawLine(Offset(0, j), Offset(size.width, j), strokePaint);
        }
      }

      if (showDefect) {
        // Red crack line in tiles
        final defectPaint = Paint()
          ..color = const Color(0xFFFF5A5F)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        final path = Path()
          ..moveTo(size.width * 0.45, size.height * 0.4)
          ..lineTo(size.width * 0.52, size.height * 0.52)
          ..lineTo(size.width * 0.48, size.height * 0.65);
        canvas.drawPath(path, defectPaint);
      }
    } else if (roomType == '거실 바닥재') {
      if (!isWireframe) {
        // Wood floorboard background (Warm light brown)
        fillPaint.color = const Color(0xFFEAD8C3);
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), fillPaint);

        // Floor joint lines (Brown)
        paint.color = const Color(0xFFC8B39B);
        paint.style = PaintingStyle.stroke;
        paint.strokeWidth = 1.0;

        // Draw horizontal planks
        double plankHeight = size.height / 4;
        for (int i = 1; i < 4; i++) {
          double y = i * plankHeight;
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }

        // Draw vertical joint dividers (staggered)
        // Row 1
        canvas.drawLine(Offset(size.width * 0.25, 0), Offset(size.width * 0.25, plankHeight), paint);
        canvas.drawLine(Offset(size.width * 0.75, 0), Offset(size.width * 0.75, plankHeight), paint);
        // Row 2
        canvas.drawLine(Offset(size.width * 0.45, plankHeight), Offset(size.width * 0.45, plankHeight * 2), paint);
        canvas.drawLine(Offset(size.width * 0.9, plankHeight), Offset(size.width * 0.9, plankHeight * 2), paint);
        // Row 3
        canvas.drawLine(Offset(size.width * 0.15, plankHeight * 2), Offset(size.width * 0.15, plankHeight * 3), paint);
        canvas.drawLine(Offset(size.width * 0.6, plankHeight * 2), Offset(size.width * 0.6, plankHeight * 3), paint);
        // Row 4
        canvas.drawLine(Offset(size.width * 0.35, plankHeight * 3), Offset(size.width * 0.35, size.height), paint);
        canvas.drawLine(Offset(size.width * 0.8, plankHeight * 3), Offset(size.width * 0.8, size.height), paint);
      } else {
        // Wireframe outlines only
        double plankHeight = size.height / 4;
        for (int i = 1; i < 4; i++) {
          double y = i * plankHeight;
          canvas.drawLine(Offset(0, y), Offset(size.width, y), strokePaint);
        }
        canvas.drawLine(Offset(size.width * 0.25, 0), Offset(size.width * 0.25, plankHeight), strokePaint);
        canvas.drawLine(Offset(size.width * 0.75, 0), Offset(size.width * 0.75, plankHeight), strokePaint);
        canvas.drawLine(Offset(size.width * 0.45, plankHeight), Offset(size.width * 0.45, plankHeight * 2), strokePaint);
        canvas.drawLine(Offset(size.width * 0.9, plankHeight), Offset(size.width * 0.9, plankHeight * 2), strokePaint);
      }

      if (showDefect) {
        // Red deep scratch on floorboards
        final defectPaint = Paint()
          ..color = const Color(0xFFFF5A5F)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        final path = Path()
          ..moveTo(size.width * 0.25, size.height * 0.45)
          ..lineTo(size.width * 0.45, size.height * 0.55)
          ..lineTo(size.width * 0.75, size.height * 0.50);
        canvas.drawPath(path, defectPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Separate painter to draw red defects on top of custom network images
class DefectOverlayPainter extends CustomPainter {
  final String roomType;

  DefectOverlayPainter({required this.roomType});

  @override
  void paint(Canvas canvas, Size size) {
    final defectPaint = Paint()
      ..color = const Color(0xFFFF5A5F)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (roomType == '거실 벽면') {
      final path = Path()
        ..moveTo(size.width * 0.35, size.height - 13)
        ..lineTo(size.width * 0.45, size.height - 6)
        ..lineTo(size.width * 0.55, size.height - 11);
      canvas.drawPath(path, defectPaint);
    } else if (roomType == '현관 도어') {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(size.width - 40, size.height / 2 - 15), radius: 10),
        0,
        3.14,
        false,
        defectPaint,
      );
    } else if (roomType == '다용도실 타일') {
      final path = Path()
        ..moveTo(size.width * 0.45, size.height * 0.4)
        ..lineTo(size.width * 0.52, size.height * 0.52)
        ..lineTo(size.width * 0.48, size.height * 0.65);
      canvas.drawPath(path, defectPaint);
    } else if (roomType == '거실 바닥재') {
      final path = Path()
        ..moveTo(size.width * 0.25, size.height * 0.45)
        ..lineTo(size.width * 0.45, size.height * 0.55)
        ..lineTo(size.width * 0.75, size.height * 0.50);
      canvas.drawPath(path, defectPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Pulse beacon widget for highlighting defects in comparisons
class PulsingBeaconWidget extends StatefulWidget {
  const PulsingBeaconWidget({super.key});

  @override
  State<PulsingBeaconWidget> createState() => _PulsingBeaconWidgetState();
}

class _PulsingBeaconWidgetState extends State<PulsingBeaconWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 32 * _controller.value,
                height: 32 * _controller.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF5A5F).withOpacity(1.0 - _controller.value),
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFFF5A5F),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Data model for structural defect analysis
class DefectAnalysis {
  final String category;
  final String defectType; // '오염/얼룩', '스크래치/긁힘', '균열/파손', '없음'
  final double discrepancyArea; // 면적 차이율 (0.0 ~ 100.0)
  final double severityWeight; // 심각도 가중치 (1.0 ~ 10.0)
  final double similarity; // 일치율 (0.0 ~ 100.0)
  final double riskScore; // 최종 하자 위험도 점수 (0 ~ 100)
  final String title;
  final String description;

  DefectAnalysis({
    required this.category,
    required this.defectType,
    required this.discrepancyArea,
    required this.severityWeight,
    required this.similarity,
    required this.riskScore,
    required this.title,
    required this.description,
  });
}
