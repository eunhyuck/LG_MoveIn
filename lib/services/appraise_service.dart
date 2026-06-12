import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

const _visionUrl = 'http://invisiondev.iptime.org:9007/v1/chat/completions';
const _visionModel = 'gemma-4-26B-A4B-it-UD-Q4_K_M.gguf';
const _exaUrl = 'https://api.exa.ai/search';
const _exaKey = 'efa593a1-3e73-4737-b5c4-f11c5c7c251d';
const _usedDomains = ['daangn.com', 'bunjang.co.kr', 'joongna.com', 'cafe.naver.com'];

class AppraiseService {
  // ─── 1. 제품 식별 (Vision LLM) ──────────────────────────────
  static const _categoryVisualGuide = {
    '냉장고': '세로로 긴 직사각형 본체, 1~2개 도어, 손잡이, 내부 선반·서랍 구조',
    '김치냉장고': '김치냉장고는 뚜껑형(상단 열림) 또는 서랍형, 냉장고보다 낮은 높이',
    '세탁기': '원형 드럼 도어(프론트로드) 또는 상단 덮개(탑로드), 조작 패널',
    '건조기': '세탁기와 유사하나 배기구·필터 커버 존재, 단독 또는 세탁기 위 적층',
    '워시타워': '세탁기+건조기가 하나로 합쳐진 슬림 타워형, LG 트롬 로고',
    '에어컨': '실내기: 벽걸이 슬림형 또는 스탠드형 / 실외기: 박스형 팬',
    '공기청정기': '원통형 또는 타워형, 전면 흡기구, 상단 배출구, 필터 교체창',
    '청소기': '핸디·스틱형(긴 막대+흡입부) 또는 로봇청소기(납작한 원반형)',
    '스타일러': '의류관리기, 세로로 긴 박스형, 전면 유리도어, 내부 행거',
    '식기세척기': '전면 도어 풀다운, 내부 바구니·분사노즐, 세제 투입구',
    '전자레인지/오븐': '소형 박스, 전면 유리창, 회전판 또는 그릴 내부, 조작 패널',
    '인덕션': '평평한 유리 상판, 화구 원형 표시, 쿡탑 형태',
    '정수기': '슬림 스탠드형 또는 카운터탑, 출수구, 필터 교체창',
    '제습기': '소형 직사각형, 상단 또는 전면 배수통, 공기 흡기·배기구',
  };

  // ─── OCR: 모델 라벨 인식 ───────────────────────────────────
  static Future<String?> ocrModelLabel(String dataUrl) async {
    const prompt =
        '이 사진은 가전제품 뒷면 또는 옆면의 모델 스티커·라벨입니다. '
        '스티커에 인쇄된 모델번호(Model No., 형식번호)를 정확히 읽어주세요. '
        '모델번호는 보통 영문+숫자 조합입니다. 예: WM3900HWA, F19WD, GR-X267MB\n\n'
        '반드시 아래 형식의 JSON만 출력하세요. 다른 설명 금지.\n'
        '{"model_code": "읽어낸 모델번호", "brand": "브랜드명", "confidence": "상/중/하"}\n'
        '모델번호를 읽을 수 없으면: {"model_code": "", "brand": "", "confidence": "하"}';

    final content = <Map<String, dynamic>>[
      {'type': 'text', 'text': prompt},
      {'type': 'image_url', 'image_url': {'url': dataUrl}},
    ];

    try {
      final raw = await _visionChat(content, maxTokens: 300);
      final parsed = _extractJson(raw);
      final code = (parsed?['model_code'] as String? ?? '').trim();
      return code.isNotEmpty ? code : null;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> identifyProduct(
    List<String> dataUrls, {
    String hint = '',
    String? categoryHint,
    String? modelCodeFromOcr,
  }) async {
    final categorySection = categoryHint != null
        ? '【중요】 사용자가 이 제품이 "$categoryHint"임을 직접 알려줬습니다. '
          '"종류" 필드는 반드시 "$categoryHint"로 출력하세요. '
          '${_categoryVisualGuide[categoryHint] != null ? "$categoryHint 외형 특징: ${_categoryVisualGuide[categoryHint]}" : ""}\n'
        : '가전제품 종류 판단 기준:\n'
          + _categoryVisualGuide.entries
              .map((e) => '  - ${e.key}: ${e.value}')
              .join('\n')
          + '\n위 기준으로 사진 속 제품 종류를 정확히 판단하세요.\n';

    final ocrSection = modelCodeFromOcr != null && modelCodeFromOcr.isNotEmpty
        ? '【OCR 확인 모델번호】 라벨 스티커 OCR로 "$modelCodeFromOcr"을(를) 읽었습니다. '
          '"모델명단서" 필드에 이 값을 반드시 포함하세요.\n'
        : '';

    final prompt = '당신은 중고 가전 감정사입니다. 아래 사진들은 모두 \'하나의 같은 제품\'을 여러 각도로 '
        '찍은 것입니다. 사진을 종합해 제품을 식별하고 상태를 평가하세요.\n\n'
        '$categorySection\n'
        '$ocrSection'
        '제품에 보이는 브랜드 로고, 모델명, 라벨 스티커의 글자/숫자를 최대한 읽어주세요.\n'
        '겉면의 하자(스크래치, 찌그러짐, 변색, 녹, 파손, 오염)를 빠짐없이 적어주세요.\n'
        + (hint.isNotEmpty
            ? '추가 정보(참고용): "$hint"\n'
            : '')
        + '\n반드시 아래 형식의 JSON 객체만 출력하세요. 다른 설명 금지.\n'
          '{\n'
          '  "종류": "냉장고",\n'
          '  "브랜드": "LG",\n'
          '  "모델명단서": "RT38K..., 비스포크 추정",\n'
          '  "추정연식": "2019~2021년형 추정",\n'
          '  "하자": ["우측 도어 하단 잔스크래치"],\n'
          '  "상태등급": "A/B/C 중 하나 (A=거의새것, B=사용감보통, C=하자뚜렷)",\n'
          '  "확신도": "상/중/하"\n'
          '}\n'
          '읽을 수 없는 값은 "불명"으로 적으세요. 하자가 없으면 빈 배열.';

    final content = <Map<String, dynamic>>[
      {'type': 'text', 'text': prompt},
      ...dataUrls.map((url) => {
        'type': 'image_url',
        'image_url': {'url': url},
      }),
    ];

    final raw = await _visionChat(content, maxTokens: 1200);
    return _extractJson(raw);
  }

  // ─── 2. 시세 검색 (Exa) ──────────────────────────────────────
  static Future<Map<String, dynamic>> searchPrices(
    Map<String, dynamic> product, {
    String purchaseYear = '',
    String sizeHint = '',
  }) async {
    final category = product['종류'] as String? ?? '가전';
    final brand    = _clean(product['브랜드']);
    final model    = _clean(product['모델명단서']);
    final dbModel  = _clean(product['db모델코드']);
    final dbYear   = _clean(product['db연식']);

    final effectiveModel = dbModel.isNotEmpty ? dbModel : model;
    final effectiveYear  = purchaseYear.isNotEmpty ? purchaseYear
        : dbYear.isNotEmpty ? dbYear
        : _clean(product['추정연식']);
    final effectiveBrand = brand.isNotEmpty ? brand : '';
    final hasModel = effectiveModel.length >= 4;

    List<Map<String, dynamic>> usedResults;
    List<Map<String, dynamic>> newResults;

    if (hasModel) {
      // ── 실매물 타겟 검색: 번개장터·당근 우선 ──
      final r1 = await _safeExaSearch(
        '"$effectiveModel" 판매', num: 10,
        domains: ['bunjang.co.kr', 'daangn.com'],
      );
      final r2 = await _safeExaSearch(
        '"$effectiveModel" 중고 만원', num: 8,
        domains: ['bunjang.co.kr', 'daangn.com', 'joongna.com'],
      );
      final r3 = await _safeExaSearch(
        '$effectiveBrand $effectiveModel $category 중고', num: 6,
        domains: _usedDomains,
      );
      final r4 = await _safeExaSearch('$effectiveBrand $effectiveModel 신품가 출시가', num: 5);
      usedResults = _dedupe([...r1, ...r2, ...r3]);
      newResults  = r4;
    } else {
      // ── 모델 불명: 카테고리+연식 폴백 ──
      final parts = [effectiveBrand, category, effectiveYear, sizeHint]
          .where((x) => x.isNotEmpty).join(' ');
      final r1 = await _safeExaSearch(
        '$parts 판매 중고', num: 10,
        domains: ['bunjang.co.kr', 'daangn.com'],
      );
      final r2 = await _safeExaSearch('$parts 중고 시세', num: 6, domains: _usedDomains);
      final r3 = await _safeExaSearch('$parts 신품가', num: 4);
      usedResults = _dedupe([...r1, ...r2]);
      newResults  = r3;
    }

    // ── 가격 추출 & 통계 ──
    final prices = _extractPrices(usedResults);
    final stats  = _priceStats(prices);

    return {'used': usedResults, 'new': newResults, 'stats': stats};
  }

  // 텍스트에서 가격 숫자 추출
  static List<int> _extractPrices(List<Map<String, dynamic>> results) {
    final prices = <int>[];
    // "1,200,000원" 또는 "120만원" 패턴
    final re = RegExp(r'(\d{1,3}(?:,\d{3})+)\s*원|(\d+)\s*만\s*원');
    for (final r in results) {
      final text = '${r['title'] ?? ''} ${r['text'] ?? ''}';
      for (final m in re.allMatches(text)) {
        int? price;
        if (m.group(1) != null) {
          price = int.tryParse(m.group(1)!.replaceAll(',', ''));
        } else if (m.group(2) != null) {
          price = (int.tryParse(m.group(2)!) ?? 0) * 10000;
        }
        // 1만원~3천만원 범위만 유효
        if (price != null && price >= 10000 && price <= 30000000) {
          prices.add(price);
        }
      }
    }
    return prices;
  }

  // 가격 목록 → 통계 (상하 10% 이상치 제거)
  static Map<String, dynamic> _priceStats(List<int> prices) {
    if (prices.isEmpty) return {};
    final sorted = List<int>.from(prices)..sort();
    final n = sorted.length;
    final lo = (n * 0.10).floor();
    final hi = (n * 0.90).ceil().clamp(lo + 1, n);
    final trimmed = sorted.sublist(lo, hi);
    final sum = trimmed.reduce((a, b) => a + b);
    return {
      'count':  prices.length,
      'min':    trimmed.first,
      'max':    trimmed.last,
      'avg':    sum ~/ trimmed.length,
      'median': trimmed[trimmed.length ~/ 2],
    };
  }

  static String _clean(dynamic v) {
    final s = (v as String? ?? '').trim();
    return (s == '불명' || s.isEmpty) ? '' : s;
  }

  // ─── 3. 견적 + 판매글 생성 (Vision LLM) ─────────────────────
  static Future<Map<String, dynamic>> generateListing(
    Map<String, dynamic> product,
    List<Map<String, dynamic>> usedResults,
    List<Map<String, dynamic>> newResults, {
    Map<String, dynamic> priceStats = const {},
  }) async {
    String snippet(Map<String, dynamic> r) {
      final title = (r['title'] as String? ?? '').take(60);
      final text = (r['text'] as String? ?? '').take(200);
      return '- $title | $text';
    }

    final usedTxt = usedResults.take(8).map(snippet).join('\n');
    final newTxt = newResults.map(snippet).join('\n');

    final modelKnown = _clean(product['db모델코드']).isNotEmpty ||
        (_clean(product['모델명단서']).length >= 4);
    final modelNote = modelKnown
        ? ''
        : '\n⚠ 모델명이 불확실합니다. 시세 검색 결과와 제품 종류·연식·상태등급을 근거로 합리적인 가격 범위를 추정해주세요.\n';

    final dbSpecs = product['db스펙'] as Map<String, dynamic>? ?? {};
    final specsTxt = dbSpecs.isEmpty
        ? ''
        : '\n[DB 상세 스펙]\n'
          + dbSpecs.entries.map((e) => '  ${e.key}: ${e.value}').join('\n')
          + '\n';

    // 실거래 시세 통계 섹션
    String statsTxt = '';
    if (priceStats.isNotEmpty) {
      final cnt    = priceStats['count'];
      final minW   = ((priceStats['min'] as int) / 10000).round();
      final maxW   = ((priceStats['max'] as int) / 10000).round();
      final medW   = ((priceStats['median'] as int) / 10000).round();
      final avgW   = ((priceStats['avg'] as int) / 10000).round();
      statsTxt = '\n[실거래 시세 — 번개장터·당근마켓 수집 $cnt개 매물 기준]\n'
          '  최저: ${minW}만원 / 최고: ${maxW}만원 / 중앙값: ${medW}만원 / 평균: ${avgW}만원\n'
          '⚠ 위 실거래 통계를 최우선 기준으로 삼고, 상태등급·하자를 반영해 견적을 조정하세요.\n';
    }

    final prompt = '제품 식별 정보:\n${jsonEncode(product)}\n$modelNote$specsTxt$statsTxt\n'
        '[중고 매물 검색 결과 (참고용)]\n${usedTxt.isEmpty ? "(없음)" : usedTxt}\n\n'
        '[신품가 검색 결과]\n${newTxt.isEmpty ? "(없음)" : newTxt}\n\n'
        '위 정보를 근거로 다음을 한국어로 작성해줘. 반드시 아래 JSON 형식만 출력:\n'
        '{\n'
        '  "신품가추정": "예: 약 250만원 (출처 기반)",\n'
        '  "중고견적": "예: 80만~110만원 (상태 B 반영)",\n'
        '  "중고최저": 800000,\n'
        '  "중고최고": 1100000,\n'
        '  "견적근거": "연식/하자/시세를 반영한 2~3줄 설명",\n'
        '  "판매제목": "검색 잘 되는 30자 내외 제목",\n'
        '  "판매본문": "상태·하자·연식·특징을 정직하게 담은 5~8줄 판매글. 네고 여부 포함",\n'
        '  "희망판매가": 900000\n'
        '}\n'
        '중고최저/중고최고/희망판매가는 단위 없는 정수(원)로만. 하자는 숨기지 말고 본문에 정직히 반영.';

    final raw = await _visionChat(
      [{'type': 'text', 'text': prompt}],
      maxTokens: 900,
    );
    return _extractJson(raw) ?? {};
  }

  // ─── 4. Supabase DB 조회로 제품 정보 보정 ───────────────────
  static Future<Map<String, dynamic>> enrichFromDb(
    Map<String, dynamic> product, {
    String? ocrModelCode,
  }) async {
    final searchCode = ocrModelCode?.trim().isNotEmpty == true
        ? ocrModelCode!.trim()
        : (product['모델명단서'] as String? ?? '').trim();

    if (searchCode.isEmpty || searchCode == '불명') return product;

    try {
      final db = Supabase.instance.client;
      final keyword = searchCode.split(RegExp(r'[,\s]')).first.trim();
      final rows = await db
          .from('lg_products')
          .select(
            'model_code, name, category, release_year, price_new_krw, '
            'color, energy_grade, size_mm, weight_kg, thinq_wifi, up_appliance, '
            'capacity_l, dry_capacity_kg, suction_w, power_w, detail_specs',
          )
          .ilike('model_code', '%$keyword%')
          .limit(1);

      if (rows.isEmpty) return product;

      final m = rows.first as Map<String, dynamic>;

      // 공통 + 카테고리별 핵심 스펙을 하나의 Map으로 합산
      final specMap = <String, String>{};
      void add(String label, dynamic v) {
        if (v != null && v.toString().isNotEmpty) specMap[label] = v.toString();
      }
      add('색상', m['color']);
      add('에너지등급', m['energy_grade']);
      add('크기(mm)', m['size_mm']);
      add('무게(kg)', m['weight_kg']);
      add('ThinQ Wi-Fi', m['thinq_wifi'] == true ? '있음' : m['thinq_wifi'] == false ? '없음' : null);
      add('UP가전', m['up_appliance'] == true ? '있음' : m['up_appliance'] == false ? '없음' : null);
      add('전체용량(L)', m['capacity_l']);
      add('건조용량(kg)', m['dry_capacity_kg']);
      add('최대흡입력(W)', m['suction_w']);
      add('소비전력(W)', m['power_w']);
      // detail_specs 는 Map<String,dynamic> 형태로 저장됨
      final detail = m['detail_specs'] as Map<String, dynamic>? ?? {};
      for (final e in detail.entries) {
        specMap[e.key] = e.value.toString();
      }

      return {
        ...product,
        if (m['name'] != null) '공식제품명': m['name'],
        if (m['release_year'] != null) 'db연식': m['release_year'],
        if (m['price_new_krw'] != null) 'db신품가': m['price_new_krw'],
        'db모델코드': m['model_code'],
        if (specMap.isNotEmpty) 'db스펙': specMap,
      };
    } catch (_) {
      return product;
    }
  }

  // ─── 내부 유틸 ────────────────────────────────────────────────

  static Future<String> _visionChat(
    List<Map<String, dynamic>> content, {
    int maxTokens = 1000,
  }) async {
    final resp = await http
        .post(
          Uri.parse(_visionUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'model': _visionModel,
            'messages': [
              {'role': 'user', 'content': content},
            ],
            'max_tokens': maxTokens,
            'temperature': 0.2,
          }),
        )
        .timeout(const Duration(seconds: 120));

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) throw Exception('Vision 응답이 비어있습니다.');
    return (choices.first['message']['content'] as String?) ?? '';
  }

  static Future<List<Map<String, dynamic>>> _safeExaSearch(
    String query, {
    int num = 5,
    List<String>? domains,
  }) async {
    try {
      final payload = <String, dynamic>{
        'query': query,
        'numResults': num,
        'contents': {'text': {'maxCharacters': 400}},
        if (domains != null) 'includeDomains': domains,
      };
      final resp = await http
          .post(
            Uri.parse(_exaUrl),
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': _exaKey,
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 40));

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(data['results'] ?? []);
    } catch (_) {
      return [];
    }
  }

  static Map<String, dynamic>? _extractJson(String raw) {
    final s = raw.indexOf('{');
    final e = raw.lastIndexOf('}');
    if (s != -1 && e != -1 && e > s) {
      try {
        return jsonDecode(raw.substring(s, e + 1)) as Map<String, dynamic>;
      } catch (_) {}
    }
    return null;
  }

  static List<Map<String, dynamic>> _dedupe(List<Map<String, dynamic>> list) {
    final seen = <String>{};
    return list.where((r) {
      final url = r['url'] as String? ?? '';
      return url.isNotEmpty && seen.add(url);
    }).toList();
  }
}

extension on String {
  String take(int n) => length > n ? substring(0, n) : this;
}
