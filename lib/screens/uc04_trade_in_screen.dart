import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lg_move_in/models/move_in_state.dart';
import 'package:lg_move_in/screens/uc04_lg_tradein_screen.dart';
import 'package:lg_move_in/screens/uc04_marketplace_screen.dart';
import 'package:lg_move_in/services/appraise_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class UC04TradeInScreen extends StatefulWidget {
  const UC04TradeInScreen({super.key});

  @override
  State<UC04TradeInScreen> createState() => _UC04TradeInScreenState();
}

class _UC04TradeInScreenState extends State<UC04TradeInScreen> {
  int _step = 0;
  bool _isAnalyzing = false;
  int _analysisPhase = 0;
  bool _posted = false;
  String? _selectedCategory;
  String? _labelDataUrl;         // 모델 라벨 사진 (OCR용)
  final _purchaseYearCtrl = TextEditingController();
  final _sizeHintCtrl = TextEditingController();

  static const _categories = [
    '냉장고', '김치냉장고', '세탁기', '건조기', '워시타워',
    '에어컨', '공기청정기', '청소기', '스타일러',
    '식기세척기', '전자레인지/오븐', '인덕션', '정수기', '제습기',
  ];

  // 가이드 슬롯 (순서 고정: 정면이 기본 썸네일)
  static const _slotLabels = ['정면', '후면', '측면', '하자 부위'];
  static const _slotIcons  = [Icons.photo_camera_outlined, Icons.flip_outlined, Icons.rotate_90_degrees_cw_outlined, Icons.report_problem_outlined];
  final _photoSlots = <String, String?>{'정면': null, '후면': null, '측면': null, '하자 부위': null};
  String _thumbnailSlot = '정면';

  List<String> get _dataUrls => _photoSlots.values.whereType<String>().toList();

  // AI 분석 결과 - 수정 가능
  final _categoryCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _gradeCtrl = TextEditingController();
  final _defects = <String>[];
  String _confidence = '중';

  // 견적 결과
  String _newPrice = '';
  int _priceMin = 0;
  int _priceMax = 0;
  int _priceRec = 0;
  String _priceReason = '';
  final _titleCtrl = TextEditingController();
  final _bodyCtrl  = TextEditingController();
  String _disposalMethod = '중고마켓';
  Map<String, String> _dbSpecs = {};
  List<Map<String, dynamic>> _recommendations = [];
  bool _loadingRecs = false;



  static const _analysisLabels = [
    '📷  사진 분석 중...',
    '🔍  제품 인식 중...',
    '💹  중고 시세 검색 중...',
    '📝  판매글 작성 중...',
  ];

  @override
  void dispose() {
    _categoryCtrl.dispose();
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _yearCtrl.dispose();
    _gradeCtrl.dispose();
    _purchaseYearCtrl.dispose();
    _sizeHintCtrl.dispose();
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  // ─── 파일 선택 ───────────────────────────────────────────────

  Future<void> _pickLabelImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image, allowMultiple: false, withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    final bytes = f.bytes;
    if (bytes == null) return;
    final ext = (f.extension ?? 'jpg').toLowerCase();
    final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
    setState(() => _labelDataUrl = 'data:$mime;base64,${base64Encode(bytes)}');
  }

  Future<void> _pickSlotImage(String slot) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image, allowMultiple: false, withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    final bytes = f.bytes;
    if (bytes == null) return;
    final ext = (f.extension ?? 'jpg').toLowerCase();
    final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
    setState(() {
      _photoSlots[slot] = 'data:$mime;base64,${base64Encode(bytes)}';
      // 정면이 비어 있었는데 다른 슬롯을 먼저 찍은 경우, 썸네일을 첫 번째 찍은 사진으로
      if (_thumbnailSlot == '정면' && _photoSlots['정면'] == null) {
        _thumbnailSlot = slot;
      }
    });
  }

  Future<void> _pickExtraPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image, allowMultiple: false, withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    final bytes = f.bytes;
    if (bytes == null) return;
    final ext = (f.extension ?? 'jpg').toLowerCase();
    final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
    setState(() {
      final extraCount = _photoSlots.keys.where((k) => k.startsWith('추가')).length;
      final key = '추가${extraCount + 1}';
      _photoSlots[key] = 'data:$mime;base64,${base64Encode(bytes)}';
    });
  }

  // ─── AI 분석 (3단계) ─────────────────────────────────────────

  Future<void> _startAnalysis() async {
    if (_dataUrls.isEmpty) return;

    setState(() {
      _isAnalyzing = true;
      _analysisPhase = 0;
    });

    try {
      // 0) 라벨 OCR → 모델코드 추출
      // 전용 라벨 사진 → 후면 → 측면 → 정면 순서로 첫 번째 유효 코드 사용
      String? ocrModelCode;
      setState(() => _analysisPhase = 0);
      final ocrCandidates = [
        _labelDataUrl,
        _photoSlots['후면'],
        _photoSlots['측면'],
        _photoSlots['정면'],
      ].whereType<String>().toList();
      final candidateNames = ['라벨', '후면', '측면', '정면'];
      for (int i = 0; i < ocrCandidates.length; i++) {
        final label = i < candidateNames.length ? candidateNames[i] : '추가$i';
        // ignore: avoid_print
        print('[OCR시도] $label 사진');
        final code = await AppraiseService.ocrModelLabel(ocrCandidates[i]);
        // ignore: avoid_print
        print('[OCR결과] $label → ${code ?? '인식실패'}');
        if (code != null && code.isNotEmpty) {
          ocrModelCode = code;
          break;
        }
      }

      // 1) 제품 식별 — 4슬롯 + 라벨 사진 전송
      setState(() => _analysisPhase = 1);
      final mainPhotos = [
        ..._slotLabels.map((s) => _photoSlots[s]).whereType<String>(),
        if (_labelDataUrl != null) _labelDataUrl!,
      ];
      final raw = await AppraiseService.identifyProduct(
        mainPhotos,
        categoryHint: _selectedCategory,
        modelCodeFromOcr: ocrModelCode,
      );
      if (raw == null) throw Exception('제품을 인식하지 못했습니다. 사진을 다시 찍어주세요.');

      // 1-b) Supabase DB로 제품 정보 보정 (OCR 모델코드 우선)
      final product = await AppraiseService.enrichFromDb(
        raw, ocrModelCode: ocrModelCode,
      );


      // 2) 시세 검색
      setState(() => _analysisPhase = 2);
      final priceData = await AppraiseService.searchPrices(
        product,
        purchaseYear: _purchaseYearCtrl.text.trim(),
        sizeHint: _sizeHintCtrl.text.trim(),
      );

      // 3) 견적 + 판매글 생성
      setState(() => _analysisPhase = 3);
      final listing = await AppraiseService.generateListing(
        product,
        priceData['used'] ?? [],
        priceData['new'] ?? [],
        priceStats: (priceData['stats'] as Map<String, dynamic>?) ?? {},
      );

      // 결과 반영
      setState(() {
        // 사용자가 카테고리를 직접 선택했으면 AI 판단보다 우선
        _categoryCtrl.text = (_selectedCategory != null && _selectedCategory!.isNotEmpty)
            ? _selectedCategory!
            : (product['종류'] as String? ?? '가전');
        _brandCtrl.text = product['브랜드'] as String? ?? '불명';
        // 모델명: DB 매칭 → OCR 코드 → AI 인식 순서로 fallback
        final dbModel  = product['db모델코드'] as String? ?? '';
        final aiModel  = product['모델명단서'] as String? ?? '';
        // aiModel이 실제 모델코드인지 판단 (영숫자 4자 이상 포함, '불명'·'추정' 없음)
        final hasRealCode = aiModel.isNotEmpty &&
            !aiModel.contains('불명') &&
            !aiModel.contains('추정') &&
            RegExp(r'[A-Za-z0-9]{4,}').hasMatch(aiModel);
        _modelCtrl.text = dbModel.isNotEmpty
            ? '$dbModel ($aiModel)'
            : hasRealCode
                ? aiModel
                : (ocrModelCode?.isNotEmpty == true ? ocrModelCode! : aiModel.isNotEmpty ? aiModel : '불명');
        // DB 연식 우선, 없으면 AI 추정
        _yearCtrl.text = product['db연식'] as String?
            ?? product['추정연식'] as String? ?? '불명';
        _gradeCtrl.text = product['상태등급'] as String? ?? 'B';
        _confidence = product['확신도'] as String? ?? '중';
        _defects
          ..clear()
          ..addAll(List<String>.from(product['하자'] ?? []));

        _newPrice = listing['신품가추정'] as String? ?? '시세 확인 필요';
        _priceMin = (listing['중고최저'] as num?)?.toInt() ?? 0;
        _priceMax = (listing['중고최고'] as num?)?.toInt() ?? 0;
        _priceRec = (listing['희망판매가'] as num?)?.toInt() ?? 0;
        _priceReason = listing['견적근거'] as String? ?? '';
        _titleCtrl.text = listing['판매제목'] as String? ?? '${_brandCtrl.text} ${_categoryCtrl.text} 판매합니다';
        _bodyCtrl.text  = listing['판매본문'] as String? ?? '';

        // inferred_specs(모델코드 추론)와 db스펙 병합 — DB 값 우선
        _dbSpecs = {
          ...(product['inferred_specs'] as Map<String, dynamic>? ?? {})
              .map((k, v) => MapEntry(k, v.toString())),
          ...(product['db스펙'] as Map<String, dynamic>? ?? {})
              .map((k, v) => MapEntry(k, v.toString())),
        };
        _isAnalyzing = false;
        _step = 1;
      });
    } catch (e, st) {
      // ignore: avoid_print
      print('[분석 실패] $e\n$st');
      setState(() => _isAnalyzing = false);
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('분석 실패'),
            content: SingleChildScrollView(child: Text(e.toString())),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인'))],
          ),
        );
      }
    }
  }

  void _addDefect() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('하자 추가', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '예: 우측 도어 스크래치', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            onPressed: () {
              final text = ctrl.text.trim();
              if (text.isNotEmpty) setState(() => _defects.add(text));
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2B2A27), foregroundColor: Colors.white),
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  Future<void> _recalculatePrice() async {
    setState(() => _isAnalyzing = true);
    try {
      // 사용자가 수정한 필드값으로 product map 재구성
      final inputModel = _modelCtrl.text
          .split(RegExp(r'[\s(,]'))
          .first
          .trim()
          .replaceAll(RegExp(r'[^A-Za-z0-9\-]'), '');
      final product = {
        '종류': _categoryCtrl.text,
        '브랜드': _brandCtrl.text,
        '모델명단서': _modelCtrl.text,
        '추정연식': _yearCtrl.text,
        '상태등급': _gradeCtrl.text,
        '하자': _defects,
        '확신도': _confidence,
        'db모델코드': inputModel,
      };

      // 수동 입력 모델코드로 DB 스펙 조회 → 추천 정확도 향상
      if (inputModel.length >= 4) {
        try {
          final db = Supabase.instance.client;
          final row = await db
              .from('lg_products')
              .select('capacity_l, dry_capacity_kg, suction_w, energy_grade, detail_specs')
              .ilike('model_code', '%$inputModel%')
              .maybeSingle();
          if (row != null) {
            setState(() {
              _dbSpecs = {
                ..._dbSpecs,
                if (row['capacity_l'] != null) 'capacity_l': row['capacity_l'].toString(),
                if (row['dry_capacity_kg'] != null) '건조용량(kg)': row['dry_capacity_kg'].toString(),
                if (row['suction_w'] != null) '최대흡입력(W)': row['suction_w'].toString(),
                if (row['energy_grade'] != null) '에너지등급': row['energy_grade'].toString(),
                ...((row['detail_specs'] as Map<String, dynamic>? ?? {})
                    .map((k, v) => MapEntry(k, v.toString()))),
              };
            });
          }
        } catch (_) {}
      }

      final priceData = await AppraiseService.searchPrices(
        product,
        purchaseYear: _purchaseYearCtrl.text.trim(),
        sizeHint: _sizeHintCtrl.text.trim(),
      );
      final listing = await AppraiseService.generateListing(
        product,
        priceData['used'] ?? [],
        priceData['new'] ?? [],
      );

      setState(() {
        _newPrice  = listing['신품가추정'] as String? ?? '';
        _priceMin  = (listing['중고최저'] as num?)?.toInt() ?? 0;
        _priceMax  = (listing['중고최고'] as num?)?.toInt() ?? 0;
        _priceRec  = (listing['희망판매가'] as num?)?.toInt() ?? 0;
        _priceReason = listing['견적근거'] as String? ?? '';
        _titleCtrl.text = listing['판매제목'] as String? ?? '';
        _bodyCtrl.text  = listing['판매본문'] as String? ?? '';
        _isAnalyzing = false;
        _step = 2;
      });
      // 분석 완료 즉시 추천 로딩 시작 (백그라운드)
      _loadRecommendations();
    } catch (e) {
      setState(() => _isAnalyzing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('시세 계산 실패: $e'),
            backgroundColor: const Color(0xFF2B2A27),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }



  // AI가 반환한 카테고리명 → DB 카테고리명 정규화
  String _normalizeCategory(String raw) {
    final s = raw.trim();
    if (s.contains('전자레인지') || s.contains('오븐')) return '전자레인지';
    if (s.contains('워시타워')) return '워시타워';
    if (s.contains('세탁기')) return '세탁기';
    if (s.contains('냉장고')) return s.contains('김치') ? '김치냉장고' : '냉장고';
    if (s.contains('에어컨')) return '에어컨';
    if (s.contains('청소기')) return '청소기';
    if (s.contains('건조기')) return '건조기';
    if (s.contains('스타일러')) return '스타일러';
    if (s.contains('식기세척기')) return '식기세척기';
    if (s.contains('공기청정기')) return '공기청정기';
    if (s.contains('인덕션')) return '인덕션';
    if (s.contains('정수기')) return '정수기';
    if (s.contains('제습기')) return '제습기';
    return s;
  }

  /// LG 공식 사이트에서 모델코드 검색 → 유사 제품 모델코드 추출
  Future<List<String>> _fetchLgSimilarModels(String modelCode) async {
    try {
      final uri = Uri.parse(
        'https://www.lge.co.kr/search?searchrword=${Uri.encodeComponent(modelCode)}',
      );
      final res = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36',
        'Accept-Language': 'ko-KR,ko;q=0.9',
      }).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return [];

      final body = res.body;
      final me = modelCode.toUpperCase();
      final found = <String>{};

      // LG 제품 URL 패턴: /category/MODELCODE.html
      for (final m in RegExp(r'/([A-Z][A-Z0-9\-]{5,20})\.html', caseSensitive: false).allMatches(body)) {
        final code = m.group(1)!.toUpperCase().replaceAll('-', '');
        if (code != me && code.length >= 6) found.add(code);
      }
      // data 속성 패턴: data-model-id="MODELCODE" 등
      for (final m in RegExp("data-model(?:name|code|-id|-name)?=[\"']([A-Z0-9\\-]{6,20})[\"']", caseSensitive: false).allMatches(body)) {
        final code = m.group(1)!.toUpperCase();
        if (code != me) found.add(code);
      }
      // JSON 패턴: "modelCode":"MODELCODE"
      for (final m in RegExp(r'"modelCode"\s*:\s*"([A-Z0-9\-]{6,20})"', caseSensitive: false).allMatches(body)) {
        final code = m.group(1)!.toUpperCase();
        if (code != me) found.add(code);
      }

      return found.take(15).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _loadRecommendations() async {
    if (_loadingRecs) return; // 중복 호출 방지
    final category = _normalizeCategory(_categoryCtrl.text);
    if (category.isEmpty) return;
    setState(() => _loadingRecs = true);
    try {
      final db = Supabase.instance.client;

      // 내 제품 스펙 파싱
      final myCapacity = double.tryParse(
        (_dbSpecs['전체용량(L)'] ?? _dbSpecs['capacity_l'] ?? '').replaceAll(RegExp(r'[^0-9.]'), ''),
      );
      final myDryCap = double.tryParse(
        (_dbSpecs['건조용량(kg)'] ?? '').replaceAll(RegExp(r'[^0-9.]'), ''),
      );
      final mySuction = double.tryParse(
        (_dbSpecs['최대흡입력(W)'] ?? '').replaceAll(RegExp(r'[^0-9.]'), ''),
      );
      final myGrade = int.tryParse(
        (_dbSpecs['에너지등급'] ?? '').replaceAll(RegExp(r'[^0-9]'), ''),
      );

      const cols = 'model_code, name, category, color, energy_grade, '
          'capacity_l, dry_capacity_kg, suction_w, power_w, '
          'size_mm, thinq_wifi, up_appliance, price_new_krw, images, product_url';

      // ── 1순위: LG 공식 사이트 검색 기반 추천 ──
      final rawModel = _modelCtrl.text
          .split(RegExp(r'[\s(,]'))
          .first
          .trim()
          .replaceAll(RegExp(r'[^A-Za-z0-9\-]'), '');
      if (rawModel.length >= 6) {
        final lgModels = await _fetchLgSimilarModels(rawModel);
        if (lgModels.isNotEmpty) {
          final lgRows = await db
              .from('lg_products')
              .select(cols)
              .inFilter('model_code', lgModels)
              .eq('category', category)
              .order('energy_grade', ascending: true)
              .order('price_new_krw', ascending: false)
              .limit(6);
          if (lgRows.isNotEmpty) {
            setState(() {
              _recommendations = List<Map<String, dynamic>>.from(lgRows)
                  .map((r) => {...r, '_sameCategory': true})
                  .toList();
              _loadingRecs = false;
            });
            return;
          }
        }
      }

      // ── 2순위: 용량 기반 클라이언트 사이드 필터 ──
      // ── 같은 카테고리 전체 로드 후 클라이언트 사이드 스펙 필터 ──
      // DB capacity_l이 null인 제품이 많으므로 제품명에서도 용량 추출
      Future<List> fetchSameCategory() async {
        final allRows = List<Map<String, dynamic>>.from(
          await db.from('lg_products').select(cols)
              .eq('category', category)
              .order('energy_grade', ascending: true)
              .order('price_new_krw', ascending: false)
              .limit(60),
        );
        if (allRows.isEmpty) return [];

        // DB 컬럼 우선, null이면 제품명에서 추출 (예: "344L" → 344.0)
        double? rowCapacity(Map<String, dynamic> row) {
          final col = row['capacity_l'];
          if (col != null) return (col as num).toDouble();
          final name = row['name'] as String? ?? '';
          final m = RegExp(r'(\d{3,4})\s*[Ll]').firstMatch(name);
          if (m != null) return double.tryParse(m.group(1)!);
          return null;
        }

        if (myCapacity != null && myCapacity > 0) {
          final lo = myCapacity * 0.80, hi = myCapacity * 1.20;

          // 1차: 용량 ±20% + 에너지등급 같거나 더 좋음
          final tier1 = allRows.where((r) {
            final cap = rowCapacity(r);
            if (cap == null || cap < lo || cap > hi) return false;
            if (myGrade != null) {
              final g = (r['energy_grade'] as num?)?.toInt();
              if (g != null && g > myGrade) return false;
            }
            return true;
          }).take(6).toList();
          if (tier1.isNotEmpty) return tier1;

          // 2차: 용량 ±20%, 등급 무시
          final tier2 = allRows.where((r) {
            final cap = rowCapacity(r);
            return cap != null && cap >= lo && cap <= hi;
          }).take(6).toList();
          if (tier2.isNotEmpty) return tier2;
        }

        // 건조용량 ±20% (건조기/워시타워)
        if (myDryCap != null && myDryCap > 0) {
          final lo = myDryCap * 0.80, hi = myDryCap * 1.20;
          final tier = allRows.where((r) {
            final cap = (r['dry_capacity_kg'] as num?)?.toDouble();
            return cap != null && cap >= lo && cap <= hi;
          }).take(6).toList();
          if (tier.isNotEmpty) return tier;
        }

        // 흡입력 ±20% (청소기)
        if (mySuction != null && mySuction > 0) {
          final lo = mySuction * 0.80, hi = mySuction * 1.20;
          final tier = allRows.where((r) {
            final s = (r['suction_w'] as num?)?.toDouble();
            return s != null && s >= lo && s <= hi;
          }).take(6).toList();
          if (tier.isNotEmpty) return tier;
        }

        // 최종: 스펙 불명 → 카테고리 전체 (이미 정렬됨)
        return allRows.take(6).toList();
      }

      final sameRows = await fetchSameCategory();
      final same = List<Map<String, dynamic>>.from(sameRows)
          .map((r) => {...r, '_sameCategory': true}).toList();

      // DB에 카테고리 없으면 Gemini로 AI 추천 생성
      if (same.isEmpty) {
        final aiRecs = await AppraiseService.generateCategoryRecommendations(category);
        setState(() {
          _recommendations = aiRecs;
          _loadingRecs = false;
        });
        return;
      }

      // ── 다른 카테고리 보충: 같은 카테고리가 3개 이상 확보됐을 때만 ──
      final need = 6 - same.length;
      final excludeSet = same.map((e) => e['model_code'] as String).toSet();
      final other = (need > 0 && same.length >= 3)
          ? List<Map<String, dynamic>>.from(
              await db.from('lg_products').select(cols)
                  .neq('category', category)
                  .not('price_new_krw', 'is', null)
                  .order('energy_grade', ascending: true)
                  .order('price_new_krw', ascending: false)
                  .limit(need + same.length),
            ).where((e) => !excludeSet.contains(e['model_code'] as String)).take(need)
              .map((r) => {...r, '_sameCategory': false}).toList()
          : <Map<String, dynamic>>[];

      setState(() {
        _recommendations = [...same, ...other];
        _loadingRecs = false;
      });
    } catch (e) {
      setState(() => _loadingRecs = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('추천 제품 로드 오류: $e'),
            backgroundColor: const Color(0xFF2B2A27),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  void _postToMarket() {
    final listing = TradeInListing(
      id: 'mine_${DateTime.now().millisecondsSinceEpoch}',
      category: _categoryCtrl.text,
      brand: _brandCtrl.text,
      modelHint: _modelCtrl.text,
      title: _titleCtrl.text.isNotEmpty ? _titleCtrl.text : '${_brandCtrl.text} ${_categoryCtrl.text} 판매합니다',
      body: _bodyCtrl.text.isNotEmpty
          ? _bodyCtrl.text
          : '이사로 인해 처분합니다. 직거래 가능하며 소폭 네고 됩니다.',
      price: _priceRec,
      priceMin: _priceMin,
      priceMax: _priceMax,
      grade: _gradeCtrl.text,
      defects: List.from(_defects),
      postedAt: DateTime.now(),
      isMine: true,
      seller: '나 (MoveIn 사용자)',
      imageDataUrl: _photoSlots[_thumbnailSlot] ?? _dataUrls.firstOrNull,
    );
    MoveInState.instance.marketListings.insert(0, listing);
    setState(() {
      _posted = true;
      _step = 3;
    });
    _loadRecommendations();
  }

  // ─── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 트레이드인'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2B2A27),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_step == 0) {
              // 1단계(사진): MoveIn 홈으로
              Navigator.pop(context);
            } else {
              // 2단계 이상: 이전 단계로
              setState(() {
                _step--;
                // 시세확인(step 2)으로 돌아오면 게시 완료 상태 초기화
                if (_step == 2) _posted = false;
              });
            }
          },
        ),
        actions: [
          // 홈으로 버튼
          if (_step > 0)
            IconButton(
              icon: const Icon(Icons.home_outlined),
              tooltip: '무브인 홈',
              onPressed: () => Navigator.pop(context),
            ),
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UC04MarketplaceScreen()),
            ),
            icon: const Icon(Icons.storefront_outlined, size: 18),
            label: const Text('마켓', style: TextStyle(fontSize: 13)),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF2B2A27)),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStepProgress(),
          Expanded(child: _isAnalyzing ? _buildAnalyzing() : _buildStep()),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget? _buildBottomNavigationBar() {
    if (_isAnalyzing) return null;

    final priceRec = _priceRec > 0 ? '${(_priceRec / 10000).round()}만원' : '-';

    switch (_step) {
      case 0:
        return Container(
          color: const Color(0xFFF5F3EE),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: SafeArea(
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _dataUrls.isNotEmpty ? _startAnalysis : null,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('AI 감정 시작', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE6007E),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFE0DED8),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        );
      case 1:
        return Container(
          color: const Color(0xFFF5F3EE),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: SafeArea(
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isAnalyzing ? null : _recalculatePrice,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2B2A27),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isAnalyzing
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('이 정보로 시세 계산하기', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        );
      case 2:
        return Container(
          color: const Color(0xFFF5F3EE),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: SafeArea(
            child: _buildDisposalAction(priceRec),
          ),
        );
      default:
        return null;
    }
  }

  Widget _buildStep() {
    return switch (_step) {
      0 => _buildStepCapture(),
      1 => _buildStepResult(),
      2 => _buildStepQuote(),
      3 => _buildStepRecommend(),
      _ => const SizedBox.shrink(),
    };
  }

  // ─── 스텝 진행 표시 ──────────────────────────────────────────

  Widget _buildStepProgress() {
    const steps = ['사진', '분석 결과', '시세 확인', '제품 추천'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF0EEE8))),
      ),
      child: Row(
        children: List.generate(steps.length, (i) {
          final done = i < _step;
          final active = i == _step;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 26, height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: done
                              ? const Color(0xFF2B2A27)
                              : active
                                  ? const Color(0xFFE6007E)
                                  : const Color(0xFFF0EEE8),
                        ),
                        child: Center(
                          child: done
                              ? const Icon(Icons.check, size: 13, color: Colors.white)
                              : Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    color: active ? Colors.white : const Color(0xFFADA9A1),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        steps[i],
                        style: TextStyle(
                          fontSize: 10,
                          color: active
                              ? const Color(0xFFE6007E)
                              : done
                                  ? const Color(0xFF2B2A27)
                                  : const Color(0xFFADA9A1),
                          fontWeight: active || done ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < steps.length - 1)
                  Container(
                    width: 18, height: 1.5,
                    margin: const EdgeInsets.only(bottom: 14),
                    color: done ? const Color(0xFF2B2A27) : const Color(0xFFE0DED8),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ─── 분석 로딩 ───────────────────────────────────────────────

  Widget _buildAnalyzing() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFFE6007E), strokeWidth: 3),
          const SizedBox(height: 32),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _analysisLabels[_analysisPhase],
              key: ValueKey(_analysisPhase),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2B2A27)),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'AI가 브랜드, 상태 및 시세 데이터를 매칭하고 있습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF8A877F), fontSize: 13),
          ),
          const SizedBox(height: 40),
          Row(
            children: List.generate(4, (i) => Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: i <= _analysisPhase
                      ? const Color(0xFFE6007E)
                      : const Color(0xFFE0DED8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildAuxInput(TextEditingController ctrl, String label, String hint, IconData icon) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFFADA9A1)),
        prefixIcon: Icon(icon, size: 16, color: const Color(0xFF8A877F)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE0DED8))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE0DED8))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2B2A27))),
      ),
    );
  }

  // ─── Step 0: 사진 선택 ───────────────────────────────────────

  Widget _buildStepCapture() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF2B2A27),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('처분할 가전 사진을 올려주세요', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 6),
                Text('AI가 모델명·상태를 인식하고\n중고 시세와 처분 방식을 추천해드립니다.', style: TextStyle(color: Color(0xFFADA9A1), fontSize: 13, height: 1.5)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 라벨 사진 (OCR)
          Row(
            children: [
              const Text('모델 라벨 사진', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFE6007E), borderRadius: BorderRadius.circular(10)),
                child: const Text('정확도 UP', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _pickLabelImage,
            child: Container(
              width: double.infinity,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _labelDataUrl != null ? const Color(0xFFE6007E) : const Color(0xFFE0DED8),
                  width: _labelDataUrl != null ? 2 : 1,
                ),
              ),
              child: _labelDataUrl != null
                  ? Stack(
                      alignment: Alignment.topRight,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Image.memory(
                            base64Decode(_labelDataUrl!.split(',').last),
                            width: double.infinity, height: 90, fit: BoxFit.cover,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _labelDataUrl = null),
                          child: Container(
                            margin: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.close, size: 16, color: Colors.white),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(left: 8, bottom: 6),
                          alignment: Alignment.bottomLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: const Color(0xFFE6007E), borderRadius: BorderRadius.circular(8)),
                            child: const Text('OCR 적용됨', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.document_scanner_outlined, size: 28, color: Color(0xFF8A877F)),
                        SizedBox(height: 4),
                        Text('제품 옆면·뒷면의 모델 스티커 사진', style: TextStyle(fontSize: 12, color: Color(0xFF5F5D58))),
                        Text('모델번호를 AI가 정확히 읽어냅니다', style: TextStyle(fontSize: 11, color: Color(0xFFADA9A1))),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 20),

          // 카테고리 선택
          const Text('제품 종류', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2B2A27))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categories.map((cat) {
              final selected = _selectedCategory == cat;
              return GestureDetector(
                onTap: () => setState(() =>
                  _selectedCategory = selected ? null : cat,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFF2B2A27) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? const Color(0xFF2B2A27) : const Color(0xFFE0DED8),
                    ),
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      fontSize: 13,
                      color: selected ? Colors.white : const Color(0xFF5F5D58),
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // 보조 입력: 구매연도 + 크기/용량
          Row(
            children: [
              Expanded(child: _buildAuxInput(_purchaseYearCtrl, '구매 연도', '예: 2021', Icons.calendar_today_outlined)),
              const SizedBox(width: 10),
              Expanded(child: _buildAuxInput(_sizeHintCtrl, '크기 / 용량', '예: 800L, 15kg', Icons.straighten_outlined)),
            ],
          ),
          const SizedBox(height: 6),
          const Text('입력할수록 가격 정확도가 높아져요 (선택)', style: TextStyle(fontSize: 11, color: Color(0xFFADA9A1))),
          const SizedBox(height: 20),

          // 가이드 사진 슬롯
          Row(
            children: [
              const Text('제품 사진', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(width: 6),
              Text('${_dataUrls.length}장', style: const TextStyle(fontSize: 12, color: Color(0xFF8A877F))),
            ],
          ),
          const SizedBox(height: 8),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.15,
            children: [
              // ── 고정 4 슬롯 ──
              ...List.generate(_slotLabels.length, (i) {
                final slot = _slotLabels[i];
                final photo = _photoSlots[slot];
                final isThumbnail = _thumbnailSlot == slot && photo != null;
                return GestureDetector(
                  onTap: () => _pickSlotImage(slot),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: photo != null ? const Color(0xFF2B2A27) : const Color(0xFFE0DED8),
                        width: photo != null ? 1.5 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: photo != null
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.memory(base64Decode(photo.split(',').last), fit: BoxFit.cover),
                                if (isThumbnail)
                                  Positioned(
                                    top: 6, left: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(color: const Color(0xFFE6007E), borderRadius: BorderRadius.circular(8)),
                                      child: const Text('썸네일', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                Positioned(
                                  bottom: 0, left: 0, right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    color: Colors.black45,
                                    child: Text(slot, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                Positioned(
                                  top: 4, right: 4,
                                  child: GestureDetector(
                                    onTap: () => setState(() {
                                      _photoSlots[slot] = null;
                                      if (_thumbnailSlot == slot) {
                                        _thumbnailSlot = _photoSlots.entries.firstWhere((e) => e.value != null, orElse: () => const MapEntry('정면', null)).key;
                                      }
                                    }),
                                    child: Container(
                                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                      child: const Icon(Icons.close, size: 16, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(_slotIcons[i], size: 28, color: const Color(0xFFADA9A1)),
                                const SizedBox(height: 6),
                                Text(slot, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF5F5D58))),
                                const SizedBox(height: 2),
                                Text(
                                  slot == '정면' ? '마켓 썸네일로 사용' : '선택사항',
                                  style: TextStyle(fontSize: 10, color: slot == '정면' ? const Color(0xFFE6007E) : const Color(0xFFADA9A1)),
                                ),
                              ],
                            ),
                    ),
                  ),
                );
              }),
            ],
          ),

          // ── 추가 사진 (가로 바) ──
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 88),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0F7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE6007E).withValues(alpha: 0.35), width: 1.5),
            ),
            child: () {
              final extras = _photoSlots.entries.where((e) => e.key.startsWith('추가')).toList();
              if (extras.isEmpty) {
                return GestureDetector(
                  onTap: _pickExtraPhoto,
                  child: const SizedBox(
                    height: 88,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, size: 22, color: Color(0xFFE6007E)),
                        SizedBox(width: 8),
                        Text('추가 사진', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFE6007E))),
                        SizedBox(width: 6),
                        Text('선택사항', style: TextStyle(fontSize: 11, color: Color(0xFFADA9A1))),
                      ],
                    ),
                  ),
                );
              }
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    ...extras.map((e) {
                      final slot = e.key;
                      final photo = e.value!;
                      final isThumbnail = _thumbnailSlot == slot;
                      return GestureDetector(
                        onTap: () => setState(() => _thumbnailSlot = slot),
                        child: Container(
                          width: 68, height: 68,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isThumbnail ? const Color(0xFFE6007E) : const Color(0xFF2B2A27),
                              width: isThumbnail ? 2.5 : 1.5,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.memory(base64Decode(photo.split(',').last), fit: BoxFit.cover),
                                if (isThumbnail)
                                  Container(
                                    color: const Color(0xFFE6007E).withValues(alpha: 0.2),
                                    child: const Icon(Icons.check_circle, color: Color(0xFFE6007E), size: 18),
                                  ),
                                Positioned(
                                  bottom: 0, left: 0, right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    color: Colors.black45,
                                    child: Text(slot, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 9)),
                                  ),
                                ),
                                Positioned(
                                  top: 2, right: 2,
                                  child: GestureDetector(
                                    onTap: () => setState(() {
                                      _photoSlots.remove(slot);
                                      if (_thumbnailSlot == slot) {
                                        _thumbnailSlot = _photoSlots.entries.firstWhere((e) => e.value != null, orElse: () => const MapEntry('정면', null)).key;
                                      }
                                    }),
                                    child: Container(
                                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                      child: const Icon(Icons.close, size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    // 추가 버튼
                    GestureDetector(
                      onTap: _pickExtraPhoto,
                      child: Container(
                        width: 68, height: 68,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6007E).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE6007E).withValues(alpha: 0.4), width: 1.5),
                        ),
                        child: const Icon(Icons.add, size: 28, color: Color(0xFFE6007E)),
                      ),
                    ),
                  ],
                ),
              );
            }(),
          ),

          const SizedBox(height: 8),
          const Text('• 정면 사진이 마켓 썸네일로 자동 사용됩니다\n• 하자 부위가 있다면 따로 찍어주세요', style: TextStyle(fontSize: 11, color: Color(0xFFADA9A1), height: 1.6)),
          const SizedBox(height: 32),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // ─── Step 1: AI 분석 결과 (수정 가능) ───────────────────────

  Widget _buildStepResult() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('✦ AI 분석 결과', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2B2A27).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('확신도: $_confidence', style: const TextStyle(fontSize: 12, color: Color(0xFF2B2A27), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('내용이 다르면 수정 후 시세를 확인하세요', style: TextStyle(fontSize: 12, color: Color(0xFF8A877F))),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                _editableRow('제품 종류', _categoryCtrl),
                _divider(),
                _editableRow('브랜드', _brandCtrl),
                _divider(),
                _editableRow('모델명 단서', _modelCtrl),
                _divider(),
                _editableRow('추정 연식', _yearCtrl),
                _divider(),
                _editableRow('상태 등급', _gradeCtrl),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 하자 목록 (편집 가능)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('하자 목록', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextButton.icon(
                      onPressed: _addDefect,
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text('추가', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF2B2A27),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                if (_defects.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('감지된 하자 없음', style: TextStyle(fontSize: 13, color: Color(0xFFADA9A1))),
                  )
                else ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _defects.asMap().entries.map((e) => Chip(
                      label: Text(e.value, style: const TextStyle(fontSize: 12)),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: () => setState(() => _defects.removeAt(e.key)),
                      backgroundColor: const Color(0xFFFFF3E0),
                      side: const BorderSide(color: Color(0xFFE0DED8)),
                      labelPadding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE0DED8)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: Color(0xFF8A877F)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '위 정보를 수정하면 시세를 다시 계산합니다',
                    style: TextStyle(fontSize: 12, color: Color(0xFF5F5D58)),
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

  Widget _editableRow(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF8A877F)))),
          Expanded(
            child: TextField(
              controller: ctrl,
              style: const TextStyle(fontSize: 14, color: Color(0xFF2B2A27), fontWeight: FontWeight.w500),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                suffixIcon: Icon(Icons.edit, size: 14, color: Color(0xFFADA9A1)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => const Divider(height: 1, color: Color(0xFFF0EEE8));

  // ─── Step 2: 시세 + 마켓 게시 ────────────────────────────────

  Widget _buildStepQuote() {
    final priceMin = _priceMin > 0 ? '${(_priceMin / 10000).round()}만원' : '-';
    final priceMax = _priceMax > 0 ? '${(_priceMax / 10000).round()}만원' : '-';
    final priceRec = _priceRec > 0 ? '${(_priceRec / 10000).round()}만원' : '-';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('예상 시세 및 처분 방식', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          // 시세 카드
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: const Color(0xFF2B2A27), borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                const Text('중고 예상 시세', style: TextStyle(color: Color(0xFFADA9A1), fontSize: 12)),
                const SizedBox(height: 8),
                Text('$priceMin ~ $priceMax', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Container(height: 1, color: const Color(0xFF3D3C38)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _priceLabel('신품가 추정', _newPrice.isNotEmpty ? _newPrice : '-', Colors.white)),
                    Expanded(child: _priceLabel('추천 판매가', priceRec, const Color(0xFFE6007E))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (_priceReason.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('견적 근거', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Text(_priceReason, style: const TextStyle(fontSize: 12, color: Color(0xFF5F5D58), height: 1.6)),
                ],
              ),
            ),

          if (_priceMin > 0 && _priceMax > 0) ...[
            const SizedBox(height: 12),
            Container(
              height: 100,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('시세 분포', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF8A877F))),
                  const SizedBox(height: 4),
                  Expanded(
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _PriceChartPainter(minPrice: _priceMin, maxPrice: _priceMax, recommendedPrice: _priceRec),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // DB 스펙 카드
          if (_dbSpecs.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0DED8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.fact_check_outlined, size: 15, color: Color(0xFFE6007E)),
                      const SizedBox(width: 6),
                      const Text('제품 상세 스펙', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const Spacer(),
                      Text('LG DB 기준', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ..._dbSpecs.entries.take(12).map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 110,
                          child: Text(e.key, style: const TextStyle(fontSize: 12, color: Color(0xFF8A877F))),
                        ),
                        Expanded(
                          child: Text(e.value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                  )),
                  if (_dbSpecs.length > 12)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '외 ${_dbSpecs.length - 12}개 스펙',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ),
                ],
              ),
            ),
          ],

          // 썸네일 선택
          if (_dataUrls.length > 1) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE0DED8))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('마켓 썸네일', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  const Text('마켓에 표시될 대표 사진을 선택하세요', style: TextStyle(fontSize: 11, color: Color(0xFF8A877F))),
                  const SizedBox(height: 10),
                  Row(
                    children: _photoSlots.entries
                        .where((e) => e.value != null)
                        .map((e) {
                      final isSelected = _thumbnailSlot == e.key;
                      return GestureDetector(
                        onTap: () => setState(() => _thumbnailSlot = e.key),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 64, height: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isSelected ? const Color(0xFFE6007E) : const Color(0xFFE0DED8), width: isSelected ? 2.5 : 1),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.memory(base64Decode(e.value!.split(',').last), fit: BoxFit.cover),
                                if (isSelected)
                                  Container(
                                    color: const Color(0xFFE6007E).withValues(alpha: 0.25),
                                    child: const Icon(Icons.check_circle, color: Color(0xFFE6007E), size: 22),
                                  ),
                                Positioned(
                                  bottom: 0, left: 0, right: 0,
                                  child: Container(
                                    color: Colors.black45,
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Text(e.key, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 9)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // 판매글 편집
          const Text('✦ 판매글 편집', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('AI가 작성한 제목과 본문을 자유롭게 수정하세요', style: TextStyle(fontSize: 12, color: Color(0xFF8A877F))),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE0DED8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('제목', style: TextStyle(fontSize: 12, color: Color(0xFF8A877F))),
                const SizedBox(height: 6),
                TextField(
                  controller: _titleCtrl,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE0DED8))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE0DED8))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2B2A27))),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('본문', style: TextStyle(fontSize: 12, color: Color(0xFF8A877F))),
                const SizedBox(height: 6),
                TextField(
                  controller: _bodyCtrl,
                  maxLines: 4,
                  style: const TextStyle(fontSize: 13, height: 1.6),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE0DED8))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE0DED8))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2B2A27))),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 처분 방식 선택
          const Text('✦ 처분 방식 선택', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('원하는 처분 방법을 선택하세요', style: TextStyle(fontSize: 12, color: Color(0xFF8A877F))),
          const SizedBox(height: 12),
          ...[
            ('중고마켓',     Icons.storefront_outlined,  '이웃에게 직접 판매',           '추천'),
            ('LG 트레이드인', Icons.swap_horiz_rounded,   '보상판매 + 최대 10만원 추가',  ''),
            ('무료 수거',    Icons.recycling_rounded,     '환경부 지정 폐가전 무료 수거', ''),
          ].map((item) {
            final (method, icon, desc, badge) = item;
            final selected = _disposalMethod == method;
            return GestureDetector(
              onTap: () => setState(() => _disposalMethod = method),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF2B2A27) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? const Color(0xFF2B2A27) : const Color(0xFFE0DED8),
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: selected ? Colors.white.withValues(alpha: 0.15) : const Color(0xFFF0EEE8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 20, color: selected ? Colors.white : const Color(0xFF5F5D58)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(method, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: selected ? Colors.white : const Color(0xFF2B2A27))),
                              if (badge.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(color: const Color(0xFFE6007E), borderRadius: BorderRadius.circular(10)),
                                  child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(desc, style: TextStyle(fontSize: 12, color: selected ? const Color(0xFFADA9A1) : const Color(0xFF8A877F))),
                        ],
                      ),
                    ),
                    Icon(
                      selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: selected ? const Color(0xFFE6007E) : const Color(0xFFE0DED8),
                      size: 20,
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // ─── Step 3: LG 신제품 추천 ──────────────────────────────────

  Widget _buildStepRecommend() {
    final category = _categoryCtrl.text;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 완료 배너
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF2B2A27),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _disposalMethod == '무료 수거' ? Icons.recycling_rounded : Icons.check_circle,
                      color: const Color(0xFFE6007E),
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _disposalMethod == '무료 수거' ? '무료 수거 예약 완료!' : '게시글 등록 완료!',
                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _disposalMethod == '무료 수거'
                      ? '폐가전 무료 수거가 예약되었어요.\n이참에 새 LG 가전으로 업그레이드해보세요 ✨'
                      : '중고 매물이 이웃들에게 공개되었어요.\n이참에 새 LG 가전으로 업그레이드해보세요 ✨',
                  style: const TextStyle(color: Color(0xFFADA9A1), fontSize: 13, height: 1.5),
                ),
                if (_disposalMethod != '무료 수거') ...[
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UC04MarketplaceScreen())),
                    icon: const Icon(Icons.storefront_outlined, size: 16),
                    label: const Text('내 매물 보러가기', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── 비슷한 중고 매물 ──
          _buildSimilarListingsSection(),

          const SizedBox(height: 24),

          // ── LG 신제품 추천 ──
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('비슷하거나 더 나은 LG $category', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('신품으로 업그레이드한다면?', style: TextStyle(fontSize: 12, color: Color(0xFF8A877F))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (_loadingRecs)
            const Center(child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: CircularProgressIndicator(color: Color(0xFFE6007E), strokeWidth: 2.5),
            ))
          else if (_recommendations.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.storefront_outlined, size: 40, color: Color(0xFFADA9A1)),
                    const SizedBox(height: 10),
                    Text(
                      'LG ${_normalizeCategory(_categoryCtrl.text)} 신제품\n정보를 준비 중입니다',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF2B2A27), fontSize: 14, fontWeight: FontWeight.bold, height: 1.5),
                    ),
                    const SizedBox(height: 4),
                    const Text('LG 공식 홈페이지에서 최신 제품을 확인해보세요', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF8A877F), fontSize: 12, height: 1.5)),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final cat = Uri.encodeComponent(_normalizeCategory(_categoryCtrl.text));
                        final uri = Uri.parse('https://www.lge.co.kr/search?searchrword=$cat');
                        if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('LG 홈페이지에서 찾아보기'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2B2A27),
                        side: const BorderSide(color: Color(0xFFCCCAC4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._buildCompactRecSections(),

          const SizedBox(height: 20),

          // 가전 구독 CTA
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFE6007E), Color(0xFFAD005E)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.subscriptions_outlined, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('LG 가전 구독', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(width: 8),
                    _SubBadge('NEW'),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('목돈 없이 월 구독료만으로\n최신 LG 가전을 집에 들이세요', style: TextStyle(color: Color(0xFFFFCCE8), fontSize: 13, height: 1.5)),
                const SizedBox(height: 6),
                const Text('• 설치·A/S 포함  • 3년 후 교체 또는 구매 선택  • 최초 0원', style: TextStyle(color: Color(0xFFFFCCE8), fontSize: 12, height: 1.6)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final uri = Uri.parse('https://www.lge.co.kr/care-solutions');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFFE6007E),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('구독 알아보기', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDisposalAction(String priceRec) {
    return switch (_disposalMethod) {
      'LG 트레이드인' => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFE6007E), Color(0xFFAD005E)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('LG 트레이드인 혜택', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  SizedBox(height: 4),
                  Text('헌 가전 비우고, LG 신제품으로\n중고 보상가 + 추가 보상 최대 10만원', style: TextStyle(color: Color(0xFFFFCCE8), fontSize: 12, height: 1.5)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LgTradeInScreen(
                    productName: '${_brandCtrl.text} ${_categoryCtrl.text}',
                    category: _categoryCtrl.text,
                    modelCode: _modelCtrl.text,
                    estimatedPrice: _priceRec,
                  ),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFE6007E),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('신청하기', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ),
      ),
      '무료 수거' => SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('폐가전 무료수거가 예약되었습니다.'),
                duration: Duration(seconds: 1),
              ),
            );
            setState(() => _step = 3);
            _loadRecommendations();
          },
          icon: const Icon(Icons.recycling_rounded),
          label: const Text('무료 수거 예약하기', style: TextStyle(fontWeight: FontWeight.bold)),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF2B2A27),
            side: const BorderSide(color: Color(0xFF2B2A27)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      _ => !_posted
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE0DED8))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(color: const Color(0xFFF0EEE8), borderRadius: BorderRadius.circular(10)),
                        child: _photoSlots[_thumbnailSlot] != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(
                                  base64Decode(_photoSlots[_thumbnailSlot]!.split(',')[1]),
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Icon(_categoryIcon(_categoryCtrl.text), color: const Color(0xFF8A877F)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _titleCtrl.text.isNotEmpty ? _titleCtrl.text : '${_brandCtrl.text} ${_categoryCtrl.text} 판매합니다',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text('$priceRec · ${_gradeCtrl.text}급', style: const TextStyle(fontSize: 12, color: Color(0xFFE6007E))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _postToMarket,
                      icon: const Icon(Icons.storefront_outlined),
                      label: const Text('마켓에 게시하기', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE6007E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFE6007E).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE6007E), width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFFE6007E), size: 36),
                  const SizedBox(height: 8),
                  const Text('마켓에 게시글이 등록되었습니다!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFE6007E))),
                  const SizedBox(height: 4),
                  const Text('다른 이사 준비 중인 이웃들이 볼 수 있어요.', style: TextStyle(fontSize: 12, color: Color(0xFF8A877F))),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UC04MarketplaceScreen())),
                      icon: const Icon(Icons.storefront_outlined),
                      label: const Text('마켓 보러가기', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2B2A27),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    };
  }

  // ─── 비슷한 중고 매물 섹션 ─────────────────────────────────────
  // 앱 내 마켓플레이스에 등록된 실제 중고 매물 데이터들을 사용하여 렌더링
  Widget _buildSimilarListingsSection() {
    final category = _normalizeCategory(_categoryCtrl.text);
    
    // 앱 내 마켓플레이스에서 같은 카테고리의 타인 매물 우선
    var filteredListings = MoveInState.instance.marketListings
        .where((l) => !l.isMine && _normalizeCategory(l.category) == category)
        .toList();

    // 만약 해당 카테고리 매물이 부족하면, 다른 카테고리의 타인 매물로 채움
    if (filteredListings.length < 4) {
      final others = MoveInState.instance.marketListings
          .where((l) => !l.isMine && _normalizeCategory(l.category) != category)
          .toList();
      filteredListings.addAll(others);
    }

    final appMarket = filteredListings
        .take(4)
        .map((l) => {
              'title': l.title,
              'text': l.body,
              'url': '',
              '_price': l.price,
              '_grade': l.grade,
              '_seller': l.seller,
              '_imageUrl': l.imageNetworkUrl,
              '_imageDataUrl': l.imageDataUrl,
            })
        .toList();

    if (appMarket.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(width: 3, height: 14, color: const Color(0xFFE6007E)),
          const SizedBox(width: 8),
          const Text('비슷한 중고 매물', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: const Color(0xFFF5F4F2), borderRadius: BorderRadius.circular(4)),
            child: Text('${appMarket.length}개', style: const TextStyle(fontSize: 11, color: Color(0xFF8A877F))),
          ),
        ]),
        const SizedBox(height: 6),
        const Text('탭해서 신품 가격과 비교해보세요', style: TextStyle(fontSize: 12, color: Color(0xFF8A877F))),
        const SizedBox(height: 12),
        ...appMarket.map((item) => _buildUsedCard(item)),
      ],
    );
  }

  // 검색 결과 텍스트에서 가격 추출
  String _extractPriceStr(String text) {
    final m = RegExp(r'(\d[\d,]*)\s*만\s*원').firstMatch(text);
    if (m != null) return '${m.group(1)}만원';
    final m2 = RegExp(r'(\d[\d,]{4,})\s*원').firstMatch(text);
    if (m2 != null) {
      final n = int.tryParse(m2.group(1)!.replaceAll(',', '')) ?? 0;
      if (n >= 10000) return '${(n / 10000).round()}만원';
    }
    return '';
  }

  // 출처 도메인 추출
  String _sourceDomain(String url) {
    if (url.contains('bunjang')) return '번개장터';
    if (url.contains('daangn')) return '당근마켓';
    if (url.contains('joongna')) return '중나';
    if (url.contains('naver')) return '네이버';
    if (url.isEmpty) return '앱 내 마켓';
    return Uri.tryParse(url)?.host.replaceFirst('www.', '') ?? '';
  }

  // 구독 월 요금 계산 (매매가의 약 2.5%, 24개월 기준, 1000원 단위 반올림)
  String _subscriptionPrice(int price) {
    if (price <= 0) return '-';
    final monthly = ((price / 24) / 1000).round() * 1000;
    final wan = monthly / 10000;
    return wan >= 1 ? '월 ${wan.toStringAsFixed(wan == wan.roundToDouble() ? 0 : 1)}만원~' : '월 ${(monthly / 1000).round()}천원~';
  }

  Widget _buildUsedCard(Map<String, dynamic> item) {
    final title = (item['title'] as String? ?? '').trim();
    final text = (item['text'] as String? ?? '').trim();
    final url = item['url'] as String? ?? '';
    final appPrice = item['_price'] as int? ?? 0;
    final priceInt = appPrice > 0 ? appPrice : 0;
    final priceStr = priceInt > 0 ? '${(priceInt / 10000).round()}만원' : _extractPriceStr('$title $text');
    final subPrice = _subscriptionPrice(priceInt);
    final grade = item['_grade'] as String? ?? 'B';
    final source = (item['_source'] as String?)?.isNotEmpty == true
        ? item['_source'] as String
        : _sourceDomain(url);
    final isTemplate = item['_isTemplate'] == true;
    final gradeColor = grade == 'A' ? const Color(0xFF2196F3) : const Color(0xFF4CAF50);

    return GestureDetector(
      onTap: () => _showUsedListingDetail(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단 이미지/아이콘 영역
            Container(
              height: 110,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F4F2),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Stack(
                children: [
                  // 추천 상품 이미지가 있으면 재사용, 없으면 아이콘
                  Builder(builder: (_) {
                    final imgUrl = item['_imageUrl'] as String?;
                    final imgDataUrl = item['_imageDataUrl'] as String?;

                    // 1. 로컬 base64 데이터 이미지가 있을 경우
                    if (imgDataUrl?.isNotEmpty == true && imgDataUrl!.startsWith('data:')) {
                      try {
                        final base64Str = imgDataUrl.split(',')[1];
                        return Positioned.fill(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            child: Image.memory(
                              base64Decode(base64Str),
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      } catch (e) {
                        // ignore decoding errors
                      }
                    }

                    // 2. 네트워크 이미지가 있을 경우
                    final recImg = _recommendations.isNotEmpty
                        ? (_recommendations.first['image_url'] as String? ?? '')
                        : '';
                    final url = (imgUrl?.isNotEmpty == true) ? imgUrl! : recImg;
                    if (url.isNotEmpty) {
                      return Positioned.fill(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          child: Image.network(
                            url,
                            fit: BoxFit.cover,
                            color: const Color(0xFFF5F4F2),
                            colorBlendMode: BlendMode.dstOver,
                            errorBuilder: (_, __, ___) => Center(
                              child: Icon(_categoryIcon(_categoryCtrl.text), color: const Color(0xFFCCCAC4), size: 52),
                            ),
                          ),
                        ),
                      );
                    }
                    return Center(child: Icon(_categoryIcon(_categoryCtrl.text), color: const Color(0xFFCCCAC4), size: 52));
                  }),
                  // LG 인증 배지
                  Positioned(
                    top: 10, left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2B2A27),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(children: [
                        Icon(Icons.verified_rounded, color: Color(0xFFE6007E), size: 11),
                        SizedBox(width: 3),
                        Text('LG 인증 중고', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                  ),
                  // 등급 배지
                  Positioned(
                    top: 10, right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(color: gradeColor, borderRadius: BorderRadius.circular(6)),
                      child: Text('$grade등급', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            // 하단 정보 영역
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title.isNotEmpty ? title : '${_categoryCtrl.text} 중고 매물',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(4)),
                      child: Text(source, style: const TextStyle(fontSize: 10, color: Color(0xFF8A877F))),
                    ),
                    if (isTemplate) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFE6007E).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(4)),
                        child: const Text('시세 기반', style: TextStyle(fontSize: 9, color: Color(0xFFE6007E))),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 10),
                  // 매매 / 구독 가격
                  Row(children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F4F2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(children: [
                          const Text('매매', style: TextStyle(fontSize: 10, color: Color(0xFF8A877F))),
                          const SizedBox(height: 2),
                          Text(priceStr.isNotEmpty ? priceStr : '-',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2B2A27))),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6007E).withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(children: [
                          const Text('구독', style: TextStyle(fontSize: 10, color: Color(0xFFE6007E))),
                          const SizedBox(height: 2),
                          Text(subPrice, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFE6007E))),
                        ]),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUsedListingDetail(Map<String, dynamic> item) {
    final title = (item['title'] as String? ?? '').trim();
    final text = (item['text'] as String? ?? '').trim();
    final url = item['url'] as String? ?? '';
    final appPrice = item['_price'] as int? ?? 0;
    final priceInt = appPrice > 0 ? appPrice : 0;
    final priceStr = priceInt > 0 ? '${(priceInt / 10000).round()}만원' : _extractPriceStr('$title $text');
    final subPrice = _subscriptionPrice(priceInt);
    final newPriceStr = _newPrice.isNotEmpty ? _newPrice : '정보 없음';
    final grade = item['_grade'] as String? ?? 'B';
    final gradeColor = grade == 'A' ? const Color(0xFF2196F3) : const Color(0xFF4CAF50);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF5F4F2),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFCCCAC4), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: ctrl,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
                  children: [
                    // 헤더
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFF2B2A27), borderRadius: BorderRadius.circular(6)),
                        child: const Row(children: [
                          Icon(Icons.verified_rounded, color: Color(0xFFE6007E), size: 11),
                          SizedBox(width: 3),
                          Text('LG 인증 중고', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(color: gradeColor, borderRadius: BorderRadius.circular(6)),
                        child: Text('$grade등급', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    Text(title.isNotEmpty ? title : '${_categoryCtrl.text} 중고 매물',
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),

                    // ── 구독 vs 매매 비교 (핵심 섹션) ──
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2B2A27),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('이용 방법 선택', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 14),
                          Row(children: [
                            // 구독
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE6007E).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE6007E).withValues(alpha: 0.4)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(children: [
                                      Icon(Icons.subscriptions_outlined, color: Color(0xFFE6007E), size: 16),
                                      SizedBox(width: 5),
                                      Text('구독', style: TextStyle(color: Color(0xFFE6007E), fontWeight: FontWeight.bold, fontSize: 13)),
                                    ]),
                                    const SizedBox(height: 8),
                                    Text(subPrice, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                                    const SizedBox(height: 4),
                                    const Text('A/S 포함 · 부담 없이', style: TextStyle(color: Color(0xFFADA9A1), fontSize: 10)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // 매매
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(children: [
                                      Icon(Icons.shopping_bag_outlined, color: Colors.white70, size: 16),
                                      SizedBox(width: 5),
                                      Text('매매', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
                                    ]),
                                    const SizedBox(height: 8),
                                    Text(priceStr.isNotEmpty ? priceStr : '가격 문의',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                                    const SizedBox(height: 4),
                                    const Text('일시불 · 내 소유', style: TextStyle(color: Color(0xFFADA9A1), fontSize: 10)),
                                  ],
                                ),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 12),
                          // 신품 대비
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.compare_arrows_rounded, color: Color(0xFF8A877F), size: 14),
                              const SizedBox(width: 4),
                              Text('신품 가격 $newPriceStr 대비 절약 가능',
                                  style: const TextStyle(color: Color(0xFF8A877F), fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 매물 설명
                    if (text.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                        child: Text(text, maxLines: 6, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, height: 1.6, color: Color(0xFF2B2A27))),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (url.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse(url);
                          if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                        },
                        icon: const Icon(Icons.open_in_new_rounded, size: 14),
                        label: const Text('원문 보기'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2B2A27),
                          side: const BorderSide(color: Color(0xFFCCCAC4)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    const SizedBox(height: 20),

                    // LG 신제품 추천 (소형)
                    if (_recommendations.isNotEmpty) ...[
                      const Text('신품으로 업그레이드한다면?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('비슷한 스펙의 LG 신제품이에요', style: TextStyle(fontSize: 11, color: Color(0xFF8A877F))),
                      const SizedBox(height: 10),
                      ..._buildCompactRecSections(),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 소형 신제품 추천 카드 (바텀시트용)
  List<Widget> _buildCompactRecSections() {
    final same = _recommendations.where((r) => r['_sameCategory'] == true).toList();
    if (same.isEmpty) return [];
    return same.take(3).map((rec) {
      final name = rec['name'] as String? ?? '';
      final price = rec['price_new_krw'] as int? ?? 0;
      final priceStr = price > 0 ? '${(price / 10000).round()}만원~' : '';
      final imgUrl = rec['image_url'] as String? ?? '';
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: const Color(0xFFF5F4F2), borderRadius: BorderRadius.circular(8)),
            child: imgUrl.isNotEmpty
                ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(imgUrl, fit: BoxFit.contain))
                : Icon(_categoryIcon(_categoryCtrl.text), color: const Color(0xFFADA9A1), size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              if (priceStr.isNotEmpty)
                Text(priceStr, style: const TextStyle(fontSize: 12, color: Color(0xFFE6007E), fontWeight: FontWeight.bold)),
            ]),
          ),
        ]),
      );
    }).toList();
  }





  Widget _priceLabel(String label, String value, Color valueColor) => Column(
    children: [
      Text(label, style: const TextStyle(color: Color(0xFFADA9A1), fontSize: 11), textAlign: TextAlign.center),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.bold, fontSize: 15), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
    ],
  );

  IconData _categoryIcon(String cat) => switch (cat) {
    '냉장고' => Icons.kitchen,
    '세탁기' => Icons.local_laundry_service,
    '에어컨' => Icons.air,
    '건조기' => Icons.dry,
    _ => Icons.electrical_services,
  };
}

class _SubBadge extends StatelessWidget {
  final String text;
  const _SubBadge(this.text);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
    child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
  );
}

class _PriceChartPainter extends CustomPainter {
  final int minPrice, maxPrice, recommendedPrice;
  const _PriceChartPainter({required this.minPrice, required this.maxPrice, required this.recommendedPrice});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()..color = const Color(0xFFE6007E)..strokeWidth = 2.5..style = PaintingStyle.stroke;
    final fill = Paint()..color = const Color(0xFFE6007E).withValues(alpha: 0.1)..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height)
      ..quadraticBezierTo(size.width * 0.2, size.height * 0.5, size.width * 0.5, size.height * 0.15)
      ..quadraticBezierTo(size.width * 0.8, size.height * 0.5, size.width, size.height);

    canvas.drawPath(Path.from(path)..lineTo(size.width, size.height)..lineTo(0, size.height)..close(), fill);
    canvas.drawPath(path, stroke);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.15), 5, Paint()..color = const Color(0xFFE6007E));

    void drawLabel(String text, double x, double y, Color color) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y));
    }

    drawLabel('${(minPrice / 10000).round()}만', 4, size.height - 14, const Color(0xFF8A877F));
    drawLabel('${(recommendedPrice / 10000).round()}만 (추천)', size.width * 0.5, size.height * 0.15 - 16, const Color(0xFFE6007E));
    drawLabel('${(maxPrice / 10000).round()}만', size.width - 4, size.height - 14, const Color(0xFF8A877F));
  }

  @override
  bool shouldRepaint(covariant _PriceChartPainter old) => false;
}
