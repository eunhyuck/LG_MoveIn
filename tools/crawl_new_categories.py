"""
LG Korea 추가 카테고리 제품 목록 크롤러 (sync_playwright)
- 전자레인지/오븐, 세탁기, 에어컨, 스타일러, 워시타워
- 결과를 lg_products_clean.json 에 병합

실행:
    python tools/crawl_new_categories.py
"""
import sys, json, re, os, time
sys.stdout.reconfigure(encoding='utf-8')
from playwright.sync_api import sync_playwright
from datetime import datetime

BASE_URL = "https://www.lge.co.kr"
CLEAN_FILE = os.path.join(os.path.dirname(__file__), "lg_products_clean.json")

# 카테고리명 → LG 사이트 경로
NEW_CATEGORIES = {
    "전자레인지":  f"{BASE_URL}/microwaves-and-ovens",
    "스타일러":   f"{BASE_URL}/care-solutions/lg-styler",
}


def get_product_urls(page, category_url: str) -> list[str]:
    """카테고리 페이지에서 제품 URL 수집 (더보기 반복 클릭)"""
    try:
        page.goto(category_url, wait_until="domcontentloaded", timeout=30000)
        page.wait_for_timeout(3000)

        for _ in range(15):
            more = page.query_selector(
                "button:has-text('더 보기'), button:has-text('더보기'), button:has-text('전체보기')"
            )
            if not more or not more.is_visible():
                break
            more.click()
            page.wait_for_timeout(1500)

        links = page.eval_on_selector_all(
            "a[href]",
            """els => [...new Set(
                els.map(e => e.href)
                   .filter(h => h && h.includes('/') && !h.endsWith('/'))
            )]"""
        )

        # 카테고리 URL 하위 경로만 (제품 상세 페이지)
        path = category_url.replace(BASE_URL, "")
        urls = [u for u in links
                if u.startswith(BASE_URL + path)
                and u != category_url
                and "?" not in u.split("/")[-1]]
        return list(set(urls))

    except Exception as e:
        print(f"  URL 수집 실패: {e}")
        return []


def scrape_product(page, url: str, category: str) -> dict | None:
    """제품 상세에서 모델코드/이름/이미지/가격 추출"""
    try:
        clean_url = url.split("?")[0]
        page.goto(clean_url, wait_until="domcontentloaded", timeout=30000)
        page.wait_for_timeout(2000)

        # 모델코드 — URL 마지막 세그먼트
        model_code = clean_url.rstrip("/").split("/")[-1].upper()

        # 제품명
        name = ""
        for sel in ["h1.product-name", "h1", ".prod-title", ".pdp-title"]:
            el = page.query_selector(sel)
            if el:
                name = el.inner_text().strip()
                if name:
                    break

        # 이미지
        images = page.eval_on_selector_all(
            "img[src*='images.lge.com'], img[src*='lgimageserver']",
            "els => [...new Set(els.map(e => e.src).filter(s => s && s.startsWith('http')))].slice(0,5)"
        )

        # 가격 (정규식으로 숫자 추출)
        price_new = None
        price_el = page.query_selector(".price-original, .price, [class*='price']")
        if price_el:
            txt = price_el.inner_text()
            m = re.search(r"[\d,]{4,}", txt)
            if m:
                try:
                    price_new = int(m.group().replace(",", ""))
                except:
                    pass

        # 출시연도
        release_year = None
        body_txt = page.inner_text("body")[:3000]
        ym = re.search(r"20(2[0-9])\s*년", body_txt)
        if ym:
            release_year = int("20" + ym.group(1))

        if not model_code or not name:
            return None

        return {
            "model_code":    model_code,
            "name":          name[:80],
            "category":      category,
            "brand":         "LG",
            "release_year":  release_year,
            "price_new_krw": price_new,
            "images":        images,
            "product_url":   clean_url,
            "crawled_at":    datetime.now().isoformat(),
        }

    except Exception as e:
        print(f"    오류: {e}")
        return None


def main():
    # 기존 데이터 로드
    with open(CLEAN_FILE, encoding="utf-8") as f:
        existing = json.load(f)
    existing_codes = {p["model_code"] for p in existing}
    existing_cats  = {p["category"] for p in existing}
    print(f"기존 데이터: {len(existing)}개 ({', '.join(sorted(existing_cats))})")

    new_products = []

    with sync_playwright() as pw:
        browser = pw.chromium.launch(headless=True)
        ctx = browser.new_context(
            locale="ko-KR",
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        )
        page = ctx.new_page()

        for cat_name, cat_url in NEW_CATEGORIES.items():
            print(f"\n▶ [{cat_name}] {cat_url}")
            urls = get_product_urls(page, cat_url)
            print(f"  제품 URL {len(urls)}개 발견")

            cat_new = 0
            for i, url in enumerate(urls, 1):
                model_seg = url.rstrip("/").split("/")[-1].upper()
                if model_seg in existing_codes:
                    print(f"  [{i}/{len(urls)}] SKIP (기존): {model_seg}")
                    continue

                print(f"  [{i}/{len(urls)}] 수집: {url[-50:]}")
                prod = scrape_product(page, url, cat_name)
                if prod:
                    new_products.append(prod)
                    existing_codes.add(prod["model_code"])
                    cat_new += 1
                    print(f"    → {prod['model_code']} | {prod['name'][:30]}")
                time.sleep(0.5)

            print(f"  → [{cat_name}] 신규 {cat_new}개")

        browser.close()

    if not new_products:
        print("\n신규 제품 없음.")
        return

    merged = existing + new_products
    with open(CLEAN_FILE, "w", encoding="utf-8") as f:
        json.dump(merged, f, ensure_ascii=False, indent=2)

    print(f"\n완료: 신규 {len(new_products)}개 추가 → 총 {len(merged)}개")
    cats_new = {}
    for p in new_products:
        cats_new[p["category"]] = cats_new.get(p["category"], 0) + 1
    for c, n in sorted(cats_new.items()):
        print(f"  {c}: {n}개")
    print(f"저장: {CLEAN_FILE}")


if __name__ == "__main__":
    main()
