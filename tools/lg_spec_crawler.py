"""
LG Korea 제품 스펙 크롤러 v3
- lg_products_clean.json URL 순회
- 스펙 탭 클릭 → "제품 스펙 더 보기" 확장
- .prod-spec-detail 테이블 파싱 (냉장고/세탁기 등)
- [class*="spec_item"] 파싱 (청소기 등)
- 노이즈 필터링
- 결과: lg_products_with_specs.json

실행:
    python tools/lg_spec_crawler.py
"""

import sys, json, re, os, time
sys.stdout.reconfigure(encoding='utf-8')
sys.stderr.reconfigure(encoding='utf-8')

from playwright.sync_api import sync_playwright

BASE_DIR   = os.path.dirname(__file__)
IN_FILE    = os.path.join(BASE_DIR, 'lg_products_clean.json')
OUT_FILE   = os.path.join(BASE_DIR, 'lg_products_with_specs.json')

# ─── 노이즈 필터 ────────────────────────────────────────────────

_NOISE_RE = re.compile(
    r'카드$|이상 결제|이벤트|수집 항목|위탁|수탁|이용 요금|'
    r'재구독|제휴카드|알림 신청|꼭!|총 금액|수량선택|'
    r'정상가|회원할인가|쿠폰할인가|주문|약관|개인정보|'
    r'전기용품 안전인증|전자파 적합성|KC인증|성능$|디자인$|휴대성$|'
    r'품질보증|A/S 책임|결함|소비자피해|제조자|제조국|'
    r'설치 (가능|불가|미권장)|동일모델의 출시'
)

def _is_noise(key: str) -> bool:
    if not key or len(key) > 50:
        return True
    if key.startswith('[') or key.startswith('※'):
        return True
    if _NOISE_RE.search(key):
        return True
    # 숫자로 시작하는 금액 조건
    if re.match(r'^[\d,]+\s*만 원', key):
        return True
    return False

def _clean(v: str) -> str:
    return re.sub(r'\s+', ' ', (v or '').replace('\t', ' ')).strip()


# ─── 스펙 파싱 ──────────────────────────────────────────────────

def parse_specs(page) -> dict:
    specs = {}

    # ① .prod-spec-detail : DT/DD 쌍 (냉장고/세탁기/에어컨 등)
    #   구조: .box > .tit(카테고리) + .spec-info-list > DT(키) + DD(값)
    try:
        pairs = page.eval_on_selector_all(
            '.prod-spec-detail dt',
            '''dts => dts.map(dt => {
                const dd = dt.nextElementSibling
                if (!dd) return null
                const tag = dd.tagName
                if (tag === "DD") {
                    return {k: dt.innerText.trim(), v: dd.innerText.trim()}
                }
                return null
            }).filter(x => x && x.k && x.v)'''
        )
        for item in pairs:
            k, v = _clean(item['k']), _clean(item['v'])
            if k and v and not _is_noise(k) and len(v) < 150:
                specs[k] = v
    except Exception:
        pass

    # ② .prod-spec-detail button.text-line : O/X 불리언 스펙
    try:
        btns = page.eval_on_selector_all(
            '.prod-spec-detail button.text-line',
            '''btns => btns.map(btn => {
                const spans = [...btn.parentElement.querySelectorAll("span")]
                const val = spans.map(s => s.innerText.trim()).join("")
                return {k: btn.innerText.trim(), v: val}
            }).filter(x => x.k && x.v)'''
        )
        for item in btns:
            k, v = _clean(item['k']), _clean(item['v'])
            if k and k not in specs and not _is_noise(k):
                specs[k] = v
    except Exception:
        pass

    # ③ [class*="spec_item"] : 청소기/스타일러 등 (기능 비교 목록)
    try:
        items = page.eval_on_selector_all(
            '[class*="spec_item"]',
            '''els => els.map(el => {
                const lines = el.innerText.split("\\n").map(t => t.trim()).filter(t => t)
                return lines
            }).filter(lines => lines.length >= 2)'''
        )
        for lines in items:
            k = lines[0].strip()
            v = ', '.join(v for v in lines[1:] if v)
            if k and v and k not in specs and not _is_noise(k):
                specs[k] = _clean(v)
    except Exception:
        pass

    return specs


def scrape_one(page, url: str) -> dict:
    try:
        clean_url = url.split('?')[0]
        page.goto(clean_url, wait_until='domcontentloaded', timeout=30000)
        page.wait_for_timeout(3000)

        # sticky 탭 활성화
        page.evaluate('window.scrollBy(0, 700)')
        page.wait_for_timeout(800)

        # 스펙 탭 클릭 — 최대 2회 시도
        for attempt in range(2):
            clicked = False
            for tab in page.query_selector_all('button:has-text("스펙"), a:has-text("스펙")'):
                try:
                    if tab.is_visible():
                        tab.click()
                        page.wait_for_timeout(2500)
                        clicked = True
                        break
                except Exception:
                    pass
            # 스펙 콘텐츠가 로드됐으면 종료
            if page.query_selector('.prod-spec-detail dt'):
                break
            if not clicked:
                break
            page.wait_for_timeout(1000)

        # "제품 스펙 더 보기" 클릭
        try:
            more = page.query_selector('button:has-text("스펙 더 보기")')
            if more and more.is_visible():
                more.click()
                page.wait_for_timeout(1500)
        except Exception:
            pass

        return parse_specs(page)
    except Exception as e:
        print(f'    ERROR: {e}')
        return {}


# ─── 메인 ──────────────────────────────────────────────────────

def main():
    with open(IN_FILE, encoding='utf-8') as f:
        products = json.load(f)

    # 기존 결과 로드 (재시작 지원)
    if os.path.exists(OUT_FILE):
        with open(OUT_FILE, encoding='utf-8') as f:
            prev = json.load(f)
        results  = {p['model_code']: p for p in prev}
        done     = {p['model_code'] for p in prev if p.get('_done_v3')}
    else:
        results = {}
        done    = set()

    todo = [p for p in products if p['model_code'] not in done]
    print(f'총 {len(products)}개 | 완료 {len(done)}개 | 남은 {len(todo)}개')
    print('=' * 60)

    with sync_playwright() as pw:
        browser = pw.chromium.launch(headless=True)
        ctx = browser.new_context(
            locale='ko-KR',
            user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
        )
        page = ctx.new_page()

        for i, prod in enumerate(todo, 1):
            model = prod['model_code']
            cat   = prod['category']
            name  = prod['name'][:25]
            url   = prod.get('product_url', '')

            print(f'[{i}/{len(todo)}] [{cat}] {model} - {name}')

            if not url:
                prod['specs'] = {}
                prod['_done_v3'] = True
                results[model] = prod
                continue

            specs = scrape_one(page, url)

            prod = {**prod, 'specs': specs, '_done_v3': True}
            prod.pop('specs_key', None)   # 구버전 필드 제거
            prod.pop('_spec_crawled', None)
            results[model] = prod

            print(f'    스펙 {len(specs)}개', end='')
            if specs:
                sample = list(specs.items())[:3]
                print(' |', ' / '.join(f'{k}: {v[:20]}' for k, v in sample))
            else:
                print()

            if i % 20 == 0:
                _save(list(results.values()))
                print(f'  → 저장 ({i}/{len(todo)})')

            time.sleep(0.6)

        browser.close()

    _save(list(results.values()))
    done_cnt = sum(1 for p in results.values() if p.get('specs'))
    print(f'\n완료: {len(results)}개 | 스펙 있음: {done_cnt}개')
    print(f'저장: {OUT_FILE}')


def _save(data):
    with open(OUT_FILE, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)


if __name__ == '__main__':
    main()
