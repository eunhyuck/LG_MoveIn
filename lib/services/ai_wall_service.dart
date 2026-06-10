import 'dart:convert';
import 'package:http/http.dart' as http;

class AiWallService {
  /// 로컬 AI API를 호출하여 도면 혹은 라이프스타일에 부합하는 3D 가벽 좌표 목록을 추출합니다.
  static Future<List<Map<String, dynamic>>> analyzeWalls({
    required String baseUrl,
    required String model,
    required String apiKey,
    required String areaSize,
    required String lifestyle,
    String? base64Image,
  }) async {
    // 1. 엔드포인트 URL 정합성 확인 및 다듬기
    String cleanUrl = baseUrl.trim();
    if (!cleanUrl.endsWith('/v1/chat/completions')) {
      if (cleanUrl.endsWith('/')) {
        cleanUrl = '${cleanUrl}v1/chat/completions';
      } else {
        cleanUrl = '$cleanUrl/v1/chat/completions';
      }
    }

    final systemPrompt = '''
너는 아파트 도면 및 구조 분석을 기반으로 방을 구분하는 가벽(Wall Partition) 목록을 생성하는 인테리어 3D 공간 배치 AI 비서이다.
사용자의 평형 정보, 라이프스타일, 그리고 도면 이미지(제공된 경우)를 토대로 방 내부의 구획을 효율적으로 나눌 수 있는 가벽들의 2.5D 좌표 리스트를 생성해라.

[공간 좌표계 가이드]
- 공간은 가로 600cm x 세로 600cm 크기의 정방형이다.
- 가벽 좌표계는 가로축 X, 세로축 Z로 구성되며 중심은 (0, 0)이다.
- X 및 Z의 허용 범위는 -100에서 100 사이의 소수점 좌표이다.
- dx는 벽의 두께(cm 단위, 보통 6)이고, dz는 벽의 전체 길이(cm 단위)이다.
- 벽의 높이(dy)는 클라이언트에서 일괄 지정하므로 따로 출력하지 않아도 된다.

[출력 요구 조건]
- 반드시 다른 부연 설명이나 마크다운 백틱(```json) 없이 오직 JSON Array 객체 포맷으로만 응답해야 한다.
- JSON 배열의 각 아이템은 반드시 다음 스펙을 충족해야 한다.
  - "id": 고유 문자열 ID (예: "wall_bed_1")
  - "name": "벽체"로 고정
  - "x": 중심 X 좌표 (double, -100 ~ 100)
  - "z": 중심 Z 좌표 (double, -100 ~ 100)
  - "dx": 벽 두께 (double, 일반적으로 6.0)
  - "dz": 벽 길이 (double, 20.0 ~ 160.0 사이)

[JSON 응답 포맷 예시]
[
  {"id": "wall_v1", "name": "벽체", "x": 10.0, "z": -30.0, "dx": 6.0, "dz": 120.0},
  {"id": "wall_h1", "name": "벽체", "x": 35.0, "z": 40.0, "dx": 80.0, "dz": 6.0}
]
''';

    // 2. 메시지 구성 (가독성과 전송 속도를 모두 잡은 압축 도면 이미지를 VLM에 전달)
    final List<Map<String, dynamic>> messages = [
      {"role": "system", "content": systemPrompt}
    ];

    final userPrompt = "아파트 평형: $areaSize, 사용자 라이프스타일 선호: $lifestyle. 제공된 도면 이미지의 방 치수 수치(예: 4.0m, 3.5m 등)와 실제 벽 구조를 정확하게 판독하여 최적의 3D 가벽 공간 분할 좌표 JSON을 응답하라. 설명은 배제하고 JSON 배열만 반환하라.";

    if (base64Image != null && base64Image.isNotEmpty) {
      String formattedImage = base64Image;
      if (!formattedImage.startsWith('data:')) {
        formattedImage = 'data:image/jpeg;base64,$formattedImage';
      }

      messages.add({
        "role": "user",
        "content": [
          {"type": "text", "text": userPrompt},
          {
            "type": "image_url",
            "image_url": {"url": formattedImage}
          }
        ]
      });
    } else {
      messages.add({"role": "user", "content": userPrompt});
    }

    final headers = {
      "Content-Type": "application/json",
    };
    if (apiKey.isNotEmpty) {
      headers["Authorization"] = "Bearer $apiKey";
    }

    final body = {
      "model": model,
      "messages": messages,
      "temperature": 0.1,
    };

    // 3. API 호출 실행 (압축된 이미지이므로 60초면 로컬에서 연산이 충분히 끝납니다)
    final response = await http.post(
      Uri.parse(cleanUrl),
      headers: headers,
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw Exception('로컬 LLM API 응답 오류: 코드 ${response.statusCode}');
    }

    final Map<String, dynamic> resultJson = jsonDecode(utf8.decode(response.bodyBytes));
    final choices = resultJson["choices"] as List?;
    if (choices == null || choices.isEmpty) {
      throw Exception('로컬 LLM API 응답 데이터 구조가 올바르지 않습니다.');
    }

    final String content = choices[0]["message"]["content"] ?? "";

    // 4. 응답 텍스트 정제 (백틱 및 화이트스페이스 제거)
    String cleanContent = content.trim();
    if (cleanContent.startsWith("```")) {
      // 마크다운 블록 제거
      final lines = cleanContent.split('\n');
      if (lines.first.startsWith("```")) {
        lines.removeAt(0);
      }
      if (lines.isNotEmpty && lines.last.startsWith("```")) {
        lines.removeLast();
      }
      cleanContent = lines.join('\n').trim();
    }

    // 5. JSON 파싱
    final parsed = jsonDecode(cleanContent);
    if (parsed is List) {
      return parsed.map((item) {
        final Map<String, dynamic> map = Map<String, dynamic>.from(item);
        // 키가 반드시 id, name, x, z, dx, dz인지 보장
        return {
          "id": map["id"]?.toString() ?? "wall_${DateTime.now().millisecondsSinceEpoch}",
          "name": "벽체",
          "x": (map["x"] as num?)?.toDouble() ?? 0.0,
          "z": (map["z"] as num?)?.toDouble() ?? 0.0,
          "dx": (map["dx"] as num?)?.toDouble() ?? 6.0,
          "dz": (map["dz"] as num?)?.toDouble() ?? 40.0,
        };
      }).toList();
    } else {
      throw Exception('응답 결과가 JSON 배열 형식이 아닙니다.');
    }
  }
}
