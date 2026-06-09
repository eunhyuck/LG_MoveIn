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
}
