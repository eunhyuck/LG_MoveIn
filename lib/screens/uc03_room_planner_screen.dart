import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/web_3d_viewer.dart';

class HexColor {
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    try {
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (e) {
      return Colors.grey;
    }
  }
}

class RoomElement {
  final String id;
  final String name;
  final bool isLG;
  // 3D coordinates relative to room center (range: -100 to 100)
  double x;
  double y; // vertical height coordinate
  double z;
  double dx; // width (X span)
  double dy; // height (Y span)
  double dz; // length (Z span)
  final Color color;
  final String? layoutType;
  final String? primaryColorHex;
  final String? secondaryColorHex;
  final bool hasDisplayScreen;
  final int panelCount;
  final String? frontImage;
  final String? sideImage;
  final bool isWall;

  RoomElement({
    required this.id,
    required this.name,
    required this.isLG,
    required this.x,
    required this.y,
    required this.z,
    required this.dx,
    required this.dy,
    required this.dz,
    required this.color,
    this.layoutType,
    this.primaryColorHex,
    this.secondaryColorHex,
    this.hasDisplayScreen = false,
    this.panelCount = 1,
    this.frontImage,
    this.sideImage,
    this.isWall = false,
  });

  RoomElement copyWith({double? x, double? z}) {
    return RoomElement(
      id: id,
      name: name,
      isLG: isLG,
      x: x ?? this.x,
      y: y,
      z: z ?? this.z,
      dx: dx,
      dy: dy,
      dz: dz,
      color: color,
      layoutType: layoutType,
      primaryColorHex: primaryColorHex,
      secondaryColorHex: secondaryColorHex,
      hasDisplayScreen: hasDisplayScreen,
      panelCount: panelCount,
      frontImage: frontImage,
      sideImage: sideImage,
      isWall: isWall,
    );
  }
}

class UC03RoomPlannerScreen extends StatefulWidget {
  const UC03RoomPlannerScreen({super.key});

  @override
  State<UC03RoomPlannerScreen> createState() => _UC03RoomPlannerScreenState();
}

class _UC03RoomPlannerScreenState extends State<UC03RoomPlannerScreen>
    with TickerProviderStateMixin {
  int _step = 0;
  String _areaSize = "114㎡ (34평)";
  String _roomLayout = "방 4 · 거실 1 · 욕실 2";
  String _lifestyle = "신혼";
  String _mood = "우드톤";
  bool _isAnalyzing = false;

  // Interactive states
  List<RoomElement> _roomElements = [];
  String? _selectedElementId;
  int _viewMode3D = 0; // 0: Room Layout, 1: Product 3D Detail
  int _selectedProduct3DIndex = 0;
  late TabController _tabController;

  Map<String, List<dynamic>> _productsDatabase = {};
  bool _isLoadingProducts = true;
  final Map<String, ui.Image> _loadedImages = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _loadProductsJson();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProductsJson() async {
    try {
      final String jsonStr = await rootBundle.loadString(
        'assets/data/products.json',
      );
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      final parsedDatabase = data.map(
        (key, value) => MapEntry(key, List<dynamic>.from(value)),
      );

      setState(() {
        _productsDatabase = parsedDatabase;
        _isLoadingProducts = false;
      });

      // Load images asynchronously in background and trigger state update as they load
      for (final category in parsedDatabase.keys) {
        for (final item in parsedDatabase[category]!) {
          final String? frontImg = item["front_image"];
          final String? sideImg = item["side_image"];
          if (frontImg != null) {
            _loadImage(frontImg)
                .then((img) {
                  setState(() {
                    _loadedImages[frontImg] = img;
                  });
                })
                .catchError((e) {
                  debugPrint("Failed to load front image $frontImg: $e");
                });
          }
          if (sideImg != null) {
            _loadImage(sideImg)
                .then((img) {
                  setState(() {
                    _loadedImages[sideImg] = img;
                  });
                })
                .catchError((e) {
                  debugPrint("Failed to load side image $sideImg: $e");
                });
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading products.json: $e");
      setState(() {
        _isLoadingProducts = false;
      });
    }
    _generateLayout();
  }

  Future<ui.Image> _loadImage(String assetPath) async {
    final ByteData data = await rootBundle.load(assetPath);
    final ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
    );
    final ui.FrameInfo fi = await codec.getNextFrame();
    return fi.image;
  }

  RoomElement _createLGElement(
    String id,
    String category,
    int index,
    double x,
    double y,
    double z,
  ) {
    if (_productsDatabase.containsKey(category) &&
        _productsDatabase[category]!.length > index) {
      final item = _productsDatabase[category]![index];
      final specs = item["visual_specs"] ?? {};
      final String name = item["name"] ?? "LG 가전";
      final double width = (item["width_mm"] ?? 900) / 10.0; // convert to cm
      final double height = (item["height_mm"] ?? 1800) / 10.0;
      final double depth = (item["depth_mm"] ?? 800) / 10.0;

      // Smart category-based fallbacks for failed/timed out VLM requests
      String defaultLayout = "single-door";
      String defaultPrimary = "#D2D2D2";
      String defaultSecondary = "#5F5D58";
      bool defaultScreen = false;

      if (category == "refrigerators") {
        defaultLayout = "4-door";
        defaultPrimary = "#F8F6F5";
        defaultSecondary = "#000000";
      } else if (category == "washers" || category == "dryers") {
        defaultLayout = "front-load";
        defaultPrimary = "#7F8782"; // Tromm steel-grey
        defaultSecondary = "#1A1C1E";
        defaultScreen = true;
      } else if (category == "air-conditioners") {
        defaultLayout = "stand";
        defaultPrimary = "#FFFFFF";
      }

      final layoutType =
          (specs["layout_type"] == "single-door" ||
              specs["layout_type"] == null)
          ? defaultLayout
          : specs["layout_type"];

      final pColor =
          (specs["primary_color_hex"] == "#D2D2D2" ||
              specs["primary_color_hex"] == null)
          ? defaultPrimary
          : specs["primary_color_hex"];

      final sColor =
          (specs["secondary_color_hex"] == "#5F5D58" ||
              specs["secondary_color_hex"] == null)
          ? defaultSecondary
          : specs["secondary_color_hex"];

      final hasScreen = specs["has_display_screen"] ?? defaultScreen;

      return RoomElement(
        id: id,
        name: name,
        isLG: true,
        x: x,
        y: y,
        z: z,
        dx: width,
        dy: height,
        dz: depth,
        color: HexColor.fromHex(pColor),
        layoutType: layoutType,
        primaryColorHex: pColor,
        secondaryColorHex: sColor,
        hasDisplayScreen: hasScreen,
        panelCount: specs["panel_count"] ?? 1,
        frontImage: item["front_image"],
        sideImage: item["side_image"],
      );
    }
    // Fallbacks if database is completely empty
    if (category == "refrigerators") {
      return RoomElement(
        id: id,
        name: "LG 냉장고 (M876)",
        isLG: true,
        x: x,
        y: y,
        z: z,
        dx: 91.4,
        dy: 186.0,
        dz: 91.8,
        color: const Color(0xFF27AE60),
      );
    } else if (category == "washers") {
      return RoomElement(
        id: id,
        name: "LG 세탁기 (T19O)",
        isLG: true,
        x: x,
        y: y,
        z: z,
        dx: 65.1,
        dy: 106.0,
        dz: 68.0,
        color: const Color(0xFFE6007E),
      );
    } else if (category == "air-conditioners") {
      return RoomElement(
        id: id,
        name: "LG 에어컨 (SQ06)",
        isLG: true,
        x: x,
        y: y,
        z: z,
        dx: 75.4,
        dy: 30.8,
        dz: 18.9,
        color: const Color(0xFF2F80ED),
      );
    } else {
      return RoomElement(
        id: id,
        name: "LG 건조기 (RG20)",
        isLG: true,
        x: x,
        y: y,
        z: z,
        dx: 70.0,
        dy: 99.0,
        dz: 82.0,
        color: const Color(0xFF9B51E0),
      );
    }
  }

  void _generateLayout() {
    final List<RoomElement> list = [];

    if (_areaSize.contains('25평') || _areaSize.contains('84㎡')) {
      if (_lifestyle == "신혼") {
        list.addAll([
          _createLGElement("tv", "air-conditioners", 0, 52.0, 30, -50.0), // 거실 (Living Room) 좌측 벽면
          _createLGElement("fridge", "refrigerators", 0, 80.0, 0, 65.0), // 주방 (Kitchen) 하단 우측
          _createLGElement("wash", "washers", 3, 70.0, 0, -88.0), // 발코니 (Balcony) 상단 우측
        ]);
      } else if (_lifestyle == "반려동반") {
        list.addAll([
          _createLGElement("pet_purifier", "air-conditioners", 1, 70.0, 0, -40.0), // 거실 중앙
          _createLGElement("tv", "refrigerators", 1, 52.0, 0, -50.0), // 거실 벽면
          _createLGElement("wash", "washers", 0, 70.0, 0, -88.0), // 발코니
        ]);
      } else if (_lifestyle == "재택근무") {
        list.addAll([
          _createLGElement("monitor", "air-conditioners", 2, -15.0, 0, 50.0), // 침실2 (Bedroom 2) 서재
          _createLGElement("standbyme", "dryers", 0, -50.0, 0, -50.0), // 안방 (Master Bed) 침대 옆
          _createLGElement("tv", "refrigerators", 2, 52.0, 0, -50.0), // 거실 벽면
        ]);
      } else {
        // 1인 미니멀
        list.addAll([
          _createLGElement("aerotower", "air-conditioners", 3, 70.0, 0, -30.0), // 거실 코너
          _createLGElement("tv", "refrigerators", 3, 52.0, 0, -50.0), // 거실 벽면
          _createLGElement("fridge", "refrigerators", 4, 80.0, 0, 65.0), // 주방
        ]);
      }
    } else if (_areaSize.contains('18평') || _areaSize.contains('59㎡')) {
      if (_lifestyle == "신혼") {
        list.addAll([
          _createLGElement("tv", "air-conditioners", 0, -10.0, 30, 50.0),
          _createLGElement("fridge", "refrigerators", 0, 40.0, 0, -50.0),
          _createLGElement("wash", "washers", 3, -50.0, 0, -50.0),
        ]);
      } else {
        list.addAll([
          _createLGElement("tv", "refrigerators", 1, -10.0, 0, 50.0),
          _createLGElement("wash", "washers", 0, -50.0, 0, -50.0),
        ]);
      }
    } else {
      // 34평 (실측 설계도 real_blueprint.png 기준 매핑)
      if (_lifestyle == "신혼") {
        list.addAll([
          _createLGElement("tv", "air-conditioners", 0, -22.0, 30, 30.0), // 거실 (Living Room) 좌측 경계벽
          _createLGElement("fridge", "refrigerators", 0, -15.0, 0, -50.0), // 주방 (Kitchen) 냉장고 홈
          _createLGElement("wash", "washers", 3, -70.0, 0, -95.0), // 발코니 (Balcony) 상단 좌측 세탁실
        ]);
      } else {
        list.addAll([
          _createLGElement("tv", "refrigerators", 1, -22.0, 0, 30.0), // 거실 벽면
          _createLGElement("wash", "washers", 0, -70.0, 0, -95.0), // 발코니 세탁실
        ]);
      }
    }

    setState(() {
      _roomElements = list;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI 룸 플래너 (UC-03)"),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2B2A27),
        elevation: 0,
      ),
      body: _isLoadingProducts
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE6007E)),
            )
          : _buildPlannerStep(),
    );
  }

  Widget _buildPlannerStep() {
    if (_isAnalyzing) {
      return _buildAnalyzingScreen();
    }
    switch (_step) {
      case 0:
        return _buildStepUploadBlueprint();
      case 1:
        return _buildStepLifestyleAndMood();
      case 2:
        return _buildStepPlannerResult();
      default:
        return Container();
    }
  }

  Widget _buildStepUploadBlueprint() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "1/3. 도면 및 기본 정보 등록",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("전용 면적"),
              DropdownButton<String>(
                value: _areaSize,
                items: ["59㎡ (18평)", "84㎡ (25평)", "114㎡ (34평)"].map((val) {
                  return DropdownMenuItem(value: val, child: Text(val));
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _areaSize = val;
                      _generateLayout();
                    });
                  }
                },
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("방 구조"),
              DropdownButton<String>(
                value: _roomLayout,
                items:
                    [
                      "방 2 · 거실 1 · 욕실 1",
                      "방 3 · 거실 1 · 욕실 2",
                      "방 4 · 거실 1 · 욕실 2",
                    ].map((val) {
                      return DropdownMenuItem(value: val, child: Text(val));
                    }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _roomLayout = val;
                      _generateLayout();
                    });
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: InkWell(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("도면 파일이 성공적으로 모의 업로드되었습니다.")),
                );
              },
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E4E8), width: 1),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.file_upload_outlined,
                      size: 48,
                      color: Color(0xFF8A877F),
                    ),
                    SizedBox(height: 12),
                    Text(
                      "도면 이미지 업로드",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "탭하여 파일 선택 또는 이미지 끌어놓기",
                      style: TextStyle(fontSize: 12, color: Color(0xFF8A877F)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => setState(() => _step = 1),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2B2A27),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "다음 단계",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepLifestyleAndMood() {
    final lifestyles = ["신혼", "1인 미니멀", "재택근무", "반려동반"];
    final moods = ["우드톤", "미드센추리", "미니멀", "Cozy"];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "2/3. 라이프스타일 및 추구 무드",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          const Text(
            "라이프스타일",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF5F5D58),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: lifestyles.map((item) {
              final isSel = _lifestyle == item;
              return ChoiceChip(
                label: Text(item),
                selected: isSel,
                onSelected: (sel) {
                  if (sel) {
                    setState(() {
                      _lifestyle = item;
                      _generateLayout();
                    });
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Text(
            "추구 무드 (인테리어)",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF5F5D58),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: moods.map((item) {
              final isSel = _mood == item;
              return ChoiceChip(
                label: Text(item),
                selected: isSel,
                onSelected: (sel) {
                  if (sel) {
                    setState(() {
                      _mood = item;
                      _generateLayout();
                    });
                  }
                },
              );
            }).toList(),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _isAnalyzing = true;
                });
                Timer(const Duration(seconds: 2), () {
                  setState(() {
                    _isAnalyzing = false;
                    _step = 2;
                  });
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE6007E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "✦ 배치 생성하기",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzingScreen() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFFE6007E)),
          SizedBox(height: 24),
          Text(
            "✦ AI Agent 분석 중...",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFFE6007E),
            ),
          ),
          SizedBox(height: 8),
          Text(
            "새 집의 도면을 해석하고 동선을 최적화하고 있어요.\n가장 잘 어울리는 LG 가전 스펙과 가구를 매칭 중입니다.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF5F5D58), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildStepPlannerResult() {
    final selectedAppliance = _selectedElementId != null
        ? _roomElements.firstWhere(
            (e) => e.id == _selectedElementId,
            orElse: () => _roomElements[0],
          )
        : null;

    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFFE6007E),
            unselectedLabelColor: const Color(0xFF8A877F),
            indicatorColor: const Color(0xFFE6007E),
            tabs: const [
              Tab(text: "2D 평면도 배치 및 이동"),
              Tab(text: "3D 입체 회전 프리뷰"),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _build2DBlueprintView(selectedAppliance),
              _build3DInteractiveView(),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("현재 가전 배치 시안이 마이페이지에 저장되었습니다."),
                      ),
                    );
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2B2A27),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "이 배치 저장하기",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _build2DBlueprintView(RoomElement? selectedAppliance) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.info_outline,
                size: 14,
                color: Color(0xFF8A877F),
              ),
              const SizedBox(width: 4),
              const Text(
                "팁: 가전을 직접 드래그앤드롭하여 재배치해 보세요!",
                style: TextStyle(fontSize: 11, color: Color(0xFF8A877F)),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E4E8)),
                image: DecorationImage(
                  image: AssetImage(
                    _areaSize.contains('18평')
                        ? 'assets/images/blueprints/blueprint_18.png'
                        : _areaSize.contains('34평')
                            ? 'assets/images/blueprints/blueprint_34.png'
                            : 'assets/images/blueprints/blueprint_25.png',
                  ),
                  fit: BoxFit.contain,
                ),
              ),
              child: AspectRatio(
                aspectRatio: 1.0,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      onPanDown: (details) {
                        final boxX = details.localPosition.dx;
                        final boxY = details.localPosition.dy;
                        _findSelectedAppliance(
                          boxX,
                          boxY,
                          constraints.maxWidth,
                          constraints.maxHeight,
                        );
                      },
                      onPanUpdate: (details) {
                        if (_selectedElementId != null) {
                          _updateAppliancePosition(
                            details.localPosition.dx,
                            details.localPosition.dy,
                            constraints.maxWidth,
                            constraints.maxHeight,
                          );
                        }
                      },
                      onPanEnd: (details) {},
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: InteractiveBlueprintPainter(
                          elements: _roomElements,
                          selectedId: _selectedElementId,
                          areaSize: _areaSize,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        if (selectedAppliance != null && selectedAppliance.isLG)
          _buildApplianceDetailCard(selectedAppliance)
        else
          Expanded(child: _buildApplianceListView()),
      ],
    );
  }

  Widget _buildApplianceDetailCard(RoomElement appliance) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6007E), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: appliance.frontImage != null
                ? Image.asset(
                    appliance.frontImage!,
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 90,
                      height: 90,
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  )
                : Container(
                    width: 90,
                    height: 90,
                    color: Colors.grey[200],
                    child: const Icon(
                      Icons.settings_remote,
                      color: Color(0xFFE6007E),
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6007E).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        "LG ThinQ",
                        style: TextStyle(
                          color: Color(0xFFE6007E),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(
                        Icons.close,
                        size: 16,
                        color: Color(0xFF8A877F),
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedElementId = null;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  appliance.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF2B2A27),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  "실측 치수: ${appliance.dx.toInt()} x ${appliance.dy.toInt()} x ${elementDepth(appliance)} cm",
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE6007E),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Text(
                      "AI 분석 스펙: ",
                      style: TextStyle(fontSize: 10, color: Color(0xFF8A877F)),
                    ),
                    if (appliance.primaryColorHex != null)
                      _colorChip(appliance.primaryColorHex!, "메인"),
                    if (appliance.secondaryColorHex != null)
                      const SizedBox(width: 4),
                    if (appliance.secondaryColorHex != null)
                      _colorChip(appliance.secondaryColorHex!, "포인트"),
                    const SizedBox(width: 8),
                    Text(
                      appliance.layoutType ?? "단일형",
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF5F5D58),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int elementDepth(RoomElement appliance) {
    return appliance.dz.toInt();
  }

  Widget _colorChip(String hex, String label) {
    final c = HexColor.fromHex(hex);
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: c,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey, width: 0.5),
          ),
        ),
        const SizedBox(width: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 8, color: Color(0xFF8A877F)),
        ),
      ],
    );
  }

  Widget _buildApplianceListView() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const Text(
          "✦ 공간 맞춤 LG 가전 추천 (목록을 탭해 도면에서 확인)",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        ..._roomElements.where((e) => e.isLG).map((appliance) {
          final isSelected = _selectedElementId == appliance.id;
          return InkWell(
            onTap: () {
              setState(() {
                _selectedElementId = appliance.id;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFFFECEC) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFE6007E)
                      : const Color(0xFFF4F5F8),
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: appliance.frontImage != null
                        ? Image.asset(
                            appliance.frontImage!,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  width: 40,
                                  height: 40,
                                  color: const Color(0xFFFFFBEF),
                                  child: const Icon(
                                    Icons.broken_image,
                                    color: Color(0xFFE6007E),
                                    size: 18,
                                  ),
                                ),
                          )
                        : Container(
                            width: 40,
                            height: 40,
                            color: const Color(0xFFFFFBEF),
                            child: const Icon(
                              Icons.settings_remote,
                              color: Color(0xFFE6007E),
                              size: 18,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appliance.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          "크기: ${appliance.dx.toInt()}x${appliance.dz.toInt()}cm, 높이: ${appliance.dy.toInt()}cm",
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF8A877F),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: Color(0xFF8A877F),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  void _findSelectedAppliance(
    double px,
    double py,
    double width,
    double height,
  ) {
    final cx = (px - width / 2) / (width / 2) * 100;
    final cz = (py - height / 2) / (height / 2) * 100;

    String? foundId;
    for (var element in _roomElements) {
      if (element.isLG) {
        final halfW = (element.dx / 2) / 3.0;
        final halfL = (element.dz / 2) / 3.0;
        if (cx >= element.x - halfW &&
            cx <= element.x + halfW &&
            cz >= element.z - halfL &&
            cz <= element.z + halfL) {
          foundId = element.id;
          break;
        }
      }
    }

    setState(() {
      _selectedElementId = foundId;
    });
  }

  void _updateAppliancePosition(
    double px,
    double py,
    double width,
    double height,
  ) {
    if (_selectedElementId == null) return;

    final element = _roomElements.firstWhere((e) => e.id == _selectedElementId);

    // Scale factor: 1 coordinate unit = 3 cm (since room is 600cm and coordinate range is -100 to 100)
    final double halfW = (element.dx / 2.0) / 3.0;
    final double halfL = (element.dz / 2.0) / 3.0;

    // Clamp coordinates so that the appliance edges do not exceed the -100 to 100 room boundaries
    final cx = ((px - width / 2) / (width / 2) * 100).clamp(
      -100.0 + halfW,
      100.0 - halfW,
    );
    final cz = ((py - height / 2) / (height / 2) * 100).clamp(
      -100.0 + halfL,
      100.0 - halfL,
    );

    setState(() {
      _roomElements = _roomElements.map((e) {
        if (e.id == _selectedElementId) {
          return e.copyWith(x: cx, z: cz);
        }
        return e;
      }).toList();
    });
  }

  String _modelSrcFor(RoomElement el) {
    final name = el.name.toLowerCase();
    if (name.contains('냉장고') || name.contains('refrigerator')) {
      return 'assets/models/haier_refrigerator.glb';
    } else if (name.contains('건조기') || name.contains('dryer')) {
      return 'assets/models/washer_dryer_machine.glb';
    } else if (name.contains('세탁기') ||
        name.contains('washer') ||
        name.contains('washing')) {
      return 'assets/models/washing_machine.glb';
    } else if (name.contains('에어컨') || name.contains('air')) {
      return 'assets/models/air_conditioner.glb';
    }
    return 'assets/models/haier_refrigerator.glb';
  }

  Widget _build3DInteractiveView() {
    if (_tabController.index == 0) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE6007E)),
      );
    }

    if (_roomElements.isEmpty) {
      return const Center(child: Text('배치된 가전이 없습니다.'));
    }

    final lgAppliances = _roomElements.where((e) => e.isLG).toList();

    return Column(
      children: [
        // View mode switch toggle
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F3F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _viewMode3D = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _viewMode3D == 0
                          ? const Color(0xFFE6007E)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '전체 입체 배치도',
                      style: TextStyle(
                        color: _viewMode3D == 0
                            ? Colors.white
                            : const Color(0xFF5F5D58),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (lgAppliances.isNotEmpty) {
                      setState(() => _viewMode3D = 1);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('배치된 LG 가전이 없습니다.')),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _viewMode3D == 1
                          ? const Color(0xFFE6007E)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '실물 가전 3D 상세보기',
                      style: TextStyle(
                        color: _viewMode3D == 1
                            ? Colors.white
                            : const Color(0xFF5F5D58),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Main 3D Panel
        Expanded(
          child: _viewMode3D == 0
              ? _buildRoom3DLayout()
              : _buildProduct3DDetail(lgAppliances),
        ),
      ],
    );
  }

  Widget _buildRoom3DLayout() {
    final List<Map<String, dynamic>> elementsList = _roomElements
        .map(
          (e) => {
            'id': e.id,
            'name': e.name,
            'isLG': e.isLG,
            'x': e.x,
            'y': e.y,
            'z': e.z,
            'dx': e.dx,
            'dy': e.dy,
            'dz': e.dz,
            'primaryColorHex': e.primaryColorHex,
            'frontImage': e.frontImage,
            'areaSize': _areaSize,
          },
        )
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.rotate_left, size: 14, color: Color(0xFFE6007E)),
              const SizedBox(width: 4),
              const Text(
                '데스크톱: WASD 키로 이동 + 마우스 클릭하여 시점 조작 | 모바일: 조이스틱 및 드래그 (우측 상단 [1인칭 탐색 (FPS)]을 눌러보세요!)',
                style: TextStyle(fontSize: 11, color: Color(0xFF8A877F)),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FC),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E4E8)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Web3DViewer.create(elements: elementsList),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            "추천 배치 무드: $_mood (${_roomElements.where((e) => e.isLG).length}개 가전)",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Color(0xFF2B2A27),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProduct3DDetail(List<RoomElement> lgAppliances) {
    if (_selectedProduct3DIndex >= lgAppliances.length) {
      _selectedProduct3DIndex = 0;
    }
    final el = lgAppliances[_selectedProduct3DIndex];
    final src = _modelSrcFor(el);

    return Column(
      children: [
        // Navigation arrows & Product Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios,
                  size: 16,
                  color: Color(0xFF5F5D58),
                ),
                onPressed: () {
                  setState(() {
                    _selectedProduct3DIndex =
                        (_selectedProduct3DIndex - 1 + lgAppliances.length) %
                        lgAppliances.length;
                  });
                },
              ),
              Expanded(
                child: Text(
                  el.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF2B2A27),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Color(0xFF5F5D58),
                ),
                onPressed: () {
                  setState(() {
                    _selectedProduct3DIndex =
                        (_selectedProduct3DIndex + 1) % lgAppliances.length;
                  });
                },
              ),
            ],
          ),
        ),

        // 3D Canvas
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FC),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E4E8)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Web3DViewer.create(
                modelUrl: src,
                frontImage: el.frontImage,
              ),
            ),
          ),
        ),

        // Size Specs
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            "실측 사이즈: W ${el.dx.toInt()} x H ${el.dy.toInt()} x D ${el.dz.toInt()} cm",
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFFE6007E),
            ),
          ),
        ),
      ],
    );
  }
}

class InteractiveBlueprintPainter extends CustomPainter {
  final List<RoomElement> elements;
  final String? selectedId;
  final String areaSize;

  InteractiveBlueprintPainter({
    required this.elements,
    required this.selectedId,
    required this.areaSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    double sizeCm = 600.0;
    if (areaSize.contains('18평') || areaSize.contains('59㎡')) {
      sizeCm = 450.0;
    } else if (areaSize.contains('34평') || areaSize.contains('114㎡')) {
      sizeCm = 800.0;
    }

    final double scale = width / sizeCm;

    double toScreenX(double cx) => width / 2 + cx * (width / 2) / 100;
    double toScreenY(double cz) => height / 2 + cz * (height / 2) / 100;
    double toScreenW(double cdx) => cdx * scale;
    double toScreenH(double cdz) => cdz * scale;

    // Draw Appliance/Furniture elements overlaid on the blueprint image
    for (var element in elements) {
      final isSel = element.id == selectedId;
      final fillPaint = Paint()
        ..color = isSel
            ? const Color(0xFFFFECEC)
            : (element.isLG
                  ? element.color.withValues(alpha: 0.3)
                  : element.color)
        ..style = PaintingStyle.fill;

      final borderPaint = Paint()
        ..color = isSel
            ? const Color(0xFFE6007E)
            : (element.isLG ? const Color(0xFFE6007E) : const Color(0xFF8A877F))
        ..strokeWidth = isSel ? 2.5 : 1.5
        ..style = PaintingStyle.stroke;

      final elementW = toScreenW(element.dx);
      final elementH = toScreenH(element.dz);
      final rect = Rect.fromCenter(
        center: Offset(toScreenX(element.x), toScreenY(element.z)),
        width: elementW,
        height: elementH,
      );

      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect, borderPaint);

      // Label inside element
      final textPainter = TextPainter(
        text: TextSpan(
          text: element.name.length > 15
              ? "${element.name.substring(0, 12)}..."
              : element.name,
          style: TextStyle(
            color: isSel ? const Color(0xFFE6007E) : const Color(0xFF2B2A27),
            fontSize: element.dx > 40 ? 9.5 : 7.5,
            fontWeight: FontWeight.bold,
            backgroundColor: Colors.white.withValues(alpha: 0.8),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: elementW);

      textPainter.paint(
        canvas,
        Offset(
          rect.left + (elementW - textPainter.width) / 2,
          rect.top + (elementH - textPainter.height) / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant InteractiveBlueprintPainter oldDelegate) {
    return oldDelegate.selectedId != selectedId ||
        oldDelegate.elements != elements ||
        oldDelegate.areaSize != areaSize;
  }
}

class Isometric3DRotatorPainter extends CustomPainter {
  final List<RoomElement> elements;
  final double yaw;
  final double pitch;
  final Map<String, ui.Image> loadedImages;

  Isometric3DRotatorPainter({
    required this.elements,
    required this.yaw,
    required this.pitch,
    required this.loadedImages,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    Offset project(double x, double y, double z) {
      final cosY = math.cos(yaw);
      final sinY = math.sin(yaw);
      final x1 = x * cosY - z * sinY;
      final z1 = x * sinY + z * cosY;

      final cosP = math.cos(pitch);
      final sinP = math.sin(pitch);
      final y2 = y * cosP - z1 * sinP;

      final scale = math.min(width, height) * 0.0035;
      final px = width / 2 + x1 * scale;
      final py = height / 2 - y2 * scale;
      return Offset(px, py);
    }

    final floorPaint = Paint()
      ..color = const Color(0xFFF1F3F6)
      ..style = PaintingStyle.fill;
    final floorBorderPaint = Paint()
      ..color = const Color(0xFFE2E4E8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final floorPts = [
      project(-100, 0, -100),
      project(100, 0, -100),
      project(100, 0, 100),
      project(-100, 0, 100),
    ];
    final floorPath = Path()..addPolygon(floorPts, true);
    canvas.drawPath(floorPath, floorPaint);
    canvas.drawPath(floorPath, floorBorderPaint);

    final wallPaint = Paint()
      ..color = const Color(0xFF2B2A27).withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;
    final wallBorderPaint = Paint()
      ..color = const Color(0xFF2B2A27)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final wallPtsBack = [
      project(-100, 0, -100),
      project(100, 0, -100),
      project(100, 60, -100),
      project(-100, 60, -100),
    ];
    canvas.drawPath(Path()..addPolygon(wallPtsBack, true), wallPaint);
    canvas.drawPath(Path()..addPolygon(wallPtsBack, true), wallBorderPaint);

    final wallPtsLeft = [
      project(-100, 0, -100),
      project(-100, 0, 100),
      project(-100, 60, 100),
      project(-100, 60, -100),
    ];
    canvas.drawPath(Path()..addPolygon(wallPtsLeft, true), wallPaint);
    canvas.drawPath(Path()..addPolygon(wallPtsLeft, true), wallBorderPaint);

    final rotatedElements = List<RoomElement>.from(elements);
    rotatedElements.sort((a, b) {
      final zA = a.x * math.sin(yaw) + a.z * math.cos(yaw);
      final zB = b.x * math.sin(yaw) + b.z * math.cos(yaw);
      return zA.compareTo(zB);
    });

    for (var element in rotatedElements) {
      final hW = element.dx / 2;
      final hL = element.dz / 2;
      final ht = element.dy;

      final p0 = project(element.x - hW, element.y, element.z - hL);
      final p1 = project(element.x + hW, element.y, element.z - hL);
      final p2 = project(element.x + hW, element.y, element.z + hL);
      final p3 = project(element.x - hW, element.y, element.z + hL);
      final p4 = project(element.x - hW, element.y + ht, element.z - hL);
      final p5 = project(element.x + hW, element.y + ht, element.z - hL);
      final p6 = project(element.x + hW, element.y + ht, element.z + hL);
      final p7 = project(element.x - hW, element.y + ht, element.z + hL);

      final boxBorder = Paint()
        ..color = element.isLG
            ? const Color(0xFFE6007E)
            : const Color(0xFF5F5D58)
        ..strokeWidth = element.isLG ? 1.5 : 1
        ..style = PaintingStyle.stroke;

      final boxFill = Paint()
        ..color = element.color.withValues(alpha: 0.8)
        ..style = PaintingStyle.fill;

      // Generative 3D visual panels using VLM specs (Hex colors, divides, louvers, display windows)
      void drawApplianceFace(List<Offset> pts, Color fallbackColor) {
        if (!element.isLG || element.layoutType == null) {
          canvas.drawPath(Path()..addPolygon(pts, true), boxFill);
          canvas.drawPath(Path()..addPolygon(pts, true), boxBorder);
          return;
        }

        final bl = pts[0];
        final br = pts[1];
        final tr = pts[2];
        final tl = pts[3];

        final pColor = element.primaryColorHex != null
            ? HexColor.fromHex(element.primaryColorHex!)
            : fallbackColor;
        final sColor = element.secondaryColorHex != null
            ? HexColor.fromHex(element.secondaryColorHex!)
            : pColor;

        // Base Panel Paint
        final basePaint = Paint()
          ..color = pColor
          ..style = PaintingStyle.fill;
        canvas.drawPath(Path()..addPolygon(pts, true), basePaint);

        final linePaint = Paint()
          ..color = const Color(0xFF2B2A27)
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round;

        final shadowLinePaint = Paint()
          ..color = Colors.black.withValues(alpha: 0.25)
          ..strokeWidth = 2.5;

        if (element.layoutType == "4-door") {
          // Bottom panel gets secondary color (Objet Collection split design)
          final lMid = Offset(
            bl.dx + (tl.dx - bl.dx) * 0.45,
            bl.dy + (tl.dy - bl.dy) * 0.45,
          );
          final rMid = Offset(
            br.dx + (tr.dx - br.dx) * 0.45,
            br.dy + (tr.dy - br.dy) * 0.45,
          );

          final bottomPath = Path()
            ..moveTo(bl.dx, bl.dy)
            ..lineTo(br.dx, br.dy)
            ..lineTo(rMid.dx, rMid.dy)
            ..lineTo(lMid.dx, lMid.dy)
            ..close();

          final secPaint = Paint()
            ..color = sColor
            ..style = PaintingStyle.fill;
          canvas.drawPath(bottomPath, secPaint);

          // Horizontal divider line
          canvas.drawLine(lMid, rMid, shadowLinePaint);
          canvas.drawLine(lMid, rMid, linePaint);

          // Vertical divider line
          final bMid = Offset((bl.dx + br.dx) / 2, (bl.dy + br.dy) / 2);
          final tMid = Offset((tl.dx + tr.dx) / 2, (tl.dy + tr.dy) / 2);
          canvas.drawLine(bMid, tMid, shadowLinePaint);
          canvas.drawLine(bMid, tMid, linePaint);
        } else if (element.layoutType == "2-door-vertical") {
          final bMid = Offset((bl.dx + br.dx) / 2, (bl.dy + br.dy) / 2);
          final tMid = Offset((tl.dx + tr.dx) / 2, (tl.dy + tr.dy) / 2);
          canvas.drawLine(bMid, tMid, shadowLinePaint);
          canvas.drawLine(bMid, tMid, linePaint);
        } else if (element.layoutType == "2-door-horizontal" ||
            element.layoutType == "top-load") {
          final lMid = Offset((bl.dx + tl.dx) / 2, (bl.dy + tl.dy) / 2);
          final rMid = Offset((br.dx + tr.dx) / 2, (br.dy + tr.dy) / 2);
          canvas.drawLine(lMid, rMid, shadowLinePaint);
          canvas.drawLine(lMid, rMid, linePaint);
        } else if (element.layoutType == "front-load") {
          // Detergent Drawer Divider line at 78% height
          final lDraw = Offset(
            bl.dx + (tl.dx - bl.dx) * 0.78,
            bl.dy + (tl.dy - bl.dy) * 0.78,
          );
          final rDraw = Offset(
            br.dx + (tr.dx - br.dx) * 0.78,
            br.dy + (tr.dy - br.dy) * 0.78,
          );
          canvas.drawLine(lDraw, rDraw, linePaint);

          // Front Round Glass Window (for Drum Washers)
          final center = Offset(
            bl.dx + (tr.dx - bl.dx) * 0.5,
            bl.dy + (tr.dy - bl.dy) * 0.42,
          );
          final rx = (br.dx - bl.dx).abs() * 0.28;
          final ry = (tl.dy - bl.dy).abs() * 0.28;
          final r = math.min(rx, ry);

          // Chrome frame
          final ringPaint = Paint()
            ..color = const Color(0xFFCFD8DC)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.5;
          canvas.drawCircle(center, r, ringPaint);

          // Dark transparent inner glass
          final glassPaint = Paint()
            ..color = const Color(0xFF1C2833).withValues(alpha: 0.88)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(center, r - 2, glassPaint);

          // Reflections gloss arc
          final glossPaint = Paint()
            ..color = Colors.white.withValues(alpha: 0.15)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8;
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: r - 5),
            -math.pi / 4,
            math.pi / 2,
            false,
            glossPaint,
          );
        } else if (element.layoutType == "stand" ||
            element.layoutType == "air-conditioners") {
          // Stand aircon output panels
          final steps = 5;
          for (int s = 1; s < steps; s++) {
            final ratio = s / steps.toDouble();
            final lp = Offset(
              bl.dx + (tl.dx - bl.dx) * ratio,
              bl.dy + (tl.dy - bl.dy) * ratio,
            );
            final rp = Offset(
              br.dx + (tr.dx - br.dx) * ratio,
              br.dy + (tr.dy - br.dy) * ratio,
            );
            canvas.drawLine(
              lp,
              rp,
              Paint()
                ..color = const Color(0xFF7F8C8D)
                ..strokeWidth = 0.8,
            );
          }
          final lMid = Offset(
            bl.dx + (tl.dx - bl.dx) * 0.15,
            bl.dy + (tl.dy - bl.dy) * 0.15,
          );
          final rMid = Offset(
            br.dx + (tr.dx - br.dx) * 0.15,
            br.dy + (tr.dy - br.dy) * 0.15,
          );
          canvas.drawLine(lMid, rMid, linePaint);
        } else if (element.layoutType == "wall-mount") {
          // Wall louver lines
          final lMid = Offset(
            bl.dx + (tl.dx - bl.dx) * 0.3,
            bl.dy + (tl.dy - bl.dy) * 0.3,
          );
          final rMid = Offset(
            br.dx + (tr.dx - br.dx) * 0.3,
            br.dy + (tr.dy - br.dy) * 0.3,
          );
          canvas.drawLine(lMid, rMid, linePaint);
        }

        // Draw screen touch display panel if VLM identified it
        if (element.hasDisplayScreen) {
          final sLeft = bl.dx + (tl.dx - bl.dx) * 0.8 + (br.dx - bl.dx) * 0.12;
          final sTop = bl.dy + (tl.dy - bl.dy) * 0.8 + (br.dy - bl.dy) * 0.12;
          final sWidth = (br.dx - bl.dx).abs() * 0.22;
          final sHeight = (tl.dy - bl.dy).abs() * 0.06;

          final screenPaint = Paint()
            ..color = const Color(0xFF0F172A)
            ..style = PaintingStyle.fill;
          canvas.drawRect(
            Rect.fromLTWH(sLeft, sTop, sWidth, -sHeight),
            screenPaint,
          );

          // LED glowing power dot
          final dotPaint = Paint()
            ..color = const Color(0xFF38BDF8)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(
            Offset(sLeft + sWidth * 0.2, sTop - sHeight / 2),
            1.2,
            dotPaint,
          );
        }

        // Glassmorphism gloss reflection sheet
        final sheenPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.08)
          ..style = PaintingStyle.fill;
        final sheenPath = Path()
          ..moveTo(tl.dx, tl.dy)
          ..lineTo(br.dx, br.dy)
          ..lineTo(bl.dx, bl.dy)
          ..close();
        canvas.drawPath(sheenPath, sheenPaint);

        // Face outline
        canvas.drawPath(Path()..addPolygon(pts, true), boxBorder);
      }

      // Helper: returns true if face polygon is front-facing (CCW winding = visible to camera)
      bool isFrontFacing(List<Offset> pts) {
        // 2D cross product of first two edges
        final v1x = pts[1].dx - pts[0].dx;
        final v1y = pts[1].dy - pts[0].dy;
        final v2x = pts[2].dx - pts[0].dx;
        final v2y = pts[2].dy - pts[0].dy;
        // In screen coords Y is flipped, so CCW = negative cross
        return (v1x * v2y - v1y * v2x) < 0;
      }

      // Bottom face
      final botPts = [p0, p1, p2, p3];
      if (isFrontFacing(botPts)) {
        canvas.drawPath(Path()..addPolygon(botPts, true), boxFill);
        canvas.drawPath(Path()..addPolygon(botPts, true), boxBorder);
      }

      final pColor = element.primaryColorHex != null
          ? HexColor.fromHex(element.primaryColorHex!)
          : element.color;

      // Draw top face (always visible from the camera pitch angle)
      final topPts = [p4, p5, p6, p7];
      final topFill = Paint()
        ..color = pColor
        ..style = PaintingStyle.fill;
      canvas.drawPath(Path()..addPolygon(topPts, true), topFill);
      canvas.drawPath(Path()..addPolygon(topPts, true), boxBorder);

      // Face A: front face (Z- side, faces viewer when yaw ≈ 45°)
      final faceA = [p0, p1, p5, p4];
      if (isFrontFacing(faceA)) {
        drawApplianceFace(faceA, element.color);
      }

      // Face B: right side face (X+ side)
      final faceB = [p1, p2, p6, p5];
      if (isFrontFacing(faceB)) {
        final sideFill = Paint()
          ..color = pColor
          ..style = PaintingStyle.fill;
        canvas.drawPath(Path()..addPolygon(faceB, true), sideFill);
        canvas.drawPath(Path()..addPolygon(faceB, true), boxBorder);
      }

      // Face C: back face (Z+ side, opposite of front)
      final faceC = [p2, p3, p7, p6];
      if (isFrontFacing(faceC)) {
        drawApplianceFace(faceC, element.color);
      }

      // Face D: left side face (X- side)
      final faceD = [p3, p0, p4, p7];
      if (isFrontFacing(faceD)) {
        final sideFill = Paint()
          ..color = pColor
          ..style = PaintingStyle.fill;
        canvas.drawPath(Path()..addPolygon(faceD, true), sideFill);
        canvas.drawPath(Path()..addPolygon(faceD, true), boxBorder);
      }

      // Label on top
      final textPainter = TextPainter(
        text: TextSpan(
          text: element.name.length > 12
              ? "${element.name.substring(0, 10)}..."
              : element.name,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final textOffset = project(element.x, element.y + ht, element.z);
      textPainter.paint(
        canvas,
        Offset(
          textOffset.dx - textPainter.width / 2,
          textOffset.dy - textPainter.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant Isometric3DRotatorPainter oldDelegate) {
    return oldDelegate.yaw != yaw ||
        oldDelegate.pitch != pitch ||
        oldDelegate.elements != elements ||
        oldDelegate.loadedImages != loadedImages;
  }
}
