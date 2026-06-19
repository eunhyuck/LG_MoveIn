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
  bool _marketListingsLoaded = false;

  // Challenges
  int currentPoints = 1240;
  int completedMissions = 18;
  List<String> badges = ["첫빨래", "산책", "카페"];

  // Community
  List<Map<String, dynamic>> communityPosts = [
    {
      "author": "이사가좋아",
      "category": "새집자랑",
      "title": "드디어 이사 끝! 가전 배치 완료했어요",
      "content": "LG 오브제컬렉션으로 싹 맞췄는데 주방이 너무 예쁘네요. 룸플래너 덕분에 사이즈 딱 맞게 들어갔어요!",
      "likes": 24,
      "comments": 8,
      "image": "kitchen"
    },
    {
      "author": "미니멀라이프",
      "category": "동네정보",
      "title": "동네 근처 대형 마트 주차 팁 공유해요",
      "content": "이 동네 새로 오신 분들 많으시죠? 이마트 갈 때 뒷길로 가시면 주차 대기시간이 반으로 줍니다.",
      "likes": 15,
      "comments": 3,
      "image": "mart"
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

      final now = DateTime.now();
      final loaded = <TradeInListing>[];
      for (int i = 0; i < rows.length; i++) {
        final row = rows[i] as Map<String, dynamic>;
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
