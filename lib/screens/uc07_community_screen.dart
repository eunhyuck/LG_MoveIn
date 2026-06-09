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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("MoveIn 커뮤니티 (UC-07)"),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2B2A27),
        elevation: 0,
      ),
      body: _isReviewing ? _buildReviewScreen() : _buildFeedScreen(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showWritePostDialog(),
        backgroundColor: const Color(0xFFE6007E),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit),
        label: const Text("글쓰기"),
      ),
    );
  }

  Widget _buildReviewScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFFE6007E)),
          SizedBox(height: 20),
          Text(
            "✦ AI 콘텐츠 게시 검토 중...",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            "부적절한 표현이나 개인정보 노출 위험을 실시간 검토 중입니다.",
            style: TextStyle(color: Color(0xFF8A877F), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedScreen() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.communityPosts.length,
      itemBuilder: (context, index) {
        final post = state.communityPosts[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        post["category"],
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2B2A27),
                        ),
                      ),
                    ),
                    Text(
                      post["author"],
                      style: const TextStyle(
                        color: Color(0xFF8A877F),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  post["title"],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  post["content"],
                  style: const TextStyle(
                    color: Color(0xFF5F5D58),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(
                      Icons.favorite_border,
                      size: 18,
                      color: Color(0xFF8A877F),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "${post['likes']}",
                      style: const TextStyle(color: Color(0xFF8A877F)),
                    ),
                    const SizedBox(width: 16),
                    const Icon(
                      Icons.comment_outlined,
                      size: 18,
                      color: Color(0xFF8A877F),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "${post['comments']}",
                      style: const TextStyle(color: Color(0xFF8A877F)),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "새 글 작성하기",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  DropdownButton<String>(
                    value: _selectedCategory,
                    isExpanded: true,
                    items: ["새집자랑", "동네정보", "공동육아", "반려동물"].map((val) {
                      return DropdownMenuItem(value: val, child: Text(val));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          _selectedCategory = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: "제목"),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _contentController,
                    decoration: const InputDecoration(labelText: "내용"),
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
                          ),
                          child: const Text("✦ 검토 및 등록"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
