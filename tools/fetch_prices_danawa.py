"""
다나와 직접 크롤링으로 LG 제품 정가 수집 → Supabase 업데이트

실행:
    python tools/fetch_prices_danawa.py
"""
import sys, json, os, re, time
sys.stdout.reconfigure(encoding='utf-8')
from playwright.sync_api import sync_playwright
from supabase import create_client

SUPABASE_URL = "https://fdugmidipljoesfsshzn.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZkdWdtaWRpcGxqb2VzZnNzaHpuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA5ODMwMjksImV4cCI6MjA5NjU1OTAyOX0.pxTJHby6s_dvz7K8rciy4efdykaCdZ7BRXEMW44POrw"
TABLE      = "lg_products"
CACHE_FILE = os.path.join(os.path.dirname(__file__), "price_cache_danawa.json")

_PRICE_RE = re.compile(r'[\d,]{4,}')

def parse_price(text: str) -> int | None:
    for m in _PRICE_RE.finditer(text.replace(' ', '')):
        try:
            v = int(m.group().replace(',', ''))
            if 50_000 <= v <= 15_000_000:
                return v
        except:
            pass
    return None

def scrape_danawa(page, model: str) -> int | None:
    try:
        url = f"https://search.danawa.com/dsearch.php?query=LG+{model}&tab=goods"
        page.goto(url, wait_until='domcontentloaded', timeout=20000)
        page.wait_for_timeout(1500)

        # 최저가 텍스트 (다나와 상품 목록 — .price-sect 또는 .low_price)
        for sel in ['.price-sect strong', '.low_price strong', '.item_price .price', '.pricelist .price']:
            el = page.query_selector(sel)
            if el:
                txt = el.inner_text().strip()
                p = parse_price(txt)
                if p:
                    return p

        # 폴백: 첫 번째 상품 카드 텍스트에서 가격 추출
        card = page.query_selector('.main_prodlist .prod_item, .product_list .item')
        if card:
            txt = card.inner_text()
            prices = []
            for m in _PRICE_RE.finditer(txt.replace(',', '')):
                v = int(m.group())
                if 50_000 <= v <= 15_000_000:
                    prices.append(v)
            if prices:
                return min(prices)
    except Exception as e:
        print(f'    다나와 오류: {e}')
    return None


def scrape_naver(page, model: str, name: str) -> int | None:
    try:
        query = f"LG {model}"
        url = f"https://search.shopping.naver.com/search/all?query={query}"
        page.goto(url, wait_until='domcontentloaded', timeout=20000)
        page.wait_for_timeout(1500)

        for sel in [
            '[class*="price_num"]',
            '[class*="price__"] em',
            '.price_area .price',
            'strong[class*="price"]',
        ]:
            el = page.query_selector(sel)
            if el:
                txt = el.inner_text().strip()
                p = parse_price(txt)
                if p:
                    return p
    except Exception as e:
        print(f'    네이버 오류: {e}')
    return None


def main():
    sb = create_client(SUPABASE_URL, SUPABASE_KEY)

    rows = sb.table(TABLE).select('model_code,name,category,price_new_krw') \
             .is_('price_new_krw', 'null').execute().data
    print(f'가격 없는 제품: {len(rows)}개')

    cache: dict = {}
    if os.path.exists(CACHE_FILE):
        with open(CACHE_FILE, encoding='utf-8') as f:
            cache = json.load(f)
    todo = [r for r in rows if r['model_code'] not in cache]
    print(f'캐시 {len(cache)}개 | 처리 예정: {len(todo)}개')
    print('=' * 60)

    found = skip = 0

    with sync_playwright() as pw:
        browser = pw.chromium.launch(headless=True)
        ctx = browser.new_context(
            locale='ko-KR',
            user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
        )
        page = ctx.new_page()

        for i, row in enumerate(todo, 1):
            model = row['model_code']
            name  = row.get('name', '')
            cat   = row.get('category', '')
            print(f'[{i}/{len(todo)}] {model} [{cat}]', end=' ')

            # 1차: 다나와
            price = scrape_danawa(page, model)

            # 2차: 네이버쇼핑
            if not price:
                price = scrape_naver(page, model, name)

            cache[model] = price

            if price:
                found += 1
                print(f'→ {price:,}원 ({price//10000}만원)')
                try:
                    sb.table(TABLE).update({'price_new_krw': price}).eq('model_code', model).execute()
                except Exception as e:
                    print(f'    DB오류: {e}')
            else:
                skip += 1
                print('→ 미확인')

            if i % 20 == 0:
                with open(CACHE_FILE, 'w', encoding='utf-8') as f:
                    json.dump(cache, f, ensure_ascii=False)
                print(f'  → 저장 ({i}/{len(todo)}) | 확보:{found} 미확인:{skip}')

            time.sleep(0.4)

        browser.close()

    with open(CACHE_FILE, 'w', encoding='utf-8') as f:
        json.dump(cache, f, ensure_ascii=False)

    print(f'\n완료: 가격 확보 {found}/{len(todo)}개 | 미확인 {skip}개')


if __name__ == '__main__':
    main()
