"""
LG 제품 이미지 크롤러 v2
- __NEXT_DATA__ JSON에서 이미지 URL 직접 추출
- 폴백: 갤러리 img 태그에서 큰 이미지 추출
- Supabase images 컬럼 업데이트

실행:
    python tools/crawl_images_v2.py
"""
import sys, json, os, re, time
sys.stdout.reconfigure(encoding='utf-8')
from playwright.sync_api import sync_playwright
from supabase import create_client

SUPABASE_URL = "https://fdugmidipljoesfsshzn.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZkdWdtaWRpcGxqb2VzZnNzaHpuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA5ODMwMjksImV4cCI6MjA5NjU1OTAyOX0.pxTJHby6s_dvz7K8rciy4efdykaCdZ7BRXEMW44POrw"
TABLE      = "lg_products"
CACHE_FILE = os.path.join(os.path.dirname(__file__), "image_cache_v2.json")

# 진짜 제품 이미지 도메인 패턴
GOOD_CDN = re.compile(r'(kic\.lge\.com|gscs-b2c\.lge\.com|images\.lge\.com|lgimageserver)', re.I)
BAD_PATH = re.compile(r'(banner|logo|icon|badge|home-main|story|upload/admin|favicon|sprite)', re.I)


def _is_product_img(url: str) -> bool:
    if not url or not url.startswith('http'):
        return False
    if BAD_PATH.search(url):
        return False
    return True


def extract_from_next_data(page) -> list[str]:
    """__NEXT_DATA__ JSON에서 이미지 URL 뽑기"""
    try:
        raw = page.evaluate('() => document.getElementById("__NEXT_DATA__")?.textContent')
        if not raw:
            return []
        data = json.loads(raw)

        # JSON 전체를 문자열로 변환 후 CDN URL 패턴 검색
        text = json.dumps(data)
        urls = re.findall(r'https://[^\s"\'\\]+\.(?:jpg|jpeg|png|webp)', text, re.I)
        good = list(dict.fromkeys(  # 순서 유지 중복 제거
            u for u in urls if _is_product_img(u)
                              and GOOD_CDN.search(u)
        ))
        return good[:4]
    except Exception:
        return []


def extract_from_dom(page) -> list[str]:
    """갤러리 img 태그 직접 추출"""
    try:
        # 네트워크 요청에서 이미지 URL 수집
        imgs = page.eval_on_selector_all(
            'img',
            """els => [...new Set(
                els.map(e => e.src || e.dataset.src || e.dataset.lazySrc || '')
                   .filter(s => s.startsWith('http'))
            )]"""
        )
        good = [u for u in imgs if _is_product_img(u) and GOOD_CDN.search(u)]
        return good[:4]
    except Exception:
        return []


def get_images(page, url: str) -> list[str]:
    captured = []

    def on_request(request):
        u = request.url
        if GOOD_CDN.search(u) and _is_product_img(u):
            captured.append(u)

    page.on('request', on_request)
    try:
        page.goto(url.split('?')[0], wait_until='domcontentloaded', timeout=25000)
        page.wait_for_timeout(1500)
        # 스크롤로 lazy-load 유발
        page.evaluate('window.scrollBy(0, 600)')
        page.wait_for_timeout(1000)

        # 1순위: 네트워크 캡처된 CDN 이미지
        good = list(dict.fromkeys(u for u in captured if _is_product_img(u)))
        if good:
            page.remove_listener('request', on_request)
            return good[:4]

        # 2순위: Next.js 데이터
        imgs = extract_from_next_data(page)
        if imgs:
            page.remove_listener('request', on_request)
            return imgs

        # 3순위: DOM img 태그
        imgs = extract_from_dom(page)
        page.remove_listener('request', on_request)
        return imgs

    except Exception as e:
        print(f'    오류: {e}')
        try:
            page.remove_listener('request', on_request)
        except Exception:
            pass
    return []


def main():
    sb = create_client(SUPABASE_URL, SUPABASE_KEY)

    # 이미지 없는 제품만
    rows = sb.table(TABLE).select('model_code,category,product_url,images').execute().data
    no_img = [r for r in rows if not r.get('images') and r.get('product_url')]
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
            url   = row['product_url']
            cat   = row.get('category', '')
            print(f'[{i}/{len(todo)}] {model} [{cat}]', end=' ')

            imgs = get_images(page, url)
            cache[model] = imgs

            if imgs:
                found += 1
                print(f'→ {len(imgs)}장  {imgs[0][:65]}')
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
                print(f'  → 저장 ({i}/{len(todo)}) | 이미지확보:{found} 없음:{skip}')

            time.sleep(0.5)

        browser.close()

    with open(CACHE_FILE, 'w', encoding='utf-8') as f:
        json.dump(cache, f, ensure_ascii=False)

    print(f'\n완료: 이미지 확보 {found}/{len(todo)}개 | 없음 {skip}개')


if __name__ == '__main__':
    main()
