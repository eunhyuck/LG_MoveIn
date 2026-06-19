import 'package:supabase_flutter/supabase_flutter.dart';

class TradeInListing {
  final String id;
  final String category;
  final String brand;
  final String modelHint;
  final String title;
  final String body;
  final int price;
  final int priceMin;
  final int priceMax;
  final String grade;
  final List<String> defects;
  final DateTime postedAt;
  final bool isMine;
  final String seller;
  final String? imageDataUrl;    // base64 data URL of the product photo
  final String? imageNetworkUrl; // network URL (from Supabase or CDN)

  TradeInListing({
    required this.id,
    required this.category,
    required this.brand,
    required this.modelHint,
    required this.title,
    required this.body,
    required this.price,
    required this.priceMin,
    required this.priceMax,
    required this.grade,
    required this.defects,
    required this.postedAt,
    required this.isMine,
    required this.seller,
    this.imageDataUrl,
    this.imageNetworkUrl,
  });

  TradeInListing copyWith({
    String? title,
    String? body,
    int? price,
    String? grade,
    List<String>? defects,
  }) {
    return TradeInListing(
      id: id,
      category: category,
      brand: brand,
      modelHint: modelHint,
      title: title ?? this.title,
      body: body ?? this.body,
      price: price ?? this.price,
      priceMin: priceMin,
      priceMax: priceMax,
      grade: grade ?? this.grade,
      defects: defects ?? this.defects,
      postedAt: postedAt,
      isMine: isMine,
      seller: seller,
      imageDataUrl: imageDataUrl,
      imageNetworkUrl: imageNetworkUrl,
    );
  }
}

class MoveInState {
  static final MoveInState instance = MoveInState._internal();
  MoveInState._internal();

  DateTime? moveDate;
  String? departureAddress;
  String? arrivalAddress;
  String moveType = "가정 이사";
  bool isDDayConfigured = false;
  bool isChallengeStarted = false;
  bool _marketListingsLoaded = false;

  // Challenges
  int currentPoints = 1240;
  int completedMissions = 18;
  List<String> badges = ["첫빨래", "산책", "카페"];

  // Community
  List<Map<String, dynamic>> communityPosts = [
    {
      "author": "판교새댁99",
      "category": "동네정보",
      "title": "이사 가전: 마켓 중고 vs 공식 신품 고민이에요 ㅜㅜ",
      "content": "이번에 분당으로 이사하면서 냉장고랑 워시타워 맞춰야 하는데, 이사 비용이 너무 많이 들어서 중고 마켓 매물을 보고 있어요. 마켓에 올라온 1년 사용한 오브제 냉장고가 120만원이던데, 신품 220만원 주고 사는 게 나을까요 아니면 100만원 아껴서 중고로 살까요? 고장이나 AS 생각하면 머리가 아프네요.",
      "likes": 18,
      "comments": 6,
      "image": "fridge"
    },
    {
      "author": "오브제러버",
      "category": "새집자랑",
      "title": "가전 구독제 3개월 사용 후기! (일시불 비교)",
      "content": "세탁기랑 건조기 일시불로 사려다가 이번에 LG 가전 구독제로 계약해서 들어왔어요. 목돈 안 드는 게 가장 컸고, 구독 기간 동안 무상 케어서비스랑 필터 교체가 무상이라 결정했는데 대만족 중입니다! 월 3만원대로 오브제 최신형 쓰니까 일시불보다 초기 부담이 전혀 없네요.",
      "likes": 29,
      "comments": 12,
      "image": "laundry"
    },
    {
      "author": "이사는힘들어",
      "category": "동네정보",
      "title": "중고마켓 냉장고 매물 비교 도와주세요!",
      "content": "무브인 마켓플레이스에 올라와 있는 냉장고 두 개 중에 고민 중입니다.\n\n1번: 21년식 양문형 냉장고 (A급, 미세 스크래치 있음) - 75만원\n2번: 22년식 4도어 노크온 (B급, 도어 미세 찍힘 있음) - 95만원\n\n20만원 차이인데 연식이나 기능 생각하면 2번이 나을까요? 다들 어떤 걸 선택하시겠어요?",
      "likes": 14,
      "comments": 5,
      "image": null
    },
    {
      "author": "테크가좋아",
      "category": "동네정보",
      "title": "가전 일시불 구매 vs 구독 서비스 총비용 비교",
      "content": "5년 기준 총 지출액 계산해 보니까 구독제가 월 납부 방식이라 비싸 보이지만 무상 A/S 기간이 구독 기간 내내(최대 5~6년) 보장되고 케어서비스 비용 포함인 걸 감안하면 일시불이랑 거의 차이 없더라고요. 제휴카드 할인까지 태우니까 오히려 구독이 훨씬 저렴해서 저도 구독으로 냉장고 질렀습니다!",
      "likes": 35,
      "comments": 18,
      "image": null
    },
    {
      "author": "미니멀리스트",
      "category": "새집자랑",
      "title": "새집 입주하면서 헌 가전 트레이드인 후기",
      "content": "원래 쓰던 오래된 냉장고를 중고 마켓에 팔지, 아니면 트레이드인(보상판매) 신청할지 고민하다가 LG 트레이드인으로 신청했어요. 무상 수거에 추가 보상금까지 쏠쏠하게 받아서 신제품 구매할 때 보탰습니다. 헌 가전 당근에 올려서 네고 문자 받느라 스트레스받는 것보다 트레이드인이 훨씬 편하고 이득인 듯요!",
      "likes": 22,
      "comments": 4,
      "image": "tv"
    }
  ];

  // Trade-in marketplace listings (fallback until Supabase loads)
  List<TradeInListing> marketListings = [];

  // 카테고리별 신품가 기본값 (Supabase price_new_krw null인 경우)
  static int _categoryDefaultNewPrice(String category) {
    switch (category) {
      case '냉장고': return 2000000;
      case '세탁기': return 900000;
      case '에어컨': return 2000000;
      case '공기청정기': return 500000;
      case '정수기': return 1000000;
      case '청소기': return 500000;
      case '식기세척기': return 1000000;
      case '워시타워': return 3000000;
      case '건조기': return 800000;
      default: return 600000;
    }
  }

  // 등급·카테고리별 결함 목록
  static List<String> _categoryDefects(String category, String grade) {
    if (grade == 'A') return [];
    final Map<String, List<String>> defectsB = {
      '냉장고': ['외관 미세 스크래치'],
      '세탁기': ['도어 고무패킹 미세 이물질'],
      '에어컨': ['외관 미세 찍힘'],
      '공기청정기': ['외관 측면 미세 스크래치'],
      '정수기': ['출수구 미세 물때'],
      '청소기': ['흡입구 미세 스크래치'],
      '식기세척기': ['도어 하단 미세 찍힘'],
      '워시타워': ['외관 좌측 미세 스크래치'],
      '건조기': ['필터 커버 미세 찍힘'],
    };
    return defectsB[category] ?? ['외관 미세 스크래치'];
  }

  // 등급·카테고리에 맞는 제품 설명 생성
  static String _bodyText(String category, String modelCode, String grade, int usedPrice) {
    final gradeDesc = grade == 'A' ? '외관 상태 매우 양호, 기능 이상 없음' : '외관 경미한 흔적 있으나 기능 완전 정상';
    return 'LG $category ($modelCode)\n'
        '• $gradeDesc\n'
        '• LG전자 공인 검사 완료 · LG 인증 중고 등록\n'
        '• 이사로 인해 처분합니다. 직거래 or 안전결제 가능';
  }

  static const _sellers = [
    '한강뷰입주', '오브제러버', '마포이사중', '성수동새집', '판교입주예정',
    '광교새보금자리', '새집꾸미기', '이사완료짱', '강남이삿날', '분당정착중',
    '위례입주', '하남미사러', '용인입주맘', '수원이삿짐', '일산새집자랑',
  ];

  Future<void> loadMarketListings({bool force = false}) async {
    if (_marketListingsLoaded && !force) return;
    try {
      final rows = await Supabase.instance.client
          .from('lg_products')
          .select('product_id, name, category, brand, model_code, price_new_krw, images, color')
          .eq('usage_status', 'used')
          .order('product_id');

      // 이미지 있는 제품을 먼저 정렬 → 상단 노출 + 더 최근 시간 부여
      final sortedRows = List<Map<String, dynamic>>.from(
        rows.map((r) => r as Map<String, dynamic>),
      )..sort((a, b) {
        final aImages = a['images'] as List<dynamic>?;
        final bImages = b['images'] as List<dynamic>?;
        final aHas = aImages != null && aImages.isNotEmpty;
        final bHas = bImages != null && bImages.isNotEmpty;
        if (aHas == bHas) return 0;
        return aHas ? -1 : 1;
      });

      final now = DateTime.now();
      final loaded = <TradeInListing>[];
      for (int i = 0; i < sortedRows.length; i++) {
        final row = sortedRows[i];
        final pid = row['product_id'] as int? ?? i;
        final category = row['category'] as String? ?? '';
        final brand = row['brand'] as String? ?? 'LG';
        final modelCode = row['model_code'] as String? ?? '';
        final name = row['name'] as String? ?? '$brand $category';
        final newPrice = (row['price_new_krw'] as num?)?.toInt() ?? _categoryDefaultNewPrice(category);
        final imageList = row['images'] as List<dynamic>?;
        final imageUrl = imageList != null && imageList.isNotEmpty ? imageList.first as String? : null;

        // 등급: 3개 중 2개는 A, 1개는 B (LG인증 매물 컨셉)
        final grade = (i % 3 == 2) ? 'B' : 'A';
        final ratio = grade == 'A' ? 0.65 : 0.52;
        final usedPrice = (newPrice * ratio / 1000).round() * 1000;
        final priceMin = (usedPrice * 0.9 / 1000).round() * 1000;
        final priceMax = (usedPrice * 1.1 / 1000).round() * 1000;

        // 게시 시각: 최근 30일 내 랜덤하게 분산
        final hoursAgo = ((i * 17 + 3) % 720) + 1;
        final postedAt = now.subtract(Duration(hours: hoursAgo));

        loaded.add(TradeInListing(
          id: 'used_$pid',
          category: category,
          brand: brand,
          modelHint: name,
          title: '$name 팝니다 ($grade등급)',
          body: _bodyText(category, modelCode, grade, usedPrice),
          price: usedPrice,
          priceMin: priceMin,
          priceMax: priceMax,
          grade: grade,
          defects: _categoryDefects(category, grade),
          postedAt: postedAt,
          isMine: false,
          seller: _sellers[i % _sellers.length],
          imageNetworkUrl: imageUrl,
        ));
      }

      if (loaded.isNotEmpty) {
        marketListings = loaded;
        _marketListingsLoaded = true;
      }
    } catch (_) {
      // 로드 실패 시 기존 더미 유지
    }
  }
}
