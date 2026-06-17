import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lg_move_in/models/move_in_state.dart';

class UC07CommunityScreen extends StatefulWidget {
  const UC07CommunityScreen({super.key});

  @override
  State<UC07CommunityScreen> createState() => _UC07CommunityScreenState();
}

class _UC07CommunityScreenState extends State<UC07CommunityScreen> {
  final state = MoveInState.instance;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  String _selectedCategory = "새집자랑";
  bool _isReviewing = false;

  // Pastel avatar colors that cycle by index
  static const List<Color> _avatarColors = [
    Color(0xFFF8BBD0), // pink
    Color(0xFFBBDEFB), // blue
    Color(0xFFC8E6C9), // green
    Color(0xFFD1C4E9), // purple
  ];

  // Time labels that cycle by index
  static const List<String> _timeLabels = [
    '방금 전',
    '1시간 전',
    '3시간 전',
    '5시간 전',
    '어제',
  ];

  // Category color mapping
  static const Map<String, Color> _categoryBgColors = {
    '새집자랑': Color(0xFFFCE4EC),
    '동네정보': Color(0xFFE3F2FD),
    '공동육아': Color(0xFFE8F5E9),
    '반려동물': Color(0xFFFFF3E0),
  };

  static const Map<String, Color> _categoryTextColors = {
    '새집자랑': Color(0xFFE6007E),
    '동네정보': Color(0xFF1976D2),
    '공동육아': Color(0xFF388E3C),
    '반려동물': Color(0xFFE65100),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F8),
      appBar: AppBar(
        title: const Text(
          "MoveIn 커뮤니티",
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2B2A27),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: const Color(0xFFF0EEE8),
            height: 1,
          ),
        ),
      ),
      body: _isReviewing ? _buildReviewScreen() : _buildFeedScreen(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showWritePostDialog(),
        backgroundColor: const Color(0xFFE6007E),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_rounded),
        label: const Text(
          "글쓰기",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 4,
      ),
    );
  }

  Widget _buildReviewScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Decorative gradient background behind the icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFE6007E), Color(0xFFFF6FB0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE6007E).withValues(alpha: 0.25),
                  blurRadius: 32,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(
              Icons.shield_rounded,
              size: 52,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 28),
          // Pulsing indicator container
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFCE4EC),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE6007E).withValues(alpha: 0.10),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(
                color: Color(0xFFE6007E),
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "✦ AI 콘텐츠 게시 검토 중...",
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            "AI 분석 진행률: 78%",
            style: TextStyle(
              color: Color(0xFFE6007E),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "부적절한 표현이나 개인정보 노출 위험을 실시간 검토 중입니다.",
            style: TextStyle(color: Color(0xFF8A877F), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedScreen() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: state.communityPosts.length,
      itemBuilder: (context, index) {
        final post = state.communityPosts[index];
        final String category = post["category"];
        final String author = post["author"];
        final Color avatarColor = _avatarColors[index % _avatarColors.length];
        final String timeLabel = _timeLabels[index % _timeLabels.length];
        final Color categoryBg =
            _categoryBgColors[category] ?? const Color(0xFFFFFBEF);
        final Color categoryText =
            _categoryTextColors[category] ?? const Color(0xFF2B2A27);

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: const Border(
              bottom: BorderSide(color: Color(0xFFF0EEE8), width: 1.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author row with avatar
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: avatarColor,
                      child: Text(
                        author.isNotEmpty ? author[0] : '?',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2B2A27),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            author,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2B2A27),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            timeLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFFADADAD),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: categoryBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: categoryText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  post["title"],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2B2A27),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  post["content"],
                  style: const TextStyle(
                    color: Color(0xFF5F5D58),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                // Divider
                Container(
                  height: 1,
                  color: const Color(0xFFF0EEE8),
                ),
                const SizedBox(height: 12),
                // Like / Comment / Share row
                Row(
                  children: [
                    const Icon(
                      Icons.favorite_border_rounded,
                      size: 20,
                      color: Color(0xFF8A877F),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      "${post['likes']}",
                      style: const TextStyle(
                        color: Color(0xFF8A877F),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 20),
                    const Icon(
                      Icons.comment_outlined,
                      size: 20,
                      color: Color(0xFF8A877F),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      "${post['comments']}",
                      style: const TextStyle(
                        color: Color(0xFF8A877F),
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.share_outlined,
                      size: 20,
                      color: Color(0xFF8A877F),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showWritePostDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD9D9D9),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "새 글 작성하기",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  // Styled dropdown with rounded border
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFFE0E0E0),
                        width: 1.2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFFFAFAFA),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCategory,
                        isExpanded: true,
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Color(0xFF8A877F),
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF2B2A27),
                        ),
                        items:
                            ["새집자랑", "동네정보", "공동육아", "반려동물"].map((val) {
                          return DropdownMenuItem(
                            value: val,
                            child: Text(val),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              _selectedCategory = val;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: "제목",
                      labelStyle: const TextStyle(color: Color(0xFF8A877F)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFE6007E),
                          width: 1.5,
                        ),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFFAFAFA),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _contentController,
                    decoration: InputDecoration(
                      labelText: "내용",
                      labelStyle: const TextStyle(color: Color(0xFF8A877F)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFE6007E),
                          width: 1.5,
                        ),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFFAFAFA),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            setState(() {
                              _isReviewing = true;
                            });
                            Timer(const Duration(milliseconds: 2500), () {
                              setState(() {
                                _isReviewing = false;
                                state.communityPosts.insert(0, {
                                  "author": "주민12",
                                  "category": _selectedCategory,
                                  "title": _titleController.text,
                                  "content": _contentController.text,
                                  "likes": 0,
                                  "comments": 0,
                                  "image": null,
                                });
                                _titleController.clear();
                                _contentController.clear();
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "AI의 게시글 건전성 검토 후 안전하게 포스팅되었습니다! ✦",
                                  ),
                                ),
                              );
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE6007E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 2,
                          ),
                          child: const Text(
                            "✦ 검토 및 등록",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
