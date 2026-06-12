"""
LG 제품 이미지 URL 크롤러
- lg_products_with_specs.json 의 product_url 순회
- 첫 번째 제품 이미지 URL 추출
- Supabase images 컬럼 업데이트

실행:
    python tools/crawl_images.py
"""
import sys, json, os, time
sys.stdout.reconfigure(encoding='utf-8')
from playwright.sync_api import sync_playwright
from supabase import create_client

BASE_DIR = os.path.dirname(__file__)
IN_FILE  = os.path.join(BASE_DIR, 'lg_products_with_specs.json')
CACHE    = os.path.join(BASE_DIR, 'image_cache.json')

SUPABASE_URL = "https://fdugmidipljoesfsshzn.supabase.co"
SUPABASE_KEY = os.environ.get(
    "SUPABASE_SERVICE_KEY",
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZkdWdtaWRpcGxqb2VzZnNzaHpuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA5ODMwMjksImV4cCI6MjA5NjU1OTAyOX0.pxTJHby6s_dvz7K8rciy4efdykaCdZ7BRXEMW44POrw"
)

IMG_SELECTORS = [
    # LG Korea 제품 상세 — 메인 슬라이더 이미지
    '.prod-gallery__img img',
    '.swiper-slide-active img',
    '.product-image img',
    '[class*="product-gallery"] img',
    '[class*="pdp-gallery"] img',
    '[class*="main-image"] img',
    # 폴백: lge.com CDN 이미지 전체에서 첫번째 큰 것
    'img[src*="images.lge.com"]',
    'img[src*="kic.lge.com"]',
    'img[src*="lgimageserver"]',
]

def get_images(page, url: str) -> list[str]:
    try:
        page.goto(url.split('?')[0], wait_until='domcontentloaded', timeout=25000)
        page.wait_for_timeout(2500)

        for sel in IMG_SELECTORS:
            try:
                imgs = page.eval_on_selector_all(
                    sel,
                    """els => [...new Set(
                        els.map(e => e.src || e.dataset.src || '')
                           .filter(s => s.startsWith('http') && !s.includes('icon') && !s.includes('logo') && !s.includes('badge'))
                    )].slice(0, 4)"""
                )
                # 작은 아이콘 제거 (width/height 기준)
                good = []
                for src in imgs:
                    if any(x in src for x in ['_480', '_600', '_720', '_960', '480x', '600x', 'medium', 'large', 'main']):
                        good.append(src)
                    elif not any(x in src for x in ['_40', '_60', '_80', '_100', 'thumb', 'icon', 'logo']):
                        good.append(src)
                if good:
                    return good[:3]
            except Exception:
                pass

        return []
    except Exception as e:
        print(f'    오류: {e}')
        return []


def main():
    with open(IN_FILE, encoding='utf-8') as f:
        products = json.load(f)

    # 캐시 로드 (재시작 지원)
    cache: dict[str, list] = {}
    if os.path.exists(CACHE):
        with open(CACHE, encoding='utf-8') as f:
            cache = json.load(f)
    print(f'캐시 {len(cache)}개 로드')

    todo = [p for p in products if p.get('product_url') and p['model_code'] not in cache]
    print(f'총 {len(products)}개 | 완료 {len(cache)}개 | 남은 {len(todo)}개')
    print('=' * 60)

    sb = create_client(SUPABASE_URL, SUPABASE_KEY)

    with sync_playwright() as pw:
        browser = pw.chromium.launch(headless=True)
        ctx = browser.new_context(
            locale='ko-KR',
            user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
        )
        page = ctx.new_page()

        for i, prod in enumerate(todo, 1):
            model = prod['model_code']
            url   = prod['product_url']
            print(f'[{i}/{len(todo)}] {model} ({prod.get("category","")})', end=' ')

            imgs = get_images(page, url)
            cache[model] = imgs
            print(f'→ {len(imgs)}장', imgs[0][:60] if imgs else '없음')

            # Supabase 업데이트
            try:
                sb.table('lg_products').update({'images': imgs}).eq('model_code', model).execute()
            except Exception as e:
                print(f'    DB오류: {e}')

            # 20개마다 캐시 저장
            if i % 20 == 0:
                with open(CACHE, 'w', encoding='utf-8') as f:
                    json.dump(cache, f, ensure_ascii=False)
                print(f'  → 캐시 저장 ({i}/{len(todo)})')

            time.sleep(0.5)

        browser.close()

    # 최종 캐시 저장
    with open(CACHE, 'w', encoding='utf-8') as f:
        json.dump(cache, f, ensure_ascii=False)

    found = sum(1 for v in cache.values() if v)
    print(f'\n완료: {len(cache)}개 처리 | 이미지 확보: {found}개')


if __name__ == '__main__':
    main()
