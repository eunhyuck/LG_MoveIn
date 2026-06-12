"""
다나와에서 LG 제품 이미지 URL 수집 → Supabase 업데이트

실행:
    python tools/crawl_images_danawa.py
"""
import sys, json, os, re, time
sys.stdout.reconfigure(encoding='utf-8')
from playwright.sync_api import sync_playwright
from supabase import create_client

SUPABASE_URL = "https://fdugmidipljoesfsshzn.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZkdWdtaWRpcGxqb2VzZnNzaHpuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA5ODMwMjksImV4cCI6MjA5NjU1OTAyOX0.pxTJHby6s_dvz7K8rciy4efdykaCdZ7BRXEMW44POrw"
TABLE      = "lg_products"
CACHE_FILE = os.path.join(os.path.dirname(__file__), "image_cache_danawa.json")


def scrape_danawa(page, model: str) -> list[str]:
    """다나와 검색 결과 첫 번째 제품 이미지 추출"""
    try:
        url = f"https://search.danawa.com/dsearch.php?query=LG+{model}&tab=goods"
        page.goto(url, wait_until='domcontentloaded', timeout=20000)
        page.wait_for_timeout(1200)

        # 첫 번째 상품 이미지
        img_selectors = [
            '.main_prodlist .prod_item:first-child .thumb_wrap img',
            '.product_list .item:first-child img.thumb',
            '.main_prodlist img.lazyload',
            '.prod_item img',
        ]
        for sel in img_selectors:
            el = page.query_selector(sel)
            if el:
                src = el.get_attribute('src') or el.get_attribute('data-src') or ''
                if src and src.startswith('http') and not 'logo' in src.lower():
                    # 다나와 썸네일 → 원본 크기로 변환
                    src = re.sub(r'/\d+x\d+/', '/600x600/', src)
                    src = src.replace('_s.', '_l.').replace('_xs.', '_l.')
                    return [src]

        # 폴백: 모든 img 중 상품 이미지처럼 생긴 것
        imgs = page.eval_on_selector_all(
            '.main_prodlist img, .product_list img',
            """els => els.map(e => e.src || e.dataset.src || '').filter(s =>
                s.startsWith('http') && (s.includes('danawa') || s.includes('img.') || s.includes('thumb'))
                && !s.includes('logo') && !s.includes('icon') && !s.includes('banner')
            ).slice(0, 1)"""
        )
        return imgs if imgs else []

    except Exception as e:
        print(f'    다나와 오류: {e}')
        return []


def scrape_naver_img(page, model: str) -> list[str]:
    """네이버쇼핑 첫 번째 상품 이미지"""
    try:
        url = f"https://search.shopping.naver.com/search/all?query=LG+{model}"
        page.goto(url, wait_until='domcontentloaded', timeout=20000)
        page.wait_for_timeout(1200)

        imgs = page.eval_on_selector_all(
            '[class*="product_image"] img, [class*="thumbnail"] img',
            """els => els.map(e => e.src || '').filter(s =>
                s.startsWith('http') && s.includes('shopping')
                && !s.includes('icon') && !s.includes('logo')
            ).slice(0, 1)"""
        )
        return imgs if imgs else []
    except Exception as e:
        print(f'    네이버 오류: {e}')
        return []


def main():
    sb = create_client(SUPABASE_URL, SUPABASE_KEY)

    rows = sb.table(TABLE).select('model_code,category,images').execute().data
    no_img = [r for r in rows if not r.get('images') and r.get('model_code')]
    print(f'이미지 없는 제품: {len(no_img)}개')

    cache: dict = {}
    if os.path.exists(CACHE_FILE):
        with open(CACHE_FILE, encoding='utf-8') as f:
            cache = json.load(f)
    todo = [r for r in no_img if r['model_code'] not in cache]
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
            cat   = row.get('category', '')
            print(f'[{i}/{len(todo)}] {model} [{cat}]', end=' ')

            imgs = scrape_danawa(page, model)
            if not imgs:
                imgs = scrape_naver_img(page, model)

            cache[model] = imgs

            if imgs:
                found += 1
                print(f'→ {imgs[0][:70]}')
                try:
                    sb.table(TABLE).update({'images': imgs}).eq('model_code', model).execute()
                except Exception as e:
                    print(f'    DB오류: {e}')
            else:
                skip += 1
                print('→ 없음')

            if i % 20 == 0:
                with open(CACHE_FILE, 'w', encoding='utf-8') as f:
                    json.dump(cache, f, ensure_ascii=False)
                print(f'  → 저장 ({i}/{len(todo)}) | 확보:{found} 없음:{skip}')

            time.sleep(0.5)

        browser.close()

    with open(CACHE_FILE, 'w', encoding='utf-8') as f:
        json.dump(cache, f, ensure_ascii=False)

    print(f'\n완료: 이미지 확보 {found}/{len(todo)}개 | 없음 {skip}개')


if __name__ == '__main__':
    main()
