import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Gemini API 설정 ─────────────────────────────────────────────
// API 키는 env.json에 GEMINI_API_KEY를 입력 후
// flutter run --dart-define-from-file=env.json 으로 실행
const _geminiApiKey     = String.fromEnvironment('GEMINI_API_KEY');
const _geminiProModel   = 'gemini-2.5-pro';    // 제품 사진 식별 (정확도 우선)
const _geminiFlashModel = 'gemini-2.5-flash';  // OCR·견적·룸플래너 (속도·비용 우선)
const _geminiBaseUrl    = 'https://generativelanguage.googleapis.com/v1beta/models';
const _exaUrl = 'https://api.exa.ai/search';
const _exaKey = 'efa593a1-3e73-4737-b5c4-f11c5c7c251d';
const _usedDomains = ['daangn.com', 'bunjang.co.kr', 'joongna.com', 'cafe.naver.com'];

class AppraiseService {
  // ─── 1. 제품 식별 (Vision LLM) ──────────────────────────────
  static const _categoryVisualGuide = {
    '냉장고': '세로로 긴 직사각형 본체, 1~2개 도어, 손잡이, 내부 선반·서랍 구조',
    '김치냉장고': '김치냉장고는 뚜껑형(상단 열림) 또는 서랍형, 냉장고보다 낮은 높이',
    '세탁기': '【독립 세탁기】 단독 기기, 높이 낮음(약 85cm), 전면 원형 드럼 도어 1개(프론트로드) 또는 상단 덮개 1개(탑로드), 조작 패널 1개. 건조기·워시타워와 별개의 단독 제품.',
    '건조기': '【독립 건조기】 세탁기와 비슷한 크기의 단독 기기, 전면 원형 드럼 도어 1개, 배기구·필터 커버 존재. 세탁기 위에 적층하거나 단독 설치.',
    '워시타워': '【워시타워 — 세탁+건조 일체형】 세탁기와 건조기가 하나의 슬림한 타워 본체로 합쳐진 제품. 높이가 세탁기의 약 2배(약 190cm), 도어가 위아래 2개(상단=건조기, 하단=세탁기), 본체에 "워시타워(WashTower)" 또는 "트롬" 로고, 컨트롤 패널 2개. 절대 단독 세탁기가 아님.',
    '에어컨': '실내기: 벽걸이 슬림형 또는 스탠드형 / 실외기: 박스형 팬',
    '공기청정기': '원통형 또는 타워형, 전면 흡기구, 상단 배출구, 필터 교체창',
    '청소기': '핸디·스틱형(긴 막대+흡입부) 또는 로봇청소기(납작한 원반형)',
    '스타일러': '【LG 스타일러 — 의류관리기】 세탁기·워시타워가 아님. 높이 약 185cm 슬림 박스형, 전면 투명 유리도어 1개, 도어 안쪽에 옷걸이(행거) 1~2개 가시적, 하단에 바지 프레스 트레이, 세탁 드럼(원형 도어) 없음. "스타일러(Styler)" 로고. 워시타워·세탁기와 완전히 다른 의류케어 제품.',
    '식기세척기': '세로형 직사각형 본체, 전면 도어(위아래로 열림), 내부 바구니·분사노즐·식기 거치대, 세제 투입구 — 절대 조리대가 아님',
    '전자레인지/오븐': '소형 박스, 전면 유리창, 회전판 또는 그릴 내부, 조작 패널',
    '인덕션': '【주방 조리기기】 평평한 유리 쿡탑, 원형 빨간 하이라이트 히터 또는 인덕션 화구 표시, 숫자 버튼+타이머 컨트롤 패널, LG DIOS 로고, 바닥에 놓이거나 빌트인 설치됨. 식기세척기·냉장고와 완전히 다른 제품임.',
    '정수기': '슬림 스탠드형 또는 카운터탑, 출수구, 필터 교체창',
    '제습기': '소형 직사각형, 상단 또는 전면 배수통, 공기 흡기·배기구',
  };

  // ─── OCR: 모델 라벨 인식 ───────────────────────────────────
  static Future<String?> ocrModelLabel(String dataUrl) async {
    const prompt =
        '이 사진은 가전제품의 모델 스티커·라벨입니다.\n'
        '아래 우선순위로 코드를 읽어주세요:\n'
        '1순위: "Product code:" 또는 "제품코드" 뒤의 코드 (예: GC-B459FQ8N.ATEGKRB → GC-B459FQ8N)\n'
        '2순위: "Model:" 또는 "Model No." 뒤의 코드 (예: Q343MTFF33)\n'
        '주의: 점(.) 뒤 지역코드(예: .AKOR .ATEGKRB .ABWT)는 반드시 제거하고 앞부분만 추출.\n'
        '시리얼번호(S/N)는 제외.\n\n'
        '반드시 아래 형식의 JSON만 출력하세요.\n'
        '{"model_code": "추출한 코드", "alt_code": "2순위 코드(없으면 빈 문자열)", "brand": "브랜드명", "confidence": "상/중/하"}\n'
        '읽을 수 없으면: {"model_code": "", "alt_code": "", "brand": "", "confidence": "하"}';

    final content = <Map<String, dynamic>>[
      {'type': 'text', 'text': prompt},
      {'type': 'image_url', 'image_url': {'url': dataUrl}},
    ];

    try {
      // OCR: Flash 모델 사용 (Pro는 thinking 토큰이 maxTokens를 소모해 텍스트 출력 없음)
      final raw = await _visionChat(content, maxTokens: 1024, useProModel: false, useJsonMime: false);
      // ignore: avoid_print
      print('[OCR] raw=${raw.take(200)}');
      String stripRegion(String c) => c.contains('.') ? c.split('.').first : c;

      final parsed = _extractJson(raw);
      // model_code 우선, alt_code 보조
      String code    = stripRegion((parsed?['model_code'] as String? ?? '').trim());
      String altCode = stripRegion((parsed?['alt_code']   as String? ?? '').trim());

      // 2차 fallback: 불완전한 JSON에서 regex로 추출
      if (code.isEmpty) {
        final m = RegExp(r'"model_code"\s*:\s*"([A-Za-z0-9\-\.]{3,})"').firstMatch(raw);
        code = stripRegion(m?.group(1)?.trim() ?? '');
      }
      // ignore: avoid_print
      print('[OCR] model_code=$code  alt_code=$altCode');
      // model_code와 alt_code를 "|" 구분자로 합쳐서 반환 (enrichFromDb에서 분리)
      if (code.isNotEmpty && altCode.isNotEmpty) return '$code|$altCode';
      return code.isNotEmpty ? code : (altCode.isNotEmpty ? altCode : null);
    } catch (e) {
      // ignore: avoid_print
      print('[OCR] 실패: $e');
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
          '"모델명단서" 필드는 반드시 "$modelCodeFromOcr"으로 시작하세요. 예: "$modelCodeFromOcr (추가설명)"\n'
        : '';

    final prompt = '당신은 중고 가전 감정사입니다. 아래 사진들은 모두 \'하나의 같은 제품\'을 여러 각도로 '
        '찍은 것입니다. 사진을 종합해 제품을 식별하고 상태를 평가하세요.\n\n'
        '$categorySection\n'
        '$ocrSection'
        '제품에 보이는 브랜드 로고, 모델명, 라벨 스티커의 글자/숫자를 최대한 읽어주세요.\n'
        '【중요 구분 기준】\n'
        '- 스타일러: 전면 투명 유리도어, 내부에 옷걸이(행거) 보임, 드럼(원형 도어) 없음 → 반드시 스타일러. 워시타워·세탁기와 절대 혼동 금지.\n'
        '- 인덕션/전기레인지: 평평한 유리 상판, 원형 화구, 조리기기. 식기세척기와 절대 혼동 금지.\n'
        '- 워시타워: 세탁+건조 일체형, 높이 약 190cm, 도어 2개(위·아래). 단독 세탁기(도어 1개, 높이 85cm)와 반드시 구분.\n'
        '- 세탁기: 단독 기기, 도어 1개. 워시타워처럼 키가 크고 도어가 2개면 워시타워임.\n'
        '겉면의 하자(스크래치, 찌그러짐, 변색, 녹, 파손, 오염)를 빠짐없이 적어주세요.\n'
        + (hint.isNotEmpty
            ? '추가 정보(참고용): "$hint"\n'
            : '')
        + '\n반드시 아래 형식의 JSON 객체만 출력하세요. 다른 설명 금지.\n'
          '{\n'
          '  "종류": "냉장고",\n'
          '  "브랜드": "LG",\n'
          '  "모델명단서": "RT38K..., 오브제컬렉션 추정",\n'
          '  "추정연식": "2019~2021년형 추정",\n'
          '  "하자": ["우측 도어 하단 잔스크래치"],\n'
          '  "상태등급": "A/B/C 중 하나 (A=거의새것, B=사용감보통, C=하자뚜렷)",\n'
          '  "확신도": "상/중/하"\n'
          '}\n'
          '【모델명단서 작성 규칙】\n'
          '1순위: 사진 어디서든 보이는 영숫자 코드를 최대한 읽어 그대로 적기 (부분만 보여도 OK: "GR-Q2..." 처럼)\n'
          '2순위: 코드가 전혀 안 보이면 시리즈명(오브제컬렉션·DIOS·트롬·휘센 등) + 도어수·색상·크기 특징\n'
          '절대 "불명" 단독 사용 금지. 항상 최대한 구체적으로.\n'
          '브랜드: 로고·스티커 기반. 불확실하면 디자인으로 추정해서라도 적기.\n'
          '하자가 없으면 빈 배열.';

    final content = <Map<String, dynamic>>[
      {'type': 'text', 'text': prompt},
      ...dataUrls.map((url) => {
        'type': 'image_url',
        'image_url': {'url': url},
      }),
    ];

    // 제품 식별: 자유형식 응답(useJsonMime:false)이 텍스트 인식에 더 정확
    final raw = await _visionChat(content, maxTokens: 8192, useProModel: true, useJsonMime: false);
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

  /// 모델코드 숫자 패턴에서 용량 등 스펙 추론
  /// 예: Q343MTFF33 → {전체용량(L): '343'}
  ///     F21WD      → {전체용량(L): '21'} (세탁기 kg)
  static Map<String, dynamic>? _inferSpecsFromModelCode(String modelCode, String category) {
    if (modelCode.isEmpty) return null;
    final code = modelCode.toUpperCase().replaceAll(RegExp(r'\s'), '');

    final isWasher = category.contains('세탁기') || category.contains('건조기') || category.contains('워시타워');

    if (isWasher) {
      // 세탁기/건조기: 영문 사이 2자리 숫자 → kg (예: F21WD → 21)
      final m = RegExp(r'[A-Z](\d{2})[A-Z]').firstMatch(code);
      if (m != null) {
        final n = int.tryParse(m.group(1)!);
        if (n != null && n >= 10 && n <= 30) return {'전체용량(L)': n.toString()};
      }
    } else {
      // 냉장고/에어컨 등: 영문 사이 3자리 숫자 → 용량(L) (예: Q343MTFF → 343)
      // 패턴 우선순위: [영문][3자리][영문] > 첫 3자리 숫자
      final m = RegExp(r'[A-Z](\d{3})[A-Z0-9]').firstMatch(code)
             ?? RegExp(r'(\d{3})').firstMatch(code);
      if (m != null) {
        final n = int.tryParse(m.group(1)!);
        if (n != null && n >= 100 && n <= 999) return {'전체용량(L)': n.toString()};
      }
    }

    return null;
  }

  /// DB에 없는 카테고리를 위해 Gemini가 LG 신제품 추천 리스트를 생성
  static Future<List<Map<String, dynamic>>> generateCategoryRecommendations(
    String category,
  ) async {
    final prompt =
        'LG 전자의 "$category" 신제품 중 2023~2025년형 인기 모델 4가지를 추천해줘.\n'
        '반드시 아래 JSON 배열 형식만 출력. 다른 설명 금지.\n'
        '[\n'
        '  {\n'
        '    "model_code": "실제 LG 모델코드 (예: S3RF, S3MFC)",\n'
        '    "name": "공식 제품명",\n'
        '    "price_new_krw": 숫자만(원 단위),\n'
        '    "energy_grade": "1~5 중 하나",\n'
        '    "spec_summary": "핵심 스펙 1줄 (용량·기능 등)"\n'
        '  }\n'
        ']\n'
        '실제 존재하는 LG 모델만 출력. 모름이면 빈 배열 [].';

    try {
      final raw = await _visionChat(
        [{'type': 'text', 'text': prompt}],
        maxTokens: 1000,
        useJsonMime: false,
      );
      final parsed = _extractJsonArray(raw);
      if (parsed == null) return [];
      return parsed
          .whereType<Map<String, dynamic>>()
          .map((r) => {
                ...r,
                'category': category,
                '_sameCategory': true,
                '_aiGenerated': true,
              })
          .toList();
    } catch (_) {
      return [];
    }
  }

  static List<dynamic>? _extractJsonArray(String raw) {
    final s = raw.indexOf('[');
    final e = raw.lastIndexOf(']');
    if (s != -1 && e != -1 && e > s) {
      try {
        return jsonDecode(raw.substring(s, e + 1)) as List<dynamic>;
      } catch (_) {}
    }
    return null;
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

    // Flash도 thinking 토큰(~860)이 maxOutputTokens에 포함 → 4096으로 확보
    final raw = await _visionChat(
      [{'type': 'text', 'text': prompt}],
      maxTokens: 4096,
    );
    return _extractJson(raw) ?? {};
  }

  // ─── 4. Supabase DB 조회로 제품 정보 보정 ───────────────────
  static Future<Map<String, dynamic>> enrichFromDb(
    Map<String, dynamic> product, {
    String? ocrModelCode,
  }) async {
    // OCR에서 "GC-B459FQ8N|Q343MTFF33" 형태로 올 수 있음
    final rawOcr = ocrModelCode?.trim() ?? '';
    final ocrCodes = rawOcr.isNotEmpty ? rawOcr.split('|') : <String>[];
    final aiHint = (product['모델명단서'] as String? ?? '').trim();
    // 검색 우선순위: OCR 코드들 → AI 모델명단서
    final allSearchCodes = [...ocrCodes, if (aiHint.isNotEmpty && aiHint != '불명') aiHint];

    if (allSearchCodes.isEmpty) return product;

    try {
      final db = Supabase.instance.client;

      List<dynamic> rows = [];
      for (final rawCode in allSearchCodes) {
        final baseCode = rawCode.split(RegExp(r'[,\s]')).first.trim();
        final coreCode = baseCode.contains('.') ? baseCode.split('.').first : baseCode;

        // 단계적 검색: 전체코드 → 지역코드 제거 → 앞 6자 prefix
        for (final keyword in {baseCode, coreCode, coreCode.length >= 6 ? coreCode.substring(0, 6) : null}.whereType<String>()) {
          rows = await db
              .from('lg_products')
              .select(
                'model_code, name, category, release_year, price_new_krw, '
                'color, energy_grade, size_mm, weight_kg, thinq_wifi, up_appliance, '
                'capacity_l, dry_capacity_kg, suction_w, power_w, detail_specs',
              )
              .ilike('model_code', '%$keyword%')
              .limit(1);
          if (rows.isNotEmpty) break;
        }
        if (rows.isNotEmpty) break;
      }

      // 코드 검색용 대표값 (로깅/inferSpecs용)
      final searchCode = allSearchCodes.isNotEmpty ? allSearchCodes.first : '';

      // 코드 검색 실패 → 시리즈 키워드로 name 컬럼 검색 (오브제/DIOS/트롬 등)
      if (rows.isEmpty) {
        final desc = '${product['모델명단서'] ?? ''} $searchCode';
        const seriesMap = {
          '오브제': 'objet', 'Objet': 'objet', 'objet': 'objet',
          'DIOS': 'DIOS', '디오스': 'DIOS',
          '트롬': '트롬', 'TWINWash': '트롬', 'TWIN': '트롬',
          '휘센': '휘센', 'WHISEN': '휘센',
          '코드제로': '코드제로', 'CordZero': '코드제로',
          '스타일러': '스타일러', 'STYLER': '스타일러',
          '퓨리케어': '퓨리케어', 'PuriCare': '퓨리케어',
        };
        final category = product['종류'] as String? ?? '';
        for (final kw in seriesMap.keys) {
          if (desc.toLowerCase().contains(kw.toLowerCase())) {
            final kwSearch = seriesMap[kw]!;
            final nameRows = await db
                .from('lg_products')
                .select(
                  'model_code, name, category, release_year, price_new_krw, '
                  'color, energy_grade, size_mm, weight_kg, thinq_wifi, up_appliance, '
                  'capacity_l, dry_capacity_kg, suction_w, power_w, detail_specs',
                )
                .ilike('name', '%$kwSearch%')
                .ilike('category', '%$category%')
                .limit(1);
            if (nameRows.isNotEmpty) {
              rows = nameRows;
              break;
            }
          }
        }
      }

      if (rows.isEmpty) {
        // DB 미매칭 → 모델코드에서 스펙 추론 (용량 등)
        final inferred = _inferSpecsFromModelCode(
          searchCode, product['종류'] as String? ?? '',
        );
        return inferred != null ? {...product, 'inferred_specs': inferred} : product;
      }

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
      // DB 컬럼 우선, null이면 제품명에서 용량 파싱 (예: "344L" → "344")
      if (m['capacity_l'] != null) {
        add('전체용량(L)', m['capacity_l']);
      } else {
        final capMatch = RegExp(r'(\d{3,4})\s*[Ll]').firstMatch(m['name'] as String? ?? '');
        if (capMatch != null) add('전체용량(L)', capMatch.group(1));
      }
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
        '브랜드': 'LG',  // DB 매칭 → LG 제품 확정
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

  /// useProModel=true  → gemini-2.5-pro  (제품 사진 식별)
  /// useProModel=false → gemini-2.5-flash (OCR·견적·룸플래너)
  static Future<String> _visionChat(
    List<Map<String, dynamic>> content, {
    int maxTokens = 1000,
    bool useProModel = false,
    bool useJsonMime = true,  // OCR처럼 자유형식이 필요한 경우 false
  }) async {
    if (_geminiApiKey.isEmpty) {
      throw Exception('Gemini API 키가 설정되지 않았습니다. appraise_service.dart의 _geminiApiKey를 입력하세요.');
    }

    final model = useProModel ? _geminiProModel : _geminiFlashModel;
    final url = Uri.parse('$_geminiBaseUrl/$model:generateContent?key=$_geminiApiKey');

    // OpenAI 포맷 content → Gemini parts 포맷 변환
    final parts = <Map<String, dynamic>>[];
    for (final item in content) {
      if (item['type'] == 'text') {
        parts.add({'text': item['text'] as String});
      } else if (item['type'] == 'image_url') {
        final dataUrl = (item['image_url'] as Map)['url'] as String;
        // "data:image/jpeg;base64,{base64}" 파싱
        final semiIdx   = dataUrl.indexOf(';');
        final commaIdx  = dataUrl.indexOf(',');
        if (semiIdx != -1 && commaIdx != -1) {
          final mimeType   = dataUrl.substring(5, semiIdx); // 'data:' 다음
          final base64Data = dataUrl.substring(commaIdx + 1);
          parts.add({
            'inlineData': {'mimeType': mimeType, 'data': base64Data},
          });
        }
      }
    }

    final generationConfig = <String, dynamic>{
      'maxOutputTokens': maxTokens,
      'temperature': 0.2,
    };
    if (useJsonMime) generationConfig['responseMimeType'] = 'application/json';

    final bodyStr = jsonEncode({
      'contents': [{'parts': parts}],
      'generationConfig': generationConfig,
    });

    // 503(과부하) 시 최대 3회 재시도, 지수 백오프
    http.Response resp;
    int attempt = 0;
    while (true) {
      // ignore: avoid_print
      print('[Gemini] 요청 시작 model=$model attempt=$attempt body=${bodyStr.length}bytes');
      resp = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: bodyStr,
          )
          .timeout(const Duration(seconds: 120));
      // ignore: avoid_print
      print('[Gemini] 응답 status=${resp.statusCode} body=${resp.body.length}bytes');

      if (resp.statusCode != 503 || attempt >= 2) break;
      attempt++;
      await Future.delayed(Duration(seconds: 2 * attempt));
    }

    if (resp.statusCode != 200) {
      throw Exception('Gemini API 오류 ${resp.statusCode}: ${resp.body}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Gemini 응답이 비어있습니다.');
    }
    final first = candidates.first as Map<String, dynamic>;
    // 안전 필터 차단 시 candidate content가 null일 수 있음
    final candidateContent = first['content'] as Map<String, dynamic>?;
    if (candidateContent == null) {
      final reason = first['finishReason'] as String? ?? 'UNKNOWN';
      throw Exception('Gemini 응답 차단됨 (finishReason: $reason)');
    }
    final resParts = candidateContent['parts'] as List?;
    if (resParts == null || resParts.isEmpty) return '';
    return (resParts.first['text'] as String?) ?? '';
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
      // ignore: avoid_print
      print('[Exa] 검색: $query');
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

      // ignore: avoid_print
      print('[Exa] status=${resp.statusCode} body=${resp.body.length}bytes');
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final results = List<Map<String, dynamic>>.from(data['results'] ?? []);
      // ignore: avoid_print
      print('[Exa] 결과 ${results.length}개');
      return results;
    } catch (e) {
      // ignore: avoid_print
      print('[Exa] 실패: $e');
      return [];
    }
  }

  // Exa 실패 시 AI로 중고 매물 데이터 생성
  static Future<List<Map<String, dynamic>>> generateUsedListings(
    String category,
    String brand,
    String model, {
    int priceMin = 0,
    int priceMax = 0,
  }) async {
    final priceHint = priceMin > 0
        ? '시세 범위: ${priceMin ~/ 10000}만~${priceMax ~/ 10000}만원'
        : '';
    final prompt =
        '한국 중고 가전 마켓(번개장터, 당근마켓)에서 "$brand $category $model" 와 비슷한 매물 4개를 생성해주세요.\n'
        '$priceHint\n'
        '실제 매물처럼 자연스럽게, 각 항목:\n'
        '- title: 판매 글 제목 (30자 이내)\n'
        '- text: 매물 설명 (50자 이내)\n'
        '- url: 빈 문자열\n'
        '- _source: "번개장터" 또는 "당근마켓"\n'
        '- _price: 만원 단위 정수 (예: 350000)\n'
        'JSON 배열만 출력하세요.';

    try {
      final raw = await _visionChat(
        [{'type': 'text', 'text': prompt}],
        maxTokens: 800,
        useProModel: false,
        useJsonMime: false,
      );
      final arr = _extractJsonArray(raw);
      if (arr != null) {
        return arr.cast<Map<String, dynamic>>()
            .map((e) => {
                  'title': e['title'] ?? '',
                  'text': e['text'] ?? '',
                  'url': e['url'] ?? '',
                  '_source': e['_source'] ?? '중고마켓',
                  '_price': e['_price'] ?? 0,
                  '_aiGenerated': true,
                })
            .toList();
      }
    } catch (_) {}
    return [];
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
