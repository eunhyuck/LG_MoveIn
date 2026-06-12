"""
LG Korea 전체 가전 제품 크롤러
- LG 사이트 네비게이션에서 카테고리 자동 탐색
- 각 카테고리 전체 제품 목록 수집
- 제품 상세 페이지에서 모델코드 / 출시연도 / 이미지 / 스펙 추출
- 결과: lg_products.json 저장 (Flutter assets/data/ 에 복사해서 사용)

실행:
    pip install playwright
    playwright install chromium
    python tools/lg_crawler.py
"""

import asyncio
import json
import re
import os
import sys
from datetime import datetime
from playwright.async_api import async_playwright, Page

sys.stdout.reconfigure(encoding='utf-8')
sys.stderr.reconfigure(encoding='utf-8')

BASE_URL = "https://www.lge.co.kr"
OUT_FILE = os.path.join(os.path.dirname(__file__), "lg_products.json")

# 가전 카테고리 키워드 (네비에서 자동 탐색 + 이걸로 필터)
APPLIANCE_KEYWORDS = [
    "냉장고", "김치", "세탁기", "건조기", "에어컨", "공기청정기",
    "청소기", "스타일러", "식기세척기", "정수기", "전자레인지",
    "오븐", "인덕션", "전기레인지", "전기밥솥", "음식물처리기",
    "의류건조기", "워시타워", "냉난방기", "제습기", "가습기",
]

# ─── 유틸 ──────────────────────────────────────────────────────

def normalize_year(text: str) -> str | None:
    """텍스트에서 연도 추출 (예: '2023년형' → '2023')"""
    m = re.search(r'20\d{2}', text or '')
    return m.group(0) if m else None


def clean_text(t: str | None) -> str:
    return (t or '').strip()


# ─── 카테고리 자동 탐색 ────────────────────────────────────────

async def discover_categories(page: Page) -> list[dict]:
    """LG 사이트 네비게이션에서 가전 카테고리 URL 자동 수집"""
    print("📡 카테고리 탐색 중...")
    await page.goto(BASE_URL, wait_until="domcontentloaded", timeout=30000)
    await page.wait_for_timeout(2000)

    # 네비게이션 링크 전체 수집
    links = await page.eval_on_selector_all(
        "a[href]",
        """els => els.map(e => ({
            text: e.innerText.trim(),
            href: e.getAttribute('href')
        }))"""
    )

    categories = []
    seen_hrefs = set()

    for link in links:
        href = link.get("href", "") or ""
        text = link.get("text", "") or ""

        # 상대경로 보정
        if href.startswith("/"):
            href = BASE_URL + href

        if not href.startswith(BASE_URL):
            continue
        if href in seen_hrefs:
            continue

        # 가전 키워드 매칭
        if any(kw in text for kw in APPLIANCE_KEYWORDS):
            seen_hrefs.add(href)
            categories.append({"name": text, "url": href})
            print(f"  ✓ {text}: {href}")

    print(f"\n총 {len(categories)}개 카테고리 발견\n")
    return categories


# ─── 제품 목록 수집 ────────────────────────────────────────────

async def collect_product_urls(page: Page, category: dict) -> list[str]:
    """카테고리 페이지에서 제품 상세 URL 목록 수집 (페이지네이션 포함)"""
    urls = set()
    url = category["url"]

    try:
        await page.goto(url, wait_until="domcontentloaded", timeout=30000)
        await page.wait_for_timeout(3000)

        # '더보기' / '전체보기' 버튼 반복 클릭
        for _ in range(10):
            more_btn = await page.query_selector(
                "button:has-text('더 보기'), button:has-text('전체보기'), button:has-text('더보기')"
            )
            if not more_btn:
                break
            await more_btn.click()
            await page.wait_for_timeout(1500)

        # 제품 링크 수집
        links = await page.eval_on_selector_all(
            "a[href*='/products/'], a[href*='/refrigerators/'], a[href*='/washing-machines/'],"
            "a[href*='/dryers/'], a[href*='/air-conditioners/'], a[href*='/vacuum-cleaners/'],"
            "a[href*='/stylers/'], a[href*='/dishwashers/'], a[href*='/air-purifiers/'],"
            "a[href*='/microwaves/'], a[href*='/water-purifiers/']",
            "els => els.map(e => e.href)"
        )

        for link in links:
            if link and link.startswith(BASE_URL) and link != url:
                urls.add(link)

    except Exception as e:
        print(f"  ⚠ 목록 수집 실패 ({category['name']}): {e}")

    return list(urls)


# ─── 제품 상세 수집 ───────────────────────────────────────────

async def scrape_product(page: Page, url: str, category_name: str) -> dict | None:
    """제품 상세 페이지에서 정보 추출"""
    try:
        await page.goto(url, wait_until="domcontentloaded", timeout=30000)
        await page.wait_for_timeout(2000)

        # 모델코드: URL 또는 페이지 내 텍스트에서 추출
        model_code = None
        url_match = re.search(r'/([A-Z0-9]{6,20})(?:\?|$|/)', url)
        if url_match:
            model_code = url_match.group(1)

        if not model_code:
            code_el = await page.query_selector(
                "[class*='model'], [class*='Model'], [data-model], "
                "span:has-text('모델명'), p:has-text('모델명')"
            )
            if code_el:
                raw = await code_el.inner_text()
                m = re.search(r'([A-Z0-9]{5,20})', raw)
                if m:
                    model_code = m.group(1)

        # 제품명
        name_el = await page.query_selector("h1, [class*='product-name'], [class*='productName']")
        name = clean_text(await name_el.inner_text() if name_el else None)

        # 연도: 페이지 텍스트에서 추출
        page_text = await page.inner_text("body")
        year = normalize_year(page_text)

        # 가격
        price_el = await page.query_selector(
            "[class*='price'], [class*='Price'], span:has-text('원')"
        )
        price_text = clean_text(await price_el.inner_text() if price_el else None)
        price_match = re.search(r'[\d,]+', price_text or '')
        price = int(price_match.group(0).replace(',', '')) if price_match else None

        # 이미지 URL 수집 (최대 4장)
        images = await page.eval_on_selector_all(
            "img[src*='lge'], img[src*='images'], [class*='product'] img",
            """els => els
                .map(e => e.src)
                .filter(src => src && !src.includes('icon') && !src.includes('logo')
                               && (src.endsWith('.jpg') || src.endsWith('.png')
                                   || src.endsWith('.webp') || src.includes('.jpg?')))
                .slice(0, 4)"""
        )

        # 스펙 테이블
        specs = {}
        spec_rows = await page.query_selector_all(
            "table tr, [class*='spec'] li, [class*='feature'] li, dl"
        )
        for row in spec_rows[:30]:
            text = clean_text(await row.inner_text())
            if ':' in text or '\t' in text or '\n' in text:
                parts = re.split(r'[:\t\n]', text, maxsplit=1)
                if len(parts) == 2 and parts[0].strip() and parts[1].strip():
                    specs[parts[0].strip()] = parts[1].strip()

        if not name and not model_code:
            return None

        return {
            "model_code": model_code or "",
            "name": name,
            "category": category_name,
            "year": year,
            "price": price,
            "images": images,
            "specs": specs,
            "url": url,
            "crawled_at": datetime.now().isoformat(),
        }

    except Exception as e:
        print(f"    ⚠ 제품 수집 실패 ({url}): {e}")
        return None


# ─── 메인 ──────────────────────────────────────────────────────

async def main():
    print("=" * 60)
    print("LG Korea 전체 가전 크롤러 시작")
    print("=" * 60)

    all_products: dict[str, dict] = {}

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=False)  # headless=True 로 바꾸면 창 없이 실행
        context = await browser.new_context(
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
            locale="ko-KR",
        )
        page = await context.new_page()

        # 1) 카테고리 자동 탐색
        categories = await discover_categories(page)

        if not categories:
            print("⚠ 카테고리를 찾지 못했습니다. 사이트 구조가 변경됐을 수 있어요.")
            print("  → 하드코딩된 카테고리로 진행합니다.")
            categories = [
                {"name": "냉장고",    "url": f"{BASE_URL}/refrigerators"},
                {"name": "김치냉장고","url": f"{BASE_URL}/kimchi-refrigerators"},
                {"name": "세탁기",    "url": f"{BASE_URL}/washing-machines"},
                {"name": "건조기",    "url": f"{BASE_URL}/dryers"},
                {"name": "에어컨",    "url": f"{BASE_URL}/air-conditioners"},
                {"name": "공기청정기","url": f"{BASE_URL}/air-purifiers"},
                {"name": "청소기",    "url": f"{BASE_URL}/vacuum-cleaners"},
                {"name": "스타일러",  "url": f"{BASE_URL}/stylers"},
                {"name": "식기세척기","url": f"{BASE_URL}/dishwashers"},
                {"name": "정수기",    "url": f"{BASE_URL}/water-purifiers"},
                {"name": "전자레인지","url": f"{BASE_URL}/microwaves"},
            ]

        # 2) 카테고리별 제품 수집
        for cat in categories:
            print(f"\n{'─'*50}")
            print(f"📦 [{cat['name']}] 제품 목록 수집 중...")

            product_urls = await collect_product_urls(page, cat)
            print(f"  → {len(product_urls)}개 제품 URL 발견")

            for i, purl in enumerate(product_urls, 1):
                print(f"  [{i}/{len(product_urls)}] {purl}")
                product = await scrape_product(page, purl, cat["name"])
                if product:
                    key = product.get("model_code") or purl.split("/")[-1]
                    all_products[key] = product
                    print(f"    ✓ {product['name']} ({product.get('year', '연도불명')})")
                await asyncio.sleep(0.8)  # 서버 부하 방지

        await browser.close()

    # 3) 저장
    print(f"\n{'='*60}")
    print(f"총 {len(all_products)}개 제품 수집 완료")

    with open(OUT_FILE, "w", encoding="utf-8") as f:
        json.dump(all_products, f, ensure_ascii=False, indent=2)

    print(f"저장 완료: {OUT_FILE}")
    print("\n다음 단계:")
    print("  cp tools/lg_products.json assets/data/lg_products.json")
    print("  → Flutter 앱에서 모델코드 조회에 활용")


if __name__ == "__main__":
    asyncio.run(main())
