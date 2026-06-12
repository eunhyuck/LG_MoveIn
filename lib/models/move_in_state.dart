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
  final String? imageDataUrl; // base64 data URL of the product photo

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

  // Trade-in marketplace listings
  List<TradeInListing> marketListings = [
    TradeInListing(
      id: 'sample_1',
      category: '냉장고',
      brand: '삼성',
      modelHint: '비스포크 4도어 (추정)',
      title: '삼성 비스포크 냉장고 4도어 팝니다',
      body: '삼성 비스포크 4도어 냉장고입니다.\n구매: 2020년\n작동 이상 없고 냉각 정상입니다.\n이사로 인해 처분해요. 직거래만 가능합니다.',
      price: 620000,
      priceMin: 550000,
      priceMax: 720000,
      grade: 'B',
      defects: ['좌측 도어 상단 스크래치'],
      postedAt: DateTime.now().subtract(const Duration(hours: 3)),
      isMine: false,
      seller: '이사중인갈매기',
    ),
    TradeInListing(
      id: 'sample_2',
      category: '세탁기',
      brand: 'LG',
      modelHint: '드럼세탁기 17kg (추정)',
      title: 'LG 드럼세탁기 17kg 급처 합니다',
      body: 'LG 드럼세탁기 17kg입니다.\n구매: 2022년 중반\n외관 거의 새것 수준, 하자 없음.\n급하게 처분해야 해서 시세보다 저렴하게 내놓습니다.',
      price: 480000,
      priceMin: 430000,
      priceMax: 550000,
      grade: 'A',
      defects: [],
      postedAt: DateTime.now().subtract(const Duration(hours: 11)),
      isMine: false,
      seller: '새집이사짱',
    ),
    TradeInListing(
      id: 'sample_3',
      category: '에어컨',
      brand: '위니아',
      modelHint: '스탠드형 에어컨 (추정)',
      title: '위니아 스탠드 에어컨 팔아요 (하자있음)',
      body: '위니아 스탠드형 에어컨입니다.\n구매: 2019년\n냉방 작동 정상이나 리모컨 분실로 스마트폰 앱으로만 제어 가능합니다.\n외관 하단부 긁힘 있어 저렴하게 드립니다.',
      price: 180000,
      priceMin: 150000,
      priceMax: 230000,
      grade: 'C',
      defects: ['하단부 긁힘', '리모컨 분실'],
      postedAt: DateTime.now().subtract(const Duration(days: 1)),
      isMine: false,
      seller: '강남이사완료',
    ),
    TradeInListing(
      id: 'sample_4',
      category: '건조기',
      brand: 'LG',
      modelHint: '트롬 건조기 9kg (추정)',
      title: 'LG 트롬 건조기 9kg 판매',
      body: 'LG 트롬 건조기 9kg 팝니다.\n구매: 2021년\n청소 꼼꼼히 해서 냄새 없고 깨끗합니다.\n이사 날짜 잡혀서 빠르게 처분합니다.',
      price: 350000,
      priceMin: 310000,
      priceMax: 420000,
      grade: 'A',
      defects: [],
      postedAt: DateTime.now().subtract(const Duration(days: 2)),
      isMine: false,
      seller: '꼼꼼한이사러',
    ),
  ];
}
