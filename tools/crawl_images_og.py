"""
LG 제품 페이지 og:image 메타태그로 공식 이미지 수집 → Supabase 업데이트

실행:
    python tools/crawl_images_og.py
"""
import sys, json, os, re, time
sys.stdout.reconfigure(encoding='utf-8')
import httpx
from supabase import create_client

SUPABASE_URL = "https://fdugmidipljoesfsshzn.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZkdWdtaWRpcGxqb2VzZnNzaHpuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA5ODMwMjksImV4cCI6MjA5NjU1OTAyOX0.pxTJHby6s_dvz7K8rciy4efdykaCdZ7BRXEMW44POrw"
TABLE      = "lg_products"
CACHE_FILE = os.path.join(os.path.dirname(__file__), "image_cache_og.json")
HEADERS    = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"}

OG_RE  = re.compile(r'<meta[^>]+property=["\']og:image["\'][^>]+content=["\']([^"\']+)["\']', re.I)
OG_RE2 = re.compile(r'<meta[^>]+content=["\']([^"\']+)["\'][^>]+property=["\']og:image["\']', re.I)


def fetch_og_image(url: str) -> list[str]:
    try:
        resp = httpx.get(url.split('?')[0], headers=HEADERS, timeout=12, follow_redirects=True)
        html = resp.text
        m = OG_RE.search(html) or OG_RE2.search(html)
        if m:
            img = m.group(1).strip()
            if img.startswith('http') and not 'logo' in img.lower():
                return [img]
    except Exception as e:
        print(f'    오류: {e}')
    return []


def main():
    sb = create_client(SUPABASE_URL, SUPABASE_KEY)

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
    for i, row in enumerate(todo, 1):
        model = row['model_code']
        cat   = row.get('category', '')
        url   = row['product_url']
        print(f'[{i}/{len(todo)}] {model} [{cat}]', end=' ')

        imgs = fetch_og_image(url)
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

        if i % 30 == 0:
            with open(CACHE_FILE, 'w', encoding='utf-8') as f:
                json.dump(cache, f, ensure_ascii=False)
            print(f'  → 저장 ({i}/{len(todo)}) | 확보:{found} 없음:{skip}')

        time.sleep(0.3)

    with open(CACHE_FILE, 'w', encoding='utf-8') as f:
        json.dump(cache, f, ensure_ascii=False)
    print(f'\n완료: 이미지 확보 {found}/{len(todo)}개 | 없음 {skip}개')


if __name__ == '__main__':
    main()
