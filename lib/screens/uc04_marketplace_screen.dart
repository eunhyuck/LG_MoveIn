import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lg_move_in/models/move_in_state.dart';

class UC04MarketplaceScreen extends StatefulWidget {
  const UC04MarketplaceScreen({super.key});

  @override
  State<UC04MarketplaceScreen> createState() => _UC04MarketplaceScreenState();
}

class _UC04MarketplaceScreenState extends State<UC04MarketplaceScreen> {
  String _selectedCategory = '전체';
  final _categories = ['전체', '냉장고', '세탁기', '에어컨', '건조기'];

  List<TradeInListing> get _filtered {
    final all = MoveInState.instance.marketListings;
    if (_selectedCategory == '전체') return all;
    return all.where((l) => l.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    final listings = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('중고 가전 마켓'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2B2A27),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${MoveInState.instance.marketListings.length}개',
                style: const TextStyle(fontSize: 13, color: Color(0xFF8A877F)),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Category filter
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final cat = _categories[i];
                  final selected = cat == _selectedCategory;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected ? const Color(0xFF2B2A27) : const Color(0xFFF5F4EF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : const Color(0xFF8A877F),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 1),
          // Listings
          Expanded(
            child: listings.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.storefront_outlined, size: 64, color: Color(0xFFD9D7D0)),
                        SizedBox(height: 16),
                        Text('아직 게시된 매물이 없습니다', style: TextStyle(color: Color(0xFF8A877F))),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: listings.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) => _ListingCard(listing: listings[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  final TradeInListing listing;
  const _ListingCard({required this.listing});

  @override
  Widget build(BuildContext context) {
    final timeAgo = _timeAgo(listing.postedAt);
    final gradeColor = switch (listing.grade) {
      'A' => const Color(0xFF2B7A3E),
      'B' => const Color(0xFF8A877F),
      _ => const Color(0xFFE6007E),
    };

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _ListingDetailScreen(listing: listing)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: listing.isMine
              ? Border.all(color: const Color(0xFFE6007E), width: 1.5)
              : null,
        ),
        child: Row(
          children: [
            // Photo
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              child: SizedBox(
                width: 100,
                height: 100,
                child: listing.imageDataUrl != null
                    ? Image.memory(
                        base64Decode(listing.imageDataUrl!.split(',').last),
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: const Color(0xFFF0EEE8),
                        child: Icon(_categoryIcon(listing.category), size: 36, color: const Color(0xFFADA9A1)),
                      ),
              ),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _badge(listing.category, const Color(0xFF2B2A27)),
                        const SizedBox(width: 6),
                        _badge('${listing.grade}급', gradeColor),
                        if (listing.isMine) ...[
                          const SizedBox(width: 6),
                          _badge('내 게시글', const Color(0xFFE6007E)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      listing.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2B2A27)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      listing.modelHint,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF8A877F)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${(listing.price / 10000).round()}만원',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF2B2A27)),
                        ),
                        Text(timeAgo, style: const TextStyle(fontSize: 11, color: Color(0xFFADA9A1))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }

  IconData _categoryIcon(String cat) => switch (cat) {
    '냉장고' => Icons.kitchen,
    '세탁기' => Icons.local_laundry_service,
    '에어컨' => Icons.air,
    '건조기' => Icons.dry,
    _ => Icons.electrical_services,
  };

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }
}

// ─── 수정 화면 ────────────────────────────────────────────────────
class _ListingEditScreen extends StatefulWidget {
  final TradeInListing listing;
  const _ListingEditScreen({required this.listing});

  @override
  State<_ListingEditScreen> createState() => _ListingEditScreenState();
}

class _ListingEditScreenState extends State<_ListingEditScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _bodyCtrl;
  late String _grade;
  late List<String> _defects;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.listing.title);
    _priceCtrl = TextEditingController(text: widget.listing.price.toString());
    _bodyCtrl  = TextEditingController(text: widget.listing.body);
    _grade     = widget.listing.grade;
    _defects   = List.from(widget.listing.defects);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _priceCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final idx = MoveInState.instance.marketListings
        .indexWhere((l) => l.id == widget.listing.id);
    if (idx == -1) return;

    final updated = widget.listing.copyWith(
      title: _titleCtrl.text.trim(),
      price: int.tryParse(_priceCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? widget.listing.price,
      body: _bodyCtrl.text.trim(),
      grade: _grade,
      defects: List.from(_defects),
    );
    MoveInState.instance.marketListings[idx] = updated;

    Navigator.pop(context); // 수정 화면 닫기
    Navigator.pop(context); // 상세 화면 닫기 (목록에서 다시 열면 갱신됨)
  }

  void _addDefect() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('하자 추가'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: '예: 뒷면 스크래치')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) setState(() => _defects.add(ctrl.text.trim()));
              Navigator.pop(ctx);
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('게시글 수정'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2B2A27),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('저장', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE6007E), fontSize: 15)),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF4F5F8),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('제목', TextField(
            controller: _titleCtrl,
            decoration: _dec('제목을 입력하세요'),
            maxLength: 50,
          )),
          const SizedBox(height: 12),
          _section('희망 판매가', TextField(
            controller: _priceCtrl,
            keyboardType: TextInputType.number,
            decoration: _dec('원 단위 숫자 입력 (예: 650000)'),
          )),
          const SizedBox(height: 12),
          _section('상태 등급', Row(
            children: ['A', 'B', 'C'].map((g) {
              final selected = _grade == g;
              final color = g == 'A' ? const Color(0xFF2B7A3E) : g == 'B' ? const Color(0xFF8A877F) : const Color(0xFFE6007E);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _grade = g),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? color : Colors.white,
                      border: Border.all(color: selected ? color : const Color(0xFFE0DED8)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$g급',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: selected ? Colors.white : const Color(0xFF8A877F),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          )),
          const SizedBox(height: 12),
          _section('하자 목록',
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ..._defects.map((d) => Chip(
                  label: Text(d, style: const TextStyle(fontSize: 12)),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () => setState(() => _defects.remove(d)),
                  backgroundColor: const Color(0xFFFFFBEF),
                  side: const BorderSide(color: Color(0xFFFFCB8E)),
                )),
                GestureDetector(
                  onTap: _addDefect,
                  child: const Chip(
                    label: Text('+ 추가', style: TextStyle(fontSize: 12, color: Color(0xFF8A877F))),
                    backgroundColor: Color(0xFFF0EEE8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _section('판매 본문', TextField(
            controller: _bodyCtrl,
            maxLines: 8,
            decoration: _dec('제품 상태, 구매 시기, 거래 방법 등을 자유롭게 작성하세요'),
          )),
          const SizedBox(height: 80),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE6007E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('수정 완료', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ),
      ),
    );
  }

  Widget _section(String label, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2B2A27))),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.all(12),
        child: child,
      ),
    ],
  );

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFFADA9A1), fontSize: 13),
    border: InputBorder.none,
    isDense: true,
    counterText: '',
  );
}

class _ListingDetailScreen extends StatelessWidget {
  final TradeInListing listing;
  const _ListingDetailScreen({required this.listing});

  @override
  Widget build(BuildContext context) {
    final gradeColor = switch (listing.grade) {
      'A' => const Color(0xFF2B7A3E),
      'B' => const Color(0xFF8A877F),
      _ => const Color(0xFFE6007E),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(listing.category),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2B2A27),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo area
            SizedBox(
              width: double.infinity,
              height: 280,
              child: listing.imageDataUrl != null
                  ? Image.memory(
                      base64Decode(listing.imageDataUrl!.split(',').last),
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: const Color(0xFFF0EEE8),
                      child: Icon(_categoryIcon(listing.category), size: 80, color: const Color(0xFFADA9A1)),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badges
                  Row(
                    children: [
                      _badge(listing.category, const Color(0xFF2B2A27)),
                      const SizedBox(width: 8),
                      _badge('${listing.grade}급', gradeColor),
                      if (listing.isMine) ...[
                        const SizedBox(width: 8),
                        _badge('내 게시글', const Color(0xFFE6007E)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(listing.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2B2A27))),
                  const SizedBox(height: 4),
                  Text(
                    '${(listing.price / 10000).round()}만원',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFE6007E)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '시세 ${(listing.priceMin / 10000).round()}만원 ~ ${(listing.priceMax / 10000).round()}만원',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF8A877F)),
                  ),
                  const SizedBox(height: 16),
                  // Seller / time
                  Row(
                    children: [
                      const CircleAvatar(radius: 14, backgroundColor: Color(0xFFE0DED8), child: Icon(Icons.person, size: 16, color: Color(0xFF8A877F))),
                      const SizedBox(width: 8),
                      Text(listing.seller, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const Spacer(),
                      Text(_timeAgo(listing.postedAt), style: const TextStyle(fontSize: 12, color: Color(0xFFADA9A1))),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFFE0DED8)),
                  const SizedBox(height: 16),
                  // Body
                  Text(listing.body, style: const TextStyle(fontSize: 14, color: Color(0xFF2B2A27), height: 1.7)),
                  // Defects
                  if (listing.defects.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('AI 감지 하자', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFE65100))),
                          const SizedBox(height: 8),
                          ...listing.defects.map((d) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFE65100)),
                                const SizedBox(width: 6),
                                Text(d, style: const TextStyle(fontSize: 13)),
                              ],
                            ),
                          )),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: listing.isMine
              ? Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _deleteListing(context),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('삭제', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFCC0000),
                          side: const BorderSide(color: Color(0xFFCC0000)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () => _editListing(context),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('수정', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2B2A27),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                )
              : ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('판매자에게 채팅을 보냈습니다.')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE6007E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('채팅으로 문의하기', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
        ),
      ),
    );
  }

  void _deleteListing(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('게시글 삭제'),
        content: const Text('이 매물을 마켓에서 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              MoveInState.instance.marketListings.removeWhere((l) => l.id == listing.id);
              Navigator.pop(ctx);         // close dialog
              Navigator.pop(context);     // close detail screen
            },
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFCC0000)),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _editListing(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _ListingEditScreen(listing: listing)),
    );
  }

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
    child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
  );

  IconData _categoryIcon(String cat) => switch (cat) {
    '냉장고' => Icons.kitchen,
    '세탁기' => Icons.local_laundry_service,
    '에어컨' => Icons.air,
    '건조기' => Icons.dry,
    _ => Icons.electrical_services,
  };

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }
}
