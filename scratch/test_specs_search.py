from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options
import time

options = Options()
options.add_argument("--headless")
options.add_argument("--no-sandbox")
options.add_argument("--disable-dev-shm-usage")
options.add_argument("user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")

driver = webdriver.Chrome(options=options)

try:
    url = "https://www.lge.co.kr/refrigerators/m876gbb231"
    print(f"Connecting to: {url}")
    driver.get(url)
    time.sleep(5)
    
    # Let's search for buttons to expand specs if any
    buttons = driver.find_elements(By.TAG_NAME, "button")
    for btn in buttons:
        btn_text = btn.text.strip()
        if "스펙" in btn_text or "상세" in btn_text or "더보기" in btn_text:
            print(f"Found expandable button: {btn_text}")
            try:
                # scroll to button and click
                driver.execute_script("arguments[0].scrollIntoView(true);", btn)
                time.sleep(1)
                btn.click()
                print("Clicked button successfully.")
                time.sleep(2)
            except Exception as e:
                print("Click failed:", e)

    dts = driver.find_elements(By.TAG_NAME, "dt")
    dds = driver.find_elements(By.TAG_NAME, "dd")
    
    print(f"Total dt elements: {len(dts)}")
    for idx, dt in enumerate(dts):
        dt_text = dt.text.strip()
        dd_text = dds[idx].text.strip() if idx < len(dds) else ""
        if any(term in dt_text for term in ["크기", "치수", "폭", "높이", "깊이", "외형", "가로", "세로"]):
            print(f"Match: dt={dt_text} -> dd={dd_text}")
        elif "x" in dd_text.lower() and "mm" in dd_text.lower():
            print(f"Potential dimension Match: dt={dt_text} -> dd={dd_text}")

finally:
    driver.quit()
