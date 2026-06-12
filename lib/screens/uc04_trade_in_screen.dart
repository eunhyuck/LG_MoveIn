import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lg_move_in/models/move_in_state.dart';
import 'package:lg_move_in/screens/uc04_marketplace_screen.dart';
import 'package:lg_move_in/services/appraise_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  // 선택된 이미지 (base64 data URL 목록)
  final List<String> _dataUrls = [];

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
  String _listingTitle = '';
  String _listingBody = '';
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

  Future<void> _pickImages() async {
    final remaining = 6 - _dataUrls.length;
    if (remaining <= 0) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return;

    final urls = <String>[];
    for (final f in result.files.take(remaining)) {
      final bytes = f.bytes;
      if (bytes == null) continue;
      final ext = (f.extension ?? 'jpg').toLowerCase();
      final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
      urls.add('data:$mime;base64,${base64Encode(bytes)}');
    }

    setState(() => _dataUrls.addAll(urls));
  }

  // ─── AI 분석 (3단계) ─────────────────────────────────────────

  Future<void> _startAnalysis() async {
    if (_dataUrls.isEmpty) return;

    setState(() {
      _isAnalyzing = true;
      _analysisPhase = 0;
    });

    try {
      // 0) 라벨 OCR → 모델코드 추출 (라벨 사진 있을 때만)
      String? ocrModelCode;
      if (_labelDataUrl != null) {
        setState(() => _analysisPhase = 0);
        ocrModelCode = await AppraiseService.ocrModelLabel(_labelDataUrl!);
      }

      // 1) 제품 식별
      setState(() => _analysisPhase = 1);
      final raw = await AppraiseService.identifyProduct(
        _dataUrls,
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
        _categoryCtrl.text = product['종류'] as String? ?? '가전';
        _brandCtrl.text = product['브랜드'] as String? ?? '불명';
        // DB 매칭된 공식 제품명 우선 표시
        _modelCtrl.text = (product['db모델코드'] as String? ?? '').isNotEmpty
            ? '${product['db모델코드']} (${product['모델명단서'] ?? ''})'
            : product['모델명단서'] as String? ?? '불명';
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
        _listingTitle = listing['판매제목'] as String? ?? '${_brandCtrl.text} ${_categoryCtrl.text} 판매합니다';
        _listingBody = listing['판매본문'] as String? ?? '';

        _dbSpecs = Map<String, String>.from(
          (product['db스펙'] as Map<String, dynamic>? ?? {}).map(
            (k, v) => MapEntry(k, v.toString()),
          ),
        );
        _isAnalyzing = false;
        _step = 1;
      });
    } catch (e) {
      setState(() => _isAnalyzing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('분석 실패: $e'),
            backgroundColor: const Color(0xFF2B2A27),
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
      final product = {
        '종류': _categoryCtrl.text,
        '브랜드': _brandCtrl.text,
        '모델명단서': _modelCtrl.text,
        '추정연식': _yearCtrl.text,
        '상태등급': _gradeCtrl.text,
        '하자': _defects,
        '확신도': _confidence,
        'db모델코드': _modelCtrl.text.contains('(') ? _modelCtrl.text.split(' ').first : '',
      };

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
        _listingTitle = listing['판매제목'] as String? ?? '';
        _listingBody  = listing['판매본문'] as String? ?? '';
        _isAnalyzing = false;
        _step = 2;
      });
    } catch (e) {
      setState(() => _isAnalyzing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('시세 계산 실패: $e'), backgroundColor: const Color(0xFF2B2A27)),
        );
      }
    }
  }

  Future<void> _loadRecommendations() async {
    final category = _categoryCtrl.text;
    if (category.isEmpty) return;
    setState(() => _loadingRecs = true);
    try {
      final db = Supabase.instance.client;

      // 현재 제품 용량 (냉장고 등)
      final myCapacity = double.tryParse(
        (_dbSpecs['전체용량(L)'] ?? _dbSpecs['capacity_l'] ?? '').replaceAll(RegExp(r'[^0-9.]'), ''),
      );

      var query = db
          .from('lg_products')
          .select('model_code, name, category, color, energy_grade, '
              'capacity_l, dry_capacity_kg, suction_w, power_w, '
              'size_mm, thinq_wifi, up_appliance, price_new_krw, images, product_url')
          .eq('category', category);

      // 용량 있으면 현재 이상 필터
      if (myCapacity != null && myCapacity > 0) {
        query = query.gte('capacity_l', myCapacity * 0.85);
      }

      final rows = await query
          .not('price_new_krw', 'is', null)
          .order('energy_grade', ascending: true)   // 1등급 우선
          .order('price_new_krw', ascending: false)
          .limit(6);

      setState(() {
        _recommendations = List<Map<String, dynamic>>.from(rows);
        _loadingRecs = false;
      });
    } catch (_) {
      setState(() => _loadingRecs = false);
    }
  }

  void _postToMarket() {
    final listing = TradeInListing(
      id: 'mine_${DateTime.now().millisecondsSinceEpoch}',
      category: _categoryCtrl.text,
      brand: _brandCtrl.text,
      modelHint: _modelCtrl.text,
      title: _listingTitle.isNotEmpty ? _listingTitle : '${_brandCtrl.text} ${_categoryCtrl.text} 판매합니다',
      body: _listingBody.isNotEmpty
          ? _listingBody
          : '이사로 인해 처분합니다. 직거래 가능하며 소폭 네고 됩니다.',
      price: _priceRec,
      priceMin: _priceMin,
      priceMax: _priceMax,
      grade: _gradeCtrl.text,
      defects: List.from(_defects),
      postedAt: DateTime.now(),
      isMine: true,
      seller: '나 (MoveIn 사용자)',
      imageDataUrl: _dataUrls.isNotEmpty ? _dataUrls.first : null,
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
        actions: [
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
      body: _isAnalyzing ? _buildAnalyzing() : _buildStep(),
    );
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

          // 사진 그리드
          if (_dataUrls.isEmpty)
            GestureDetector(
              onTap: _pickImages,
              child: Container(
                width: double.infinity,
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE0DED8), style: BorderStyle.solid),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined, size: 48, color: Color(0xFFADA9A1)),
                    SizedBox(height: 10),
                    Text('사진을 선택해주세요', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5F5D58))),
                    SizedBox(height: 4),
                    Text('최대 6장 / 여러 각도로 찍을수록 정확도가 높아져요', style: TextStyle(fontSize: 12, color: Color(0xFF8A877F))),
                  ],
                ),
              ),
            )
          else ...[
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8,
              ),
              itemCount: _dataUrls.length + (_dataUrls.length < 6 ? 1 : 0),
              itemBuilder: (ctx, i) {
                if (i == _dataUrls.length) {
                  return GestureDetector(
                    onTap: _pickImages,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE0DED8)),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, size: 28, color: Color(0xFF8A877F)),
                          SizedBox(height: 4),
                          Text('추가', style: TextStyle(fontSize: 11, color: Color(0xFF8A877F))),
                        ],
                      ),
                    ),
                  );
                }
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        base64Decode(_dataUrls[i].split(',').last),
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4, right: 4,
                      child: GestureDetector(
                        onTap: () => setState(() => _dataUrls.removeAt(i)),
                        child: Container(
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Text('${_dataUrls.length}장 선택됨', style: const TextStyle(fontSize: 12, color: Color(0xFF8A877F))),
          ],

          const SizedBox(height: 16),
          // 팁
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0DED8)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('📌  사진 촬영 팁', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                SizedBox(height: 8),
                Text('• 정면 / 측면 / 모델 스티커 라벨을 각각 찍으면 정확도가 높아집니다\n• 스크래치·찌그러짐이 있는 부위도 촬영해 주세요', style: TextStyle(fontSize: 12, color: Color(0xFF5F5D58), height: 1.6)),
              ],
            ),
          ),
          const SizedBox(height: 32),

          SizedBox(
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
              ),
            ),
          ),
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

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isAnalyzing ? null : _recalculatePrice,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2B2A27),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isAnalyzing
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('이 정보로 시세 계산하기', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
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
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _priceLabel('신품가 추정', _newPrice.isNotEmpty ? _newPrice : '-', Colors.white),
                    _priceLabel('추천 판매가', priceRec, const Color(0xFFE6007E)),
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

          const SizedBox(height: 20),

          // 마켓 게시 섹션
          const Text('✦ 중고 가전 마켓에 게시하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('AI 감정 결과를 바탕으로 앱 내 마켓에 판매글이 자동 등록됩니다.', style: TextStyle(fontSize: 13, color: Color(0xFF5F5D58))),
          const SizedBox(height: 12),

          if (!_posted) ...[
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
                  Row(
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(color: const Color(0xFFF0EEE8), borderRadius: BorderRadius.circular(10)),
                        child: Icon(_categoryIcon(_categoryCtrl.text), color: const Color(0xFF8A877F)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _listingTitle.isNotEmpty ? _listingTitle : '${_brandCtrl.text} ${_categoryCtrl.text} 판매합니다',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text('$priceRec · ${_gradeCtrl.text}급', style: const TextStyle(fontSize: 13, color: Color(0xFFE6007E))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_listingBody.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFFF0EEE8)),
                    const SizedBox(height: 8),
                    Text(_listingBody, style: const TextStyle(fontSize: 12, color: Color(0xFF5F5D58), height: 1.6), maxLines: 4, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 16),
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
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFE6007E).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE6007E), width: 1.5),
              ),
              child: Column(
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
          ],

          const SizedBox(height: 16),

          // LG 트레이드인 배너
          Container(
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
                      SizedBox(height: 6),
                      Text('헌 가전 비우고, LG 신제품 들이기\n중고 보상가 + 추가 보상 최대 10만원', style: TextStyle(color: Color(0xFFFFCCE8), fontSize: 12, height: 1.5)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('LG 트레이드인 신청이 완료되었습니다.'))),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                    child: const Text('신청하기', style: TextStyle(color: Color(0xFFE6007E), fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('폐가전 무료수거가 예약되었습니다.')));
                Navigator.pop(context);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2B2A27),
                side: const BorderSide(color: Color(0xFF2B2A27)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('폐가전 무료 수거 신청', style: TextStyle(fontSize: 13)),
            ),
          ),
          const SizedBox(height: 20),
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
                const Row(
                  children: [
                    Icon(Icons.check_circle, color: Color(0xFFE6007E), size: 22),
                    SizedBox(width: 8),
                    Text('게시글 등록 완료!', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                const Text('중고 매물이 이웃들에게 공개되었어요.\n이참에 새 LG 가전으로 업그레이드해보세요 ✨', style: TextStyle(color: Color(0xFFADA9A1), fontSize: 13, height: 1.5)),
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
            ),
          ),
          const SizedBox(height: 24),

          // 추천 헤더
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('비슷하거나 더 나은 LG $category', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('중고 처분 후 딱 맞는 신제품을 찾아봤어요', style: TextStyle(fontSize: 12, color: Color(0xFF8A877F))),
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
              child: const Center(
                child: Column(
                  children: [
                    Icon(Icons.search_off_rounded, size: 40, color: Color(0xFFADA9A1)),
                    SizedBox(height: 10),
                    Text('추천 제품을 불러오는 중입니다\n잠시 후 다시 확인해주세요', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF8A877F), fontSize: 13, height: 1.5)),
                  ],
                ),
              ),
            )
          else
            ...(_recommendations.map((rec) => _buildRecCard(rec))),

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
                        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('LG 가전 구독 페이지로 이동합니다.'))),
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

  Widget _buildRecCard(Map<String, dynamic> rec) {
    final name = rec['name'] as String? ?? '-';
    final modelCode = rec['model_code'] as String? ?? '';
    final priceRaw = rec['price_new_krw'];
    final priceStr = priceRaw != null
        ? '${((priceRaw as num) / 10000).round()}만원'
        : '가격 미정';
    final energyGrade = rec['energy_grade'] as String?;
    final capacity = rec['capacity_l'];
    final thinq = rec['thinq_wifi'] as bool? ?? false;
    final upAppliance = rec['up_appliance'] as bool? ?? false;
    final images = rec['images'] as List<dynamic>?;
    final imageUrl = images != null && images.isNotEmpty ? images.first as String : null;

    final chips = <String>[];
    if (energyGrade != null) chips.add('에너지 $energyGrade등급');
    if (capacity != null) chips.add('${capacity}L');
    if (thinq) chips.add('ThinQ');
    if (upAppliance) chips.add('UP가전');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 이미지 영역
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: imageUrl != null
                ? Image.network(
                    imageUrl,
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.contain,
                    errorBuilder: (ctx, e, s) => _noImageBox(),
                  )
                : _noImageBox(),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 모델코드 + UP가전 배지
                Row(
                  children: [
                    Text(modelCode, style: const TextStyle(fontSize: 11, color: Color(0xFF8A877F))),
                    const Spacer(),
                    if (upAppliance)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFF2B2A27), borderRadius: BorderRadius.circular(20)),
                        child: const Text('UP가전', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2B2A27)), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),

                // 스펙 칩
                if (chips.isNotEmpty) Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: chips.map((c) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFF0EEE8), borderRadius: BorderRadius.circular(20)),
                    child: Text(c, style: const TextStyle(fontSize: 11, color: Color(0xFF5F5D58))),
                  )).toList(),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Text(priceStr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFE6007E))),
                    const Spacer(),
                    OutlinedButton(
                      onPressed: () {
                        final url = rec['product_url'] as String?;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(url != null ? '제품 페이지: $url' : '제품 페이지를 열 수 없습니다.'),
                          action: url != null ? SnackBarAction(label: '복사', onPressed: () => Clipboard.setData(ClipboardData(text: url))) : null,
                        ));
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2B2A27),
                        side: const BorderSide(color: Color(0xFFE0DED8)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('제품 보기', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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

  Widget _noImageBox() => Container(
    width: double.infinity,
    height: 180,
    color: const Color(0xFFF5F4F0),
    child: const Icon(Icons.kitchen_outlined, size: 48, color: Color(0xFFCCC9C0)),
  );

  Widget _priceLabel(String label, String value, Color valueColor) => Column(
    children: [
      Text(label, style: const TextStyle(color: Color(0xFFADA9A1), fontSize: 11)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.bold, fontSize: 15)),
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
