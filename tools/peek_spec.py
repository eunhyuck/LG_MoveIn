"""prod-spec-detail 실제 DOM 자식 구조 확인"""
import sys, json
sys.stdout.reconfigure(encoding='utf-8')
from playwright.sync_api import sync_playwright

with open('tools/lg_products_clean.json', encoding='utf-8') as f:
    prods = json.load(f)
fridge = next(p for p in prods if p['category'] == '냉장고' and p.get('product_url'))
url = fridge['product_url'].split('?')[0]

with sync_playwright() as pw:
    browser = pw.chromium.launch(headless=True)
    page = browser.new_page(locale='ko-KR',
        user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36')
    page.goto(url, wait_until='domcontentloaded', timeout=30000)
    page.wait_for_timeout(3000)
    page.evaluate('window.scrollBy(0, 700)')
    page.wait_for_timeout(600)
    for tab in page.query_selector_all('button:has-text("스펙"), a:has-text("스펙")'):
        if tab.is_visible():
            tab.click(); page.wait_for_timeout(2000); break
    more = page.query_selector('button:has-text("스펙 더 보기")')
    if more and more.is_visible():
        more.click(); page.wait_for_timeout(1500)

    # prod-spec-detail 직접 자식 구조 파악
    print('=== prod-spec-detail 자식 태그/클래스 ===')
    structure = page.eval_on_selector_all(
        '.prod-spec-detail *',
        '''els => els.slice(0, 60).map(el => ({
            tag: el.tagName,
            cls: el.className,
            text: el.children.length === 0 ? el.innerText.trim().slice(0, 40) : ""
        })).filter(e => e.text || e.cls)'''
    )
    for s in structure[:40]:
        print(f'  <{s["tag"]}> class={s["cls"][:40]!r}  text={s["text"]!r}')

    browser.close()
