"""
Exa 검색으로 LG 제품 정가 수집 → Supabase 업데이트

실행:
    python tools/fetch_prices.py
"""
import sys, json, os, re, time
sys.stdout.reconfigure(encoding='utf-8')
import httpx
from supabase import create_client

SUPABASE_URL = "https://fdugmidipljoesfsshzn.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZkdWdtaWRpcGxqb2VzZnNzaHpuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA5ODMwMjksImV4cCI6MjA5NjU1OTAyOX0.pxTJHby6s_dvz7K8rciy4efdykaCdZ7BRXEMW44POrw"
EXA_KEY      = "efa593a1-3e73-4737-b5c4-f11c5c7c251d"
EXA_URL      = "https://api.exa.ai/search"
TABLE        = "lg_products"
CACHE_FILE   = os.path.join(os.path.dirname(__file__), "price_cache.json")

# 가격 추출 정규식
_PRICE_RE = re.compile(
    r'(\d{1,3}(?:,\d{3})+)\s*원'   # 1,234,000원
    r'|(\d+)\s*만\s*원'             # 130만원
)

def extract_price(text: str) -> int | None:
    """텍스트에서 가전 정가 범위 가격 추출 (10만~1000만원)"""
    candidates = []
    for m in _PRICE_RE.finditer(text):
        if m.group(1):
            v = int(m.group(1).replace(',', ''))
        else:
            v = int(m.group(2)) * 10000
        if 100_000 <= v <= 10_000_000:
            candidates.append(v)
    if not candidates:
        return None
    # 가장 많이 등장하는 가격 (또는 중간값)
    candidates.sort()
    return candidates[len(candidates) // 2]


def exa_search(query: str, domains: list[str]) -> str:
    """Exa 검색 — 결과 텍스트 합쳐서 반환"""
    try:
        resp = httpx.post(
            EXA_URL,
            headers={"x-api-key": EXA_KEY, "Content-Type": "application/json"},
            json={
                "query": query,
                "num_results": 5,
                "include_domains": domains,
                "contents": {"text": {"max_characters": 800}},
            },
            timeout=15,
        )
        data = resp.json()
        texts = []
        for r in data.get("results", []):
            texts.append(r.get("title", "") + " " + (r.get("text") or ""))
        return " ".join(texts)
    except Exception as e:
        print(f"    Exa 오류: {e}")
        return ""


def fetch_price(model: str, name: str) -> int | None:
    # 1차: 다나와 + 네이버쇼핑
    text = exa_search(
        f'LG {model} 가격',
        ["danawa.com", "shopping.naver.com", "prod.danawa.com"]
    )
    price = extract_price(text)
    if price:
        return price

    # 2차: 제품명으로 재시도
    short_name = name[:20] if name else model
    text2 = exa_search(
        f'LG {short_name} 출시가 정가',
        ["danawa.com", "shopping.naver.com", "enuri.com", "cetizen.com"]
    )
    return extract_price(text2)


def main():
    sb = create_client(SUPABASE_URL, SUPABASE_KEY)

    # 가격 없는 제품만 조회
    rows = sb.table(TABLE).select('model_code,name,category,price_new_krw') \
             .is_('price_new_krw', 'null').execute().data
    print(f'가격 없는 제품: {len(rows)}개')

    # 캐시 로드
    cache: dict = {}
    if os.path.exists(CACHE_FILE):
        with open(CACHE_FILE, encoding='utf-8') as f:
            cache = json.load(f)
    todo = [r for r in rows if r['model_code'] not in cache]
    print(f'캐시 {len(cache)}개 | 처리 예정: {len(todo)}개')
    print('=' * 60)

    found = skip = fail = 0
    for i, row in enumerate(todo, 1):
        model = row['model_code']
        name  = row.get('name', '')
        cat   = row.get('category', '')
        print(f'[{i}/{len(todo)}] {model} [{cat}]', end=' ')

        price = fetch_price(model, name)
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
            print(f'  → 캐시 저장 ({i}/{len(todo)}) | 확보:{found} 미확인:{skip}')

        time.sleep(0.8)  # Exa rate limit

    with open(CACHE_FILE, 'w', encoding='utf-8') as f:
        json.dump(cache, f, ensure_ascii=False)

    total = len(todo)
    print(f'\n완료: 가격 확보 {found}/{total}개 | 미확인 {skip}개')


if __name__ == '__main__':
    main()
