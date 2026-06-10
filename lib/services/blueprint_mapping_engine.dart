class BlueprintWallData {
  final String id;
  final String name;
  final double xPercent; // Center X of the wall as percentage of the blueprint image width (0.0 to 1.0)
  final double zPercent; // Center Z of the wall as percentage of the blueprint image height (0.0 to 1.0)
  final double dxPercent; // Thickness of the wall as percentage of the blueprint image width
  final double dzPercent; // Length of the wall as percentage of the blueprint image height

  BlueprintWallData({
    required this.id,
    required this.name,
    required this.xPercent,
    required this.zPercent,
    required this.dxPercent,
    required this.dzPercent,
  });
}

class BlueprintMappingEngine {
  /// 도면 평형별 픽셀 좌표계 비례 가벽 데이터베이스
  static final Map<String, List<BlueprintWallData>> _blueprintWallsDb = {
    // 18평형 도면 이미지 (blueprint_18.png) 내부의 실제 벽선 위치 백분율 사상
    "18": [
      BlueprintWallData(
        id: "wall_bed_v",
        name: "벽체",
        xPercent: 0.55,  // 가로 55% 지점
        zPercent: 0.35,  // 세로 35% 지점
        dxPercent: 0.03, // 두께 3%
        dzPercent: 0.70, // 길이 70%
      ),
      BlueprintWallData(
        id: "wall_bed_h",
        name: "벽체",
        xPercent: 0.675,
        zPercent: 0.70,
        dxPercent: 0.25,
        dzPercent: 0.03,
      ),
      BlueprintWallData(
        id: "wall_bath_h",
        name: "벽체",
        xPercent: 0.275,
        zPercent: 0.70,
        dxPercent: 0.55,
        dzPercent: 0.03,
      ),
    ],
    // 25평형 도면 이미지 (blueprint_25.png) 내부의 실제 벽선 위치 백분율 사상
    "25": [
      BlueprintWallData(
        id: "wall_master_v",
        name: "벽체",
        xPercent: 0.375,
        zPercent: 0.25,
        dxPercent: 0.03,
        dzPercent: 0.50,
      ),
      BlueprintWallData(
        id: "wall_room2_v",
        name: "벽체",
        xPercent: 0.275,
        zPercent: 0.75,
        dxPercent: 0.03,
        dzPercent: 0.50,
      ),
      BlueprintWallData(
        id: "wall_room3_v",
        name: "벽체",
        xPercent: 0.575,
        zPercent: 0.75,
        dxPercent: 0.03,
        dzPercent: 0.50,
      ),
      BlueprintWallData(
        id: "wall_corridor_h",
        name: "벽체",
        xPercent: 0.29,
        zPercent: 0.50,
        dxPercent: 0.575,
        dzPercent: 0.03,
      ),
      BlueprintWallData(
        id: "wall_kitchen_v",
        name: "벽체",
        xPercent: 0.75,
        zPercent: 0.75,
        dxPercent: 0.03,
        dzPercent: 0.50,
      ),
    ],
    // 34평형 도면 이미지 (blueprint_34.png) 내부의 실제 벽선 위치 백분율 사상
    "34": [
      BlueprintWallData(
        id: "wall_master34_v",
        name: "벽체",
        xPercent: 0.675,
        zPercent: 0.50,
        dxPercent: 0.03,
        dzPercent: 1.0,
      ),
      BlueprintWallData(
        id: "wall_kitchen34_v",
        name: "벽체",
        xPercent: 0.525,
        zPercent: 0.25,
        dxPercent: 0.03,
        dzPercent: 0.50,
      ),
      BlueprintWallData(
        id: "wall_room2_34_v",
        name: "벽체",
        xPercent: 0.325,
        zPercent: 0.75,
        dxPercent: 0.03,
        dzPercent: 0.50,
      ),
      BlueprintWallData(
        id: "wall_room3_34_v",
        name: "벽체",
        xPercent: 0.55,
        zPercent: 0.75,
        dxPercent: 0.03,
        dzPercent: 0.50,
      ),
    ],
  };

  /// 업로드된 실제 도면 이미지의 비율(Aspect Ratio)을 연산하여 방 내부 좌표(-100 ~ 100)로 보간하여 벽체 데이터를 추출합니다.
  static List<Map<String, dynamic>> mapWalls({
    required String areaSize,
    required double imageWidth,
    required double imageHeight,
  }) {
    // 1. 도면에 매치되는 백분율 벽 데이터 추출
    String targetKey = "25";
    if (areaSize.contains("18")) {
      targetKey = "18";
    } else if (areaSize.contains("34")) {
      targetKey = "34";
    }

    final rawWalls = _blueprintWallsDb[targetKey] ?? _blueprintWallsDb["25"]!;
    final List<Map<String, dynamic>> mapped = [];

    // 2. 도면 이미지 종횡비 산출
    final double imgRatio = imageWidth / imageHeight;

    // 3. 백분율 좌표를 방의 가상 공간 좌표계(-100 ~ 100)로 사상
    for (var raw in rawWalls) {
      double cx = 0.0;
      double cz = 0.0;
      double dx = 6.0; 
      double dz = 20.0;

      if (imgRatio > 1.0) {
        // 가로가 넓은 도면: 세로 방향에 레터박스 여백이 생김
        cx = (raw.xPercent - 0.5) * 200.0;
        cz = (raw.zPercent - 0.5) * 200.0 / imgRatio;
        
        dx = raw.dxPercent * 200.0;
        dz = raw.dzPercent * 200.0 / imgRatio;
      } else {
        // 세로가 긴 도면: 가로 방향에 레터박스 여백이 생김
        cx = (raw.xPercent - 0.5) * 200.0 * imgRatio;
        cz = (raw.zPercent - 0.5) * 200.0;

        dx = raw.dxPercent * 200.0 * imgRatio;
        dz = raw.dzPercent * 200.0;
      }

      // 두께(Thickness) 정밀 보정: 수직벽/수평벽 구분에 따라 두께를 6cm(공간 2.0 unit)로 제한
      if (dx > dz) {
        // 가로로 누운 수평 벽: 두께인 dz를 2.0 (실제 6cm 두께)으로 제한
        dz = 2.0;
      } else {
        // 세로로 선 수직 벽: 두께인 dx를 2.0 (실제 6cm 두께)으로 제한
        dx = 2.0;
      }

      // 길이 최소값 제한 및 소수점 다듬기
      if (dx < 2.0) dx = 2.0;
      if (dz < 2.0) dz = 2.0;

      mapped.add({
        "id": raw.id,
        "name": raw.name,
        "x": double.parse(cx.toStringAsFixed(1)),
        "z": double.parse(cz.toStringAsFixed(1)),
        "dx": double.parse(dx.toStringAsFixed(1)),
        "dz": double.parse(dz.toStringAsFixed(1)),
      });
    }

    return mapped;
  }
}
