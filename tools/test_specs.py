"""5개 제품으로 스펙 크롤러 테스트"""
import sys, json, time, re, os
sys.stdout.reconfigure(encoding='utf-8')
from playwright.sync_api import sync_playwright

BASE_DIR = os.path.dirname(__file__)

def parse_specs(page) -> dict:
    specs = {}

    # ① spec_item (기능/특징)
    items = page.eval_on_selector_all(
        '[class*="spec_item"]',
        """els => els.map(el => {
            const lines = el.innerText.split('\\n').map(t => t.trim()).filter(t => t)
            return lines
        }).filter(lines => lines.length >= 2)"""
    )
    for lines in items:
        key = lines[0]
        val = ', '.join(lines[1:])
        if key and val and key not in specs:
            specs[key] = val

    # ② table 구조
    table_data = page.eval_on_selector_all(
        'table tr',
        """rows => rows.map(row => {
            const cells = [...row.querySelectorAll('th, td')].map(c => c.innerText.trim())
            return cells
        }).filter(cells => cells.length >= 2 && cells[0].trim())"""
    )
    for cells in table_data:
        key = cells[0].strip()
        val = ' / '.join(c for c in cells[1:] if c.strip())
        if key and val and key not in specs and len(key) < 30 and len(val) < 100:
            specs[key] = val

    # ③ 스펙 영역 텍스트에서 "키 : 값" 패턴
    spec_el = page.query_selector('[class*="spec_area"], [id*="spec"], [class*="specArea"]')
    if spec_el:
        full_text = spec_el.inner_text()
        for line in full_text.split('\n'):
            line = line.strip()
            m = re.match(r'^(.{2,25})\s*:\s*(.+)$', line)
            if m:
                k, v = m.group(1).strip(), m.group(2).strip()
                if k not in specs and len(v) < 100:
                    specs[k] = v

    return specs


with open(os.path.join(BASE_DIR, 'lg_products_clean.json'), encoding='utf-8') as f:
    products = json.load(f)

# 카테고리 다양하게 5개 선택
samples = []
seen_cats = set()
for p in products:
    if p.get('product_url') and p['category'] not in seen_cats and len(samples) < 5:
        samples.append(p)
        seen_cats.add(p['category'])

with sync_playwright() as pw:
    browser = pw.chromium.launch(headless=True)
    ctx = browser.new_context(
        locale='ko-KR',
        user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
    )
    page = ctx.new_page()

    for prod in samples:
        url = prod['product_url'].split('?')[0]
        print(f'\n[{prod["category"]}] {prod["model_code"]}')
        print(f'  URL: {url}')

        try:
            page.goto(url, wait_until='domcontentloaded', timeout=30000)
            page.wait_for_timeout(3000)
            page.evaluate('window.scrollBy(0, 600)')
            page.wait_for_timeout(800)

            # 스펙 탭 클릭
            spec_tabs = page.query_selector_all('button:has-text("스펙"), a:has-text("스펙")')
            for tab in spec_tabs:
                if tab.is_visible():
                    tab.click()
                    page.wait_for_timeout(1500)
                    break

            # 더 보기
            more = page.query_selector('button:has-text("스펙 더 보기")')
            if more and more.is_visible():
                more.click()
                page.wait_for_timeout(1000)

            specs = parse_specs(page)
            print(f'  스펙 {len(specs)}개:')
            for k, v in list(specs.items())[:10]:
                print(f'    {k}: {v[:70]}')

        except Exception as e:
            print(f'  ERROR: {e}')

        time.sleep(0.8)

    browser.close()

print('\n테스트 완료')
