"""
lg_products.json 후처리 정제 스크립트
- 모델코드 URL에서 재추출
- 카테고리명 정규화
- 제품명 불필요 텍스트 제거
- 헤더/로고 이미지 필터링
- 중복 제거
"""

import json, re, sys, os

sys.stdout.reconfigure(encoding='utf-8')

SRC = os.path.join(os.path.dirname(__file__), 'lg_products.json')
OUT = os.path.join(os.path.dirname(__file__), 'lg_products_clean.json')

# 카테고리 정규화 규칙 (포함 키워드 → 표준명)
CATEGORY_MAP = [
    (['냉장고', 'refrigerat'], '냉장고'),
    (['김치', 'kimchi'], '김치냉장고'),
    (['세탁기', 'washing'], '세탁기'),
    (['건조기', 'dryer'], '건조기'),
    (['워시타워', 'wash-tower', 'wash_tower'], '워시타워'),
    (['에어컨', 'air-condition'], '에어컨'),
    (['공기청정기', 'air-purif'], '공기청정기'),
    (['청소기', 'vacuum', '로봇청소기'], '청소기'),
    (['스타일러', 'styler'], '스타일러'),
    (['식기세척기', 'dishwasher'], '식기세척기'),
    (['정수기', 'water-purif'], '정수기'),
    (['전자레인지', '광파오븐', 'microwave', 'oven'], '전자레인지/오븐'),
    (['인덕션', '전기레인지', 'electric-stove', 'electric-range'], '인덕션/전기레인지'),
    (['제습기', 'dehumid'], '제습기'),
    (['가습기', 'humid'], '가습기'),
]

SKIP_IMAGES = {
    'img_side_banner', 'img-brand-signature', 'img-brand-object',
    'img-brand-thinq', 'img-brand-lgbest', 'common/images/header',
    'icon', 'logo', 'gnb', 'footer', 'banner',
}

def normalize_category(raw: str) -> str:
    raw_lower = raw.lower()
    for keywords, standard in CATEGORY_MAP:
        if any(kw in raw_lower for kw in keywords):
            return standard
    return raw.split('\n')[0].strip()[:20]  # fallback: 첫 줄 최대 20자

def extract_model_code(url: str) -> str:
    """URL 슬러그에서 모델코드 추출"""
    path = url.split('?')[0].rstrip('/')
    slug = path.split('/')[-1]
    # 후미의 -1, -2, -akor, -akor1, -akor2 제거
    slug = re.sub(r'(-\d+|-akor\d*|-ak\d*)$', '', slug, flags=re.IGNORECASE)
    return slug.upper() if slug else ''

def clean_name(name: str) -> str:
    # "제품 공유하기" 및 이후 텍스트 제거
    name = re.split(r'제품\s*공유하기', name)[0]
    return name.strip()

def filter_images(images: list, model_code: str) -> list:
    result = []
    for img in images:
        if any(skip in img for skip in SKIP_IMAGES):
            continue
        if not any(ext in img.lower() for ext in ['.jpg', '.png', '.webp', '.jpeg']):
            continue
        result.append(img)
    return result[:4]

def main():
    with open(SRC, 'r', encoding='utf-8') as f:
        raw_data = json.load(f)

    cleaned = {}
    skipped = 0

    for key, item in raw_data.items():
        url = item.get('url', '')
        name = clean_name(item.get('name', ''))
        if not name:
            skipped += 1
            continue

        # 모델코드: URL에서 재추출
        model_code = extract_model_code(url)
        if not model_code:
            model_code = extract_model_code(key)  # fallback: JSON key

        # 카테고리 정규화
        category = normalize_category(item.get('category', ''))

        # 이미지 필터링
        images = filter_images(item.get('images', []), model_code)

        # 가격 추출 (specs에서도 시도)
        price = item.get('price')
        if price is None:
            for spec_key, spec_val in (item.get('specs') or {}).items():
                if '정상가' in spec_key or '출시가' in spec_key:
                    m = re.search(r'[\d,]{4,}', str(spec_val))
                    if m:
                        price = int(m.group(0).replace(',', ''))
                        break

        entry = {
            'model_code': model_code,
            'name': name,
            'category': category,
            'brand': 'LG',
            'release_year': item.get('year'),
            'price_new_krw': price,
            'images': images,
            'product_url': url,
            'crawled_at': item.get('crawled_at'),
        }

        # 중복 제거: 같은 모델코드면 이미지 많은 쪽 우선
        if model_code in cleaned:
            existing = cleaned[model_code]
            if len(images) > len(existing.get('images', [])):
                cleaned[model_code] = entry
        else:
            cleaned[model_code] = entry

    products_list = list(cleaned.values())

    with open(OUT, 'w', encoding='utf-8') as f:
        json.dump(products_list, f, ensure_ascii=False, indent=2)

    # 통계
    print(f'원본: {len(raw_data)}개')
    print(f'정제 후: {len(products_list)}개 (스킵: {skipped}, 중복제거: {len(raw_data)-skipped-len(products_list)})')
    print()

    from collections import Counter
    cats = Counter(p['category'] for p in products_list)
    print('카테고리 분포:')
    for cat, cnt in cats.most_common():
        print(f'  {cat}: {cnt}')

    with_model = sum(1 for p in products_list if p['model_code'])
    with_img = sum(1 for p in products_list if p['images'])
    with_price = sum(1 for p in products_list if p['price_new_krw'])
    print(f'\n모델코드 있음: {with_model}/{len(products_list)}')
    print(f'이미지 있음: {with_img}/{len(products_list)}')
    print(f'가격 있음: {with_price}/{len(products_list)}')
    print(f'\n저장 완료: {OUT}')

    # 샘플 출력
    print('\n--- 샘플 3개 ---')
    for p in products_list[:3]:
        print(f"  [{p['category']}] {p['model_code']} | {p['name'][:40]} | {p['release_year']} | {p['price_new_krw']}")

if __name__ == '__main__':
    main()
