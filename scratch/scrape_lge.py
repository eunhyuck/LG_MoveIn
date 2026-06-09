import os
import sys
import time
import json
import re
import requests
from urllib.parse import urljoin
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options
from bs4 import BeautifulSoup

# Configure Selenium headlessly
options = Options()
options.add_argument("--headless")
options.add_argument("--no-sandbox")
options.add_argument("--disable-dev-shm-usage")
options.add_argument("user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")

CATEGORIES = {
    "refrigerators": "https://www.lge.co.kr/refrigerators",
    "washers": "https://www.lge.co.kr/washing-machines",
    "air-conditioners": "https://www.lge.co.kr/air-conditioners",
    "dryers": "https://www.lge.co.kr/dryers"
}

BASE_DIR = "/Users/baenaongunmandu/Desktop/LG MoveIn/lg_move_in/assets"
IMAGES_DIR = os.path.join(BASE_DIR, "images")
DATA_DIR = os.path.join(BASE_DIR, "data")

def log(msg):
    print(f"[*] {msg}")
    sys.stdout.flush()

def download_file(url, filepath):
    try:
        headers = {
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        }
        response = requests.get(url, headers=headers, stream=True, timeout=20)
        if response.status_code == 200:
            os.makedirs(os.path.dirname(filepath), exist_ok=True)
            with open(filepath, 'wb') as f:
                for chunk in response.iter_content(1024):
                    f.write(chunk)
            log(f"Successfully downloaded: {filepath}")
            return True
        else:
            log(f"Failed to download {url}: Status {response.status_code}")
    except Exception as e:
        log(f"Error downloading {url}: {e}")
    return False

def parse_dims(text):
    # Clean text: remove commas in numbers (e.g. 1,860 -> 1860)
    cleaned = text.replace(",", "")
    # Find all 3 to 4 digit numbers
    numbers = re.findall(r'\b\d{3,4}\b', cleaned)
    if len(numbers) >= 3:
        w = int(numbers[0])
        h = int(numbers[1])
        d = int(numbers[2])
        # Validate that dimensions fall in typical home appliance ranges (100mm to 3000mm)
        if 100 <= w <= 3000 and 100 <= h <= 3000 and 100 <= d <= 3000:
            return {"width": w, "height": h, "depth": d}
    return None

def choose_images(gallery_urls):
    front_url = None
    side_url = None
    
    # 1. Look for medium01 or large01 or small01 (excluding interior)
    for url in gallery_urls:
        filename = url.split("/")[-1].lower()
        if any(f in filename for f in ["01.jpg", "01.png"]) and "interior" not in filename:
            front_url = url
            break
            
    # 2. Look for medium02 or large02 or small02 (excluding interior)
    for url in gallery_urls:
        filename = url.split("/")[-1].lower()
        if any(f in filename for f in ["02.jpg", "02.png"]) and "interior" not in filename:
            side_url = url
            break
            
    # Fallback if front_url is not found
    if not front_url:
        non_interior = [u for u in gallery_urls if "interior" not in u.lower()]
        if non_interior:
            front_url = non_interior[0]
            if len(non_interior) > 1:
                side_url = non_interior[1]
        else:
            if gallery_urls:
                front_url = gallery_urls[0]
                if len(gallery_urls) > 1:
                    side_url = gallery_urls[1]
                    
    # Fallback if side_url is not found
    if not side_url:
        non_front = [u for u in gallery_urls if u != front_url]
        if non_front:
            side_url = non_front[0]
        else:
            side_url = front_url
            
    return front_url, side_url

def main():
    log("Initializing driver...")
    driver = webdriver.Chrome(options=options)
    
    products_db = {}
    
    try:
        for cat_name, cat_url in CATEGORIES.items():
            log(f"\n==================== Category: {cat_name} ====================")
            driver.get(cat_url)
            time.sleep(5)
            
            # Find the top 5 ranking anchors
            anchors = driver.find_elements(By.TAG_NAME, "a")
            links = []
            for a in anchors:
                href = a.get_attribute("href")
                text = a.text.strip().replace("\n", " ")
                if href and any(term in text for term in ["1위", "2위", "3위", "4위", "5위"]):
                    if href not in links:
                        links.append(href)
                        
            # Fallback if top 5 rank anchors were not successfully matched
            if len(links) < 5:
                log("Rank labels not found in all anchors, collecting standard product links...")
                for a in anchors:
                    href = a.get_attribute("href")
                    if href and f"/{cat_name}/" in href:
                        if not any(x in href for x in ["subCateId", "lineupId", "#", "compare"]):
                            if href not in links:
                                links.append(href)
                                if len(links) >= 5:
                                    break
                                    
            links = links[:5]
            log(f"Selected product links: {links}")
            products_db[cat_name] = []
            
            for rank_idx, url in enumerate(links):
                rank = rank_idx + 1
                log(f"[{cat_name} #{rank}] Fetching detail page: {url}")
                driver.get(url)
                time.sleep(5)
                
                # Expand specs using JavaScript to avoid StaleElementReferenceException
                driver.execute_script("""
                    var buttons = document.querySelectorAll("button");
                    for (var i = 0; i < buttons.length; i++) {
                        var txt = buttons[i].innerText || "";
                        if (txt.includes("스펙") || txt.includes("더보기") || txt.includes("상세정보")) {
                            try {
                                buttons[i].click();
                            } catch(e) {}
                        }
                    }
                """)
                time.sleep(2)
                
                soup = BeautifulSoup(driver.page_source, "html.parser")
                
                # Get Product Name/Model Code
                model_code = url.split("/")[-1].split("?")[0].upper()
                
                try:
                    title_tag = soup.find("title")
                    if title_tag:
                        model_title = title_tag.get_text().split("|")[0].strip()
                    else:
                        title_elem = driver.find_element(By.CSS_SELECTOR, "h1, .product-name")
                        model_title = title_elem.text.strip().split("제품 공유하기")[0].split("공유하기")[0].split("모델명 복사")[0].strip()
                except Exception as e:
                    model_title = f"LG_{cat_name}_{model_code}"
                
                log(f"Model: {model_title} ({model_code})")
                
                # Get Specs
                dims = None
                
                # Check next sibling dd of dt containing "크기" or "치수"
                for dt in soup.find_all("dt"):
                    dt_text = dt.get_text().strip()
                    if any(kw in dt_text for kw in ["크기", "치수"]):
                        dd = dt.find_next_sibling("dd")
                        if dd:
                            dd_text = dd.get_text().strip()
                            dims = parse_dims(dd_text)
                            if dims:
                                log(f"Found dimensions in dt/dd ({dt_text}): {dims}")
                                break
                                
                # Fallback: Parse whole body text
                if not dims:
                    try:
                        body_text = driver.find_element(By.TAG_NAME, "body").text
                        dims = parse_dims(body_text)
                        if dims:
                            log(f"Found dimensions in body text: {dims}")
                    except Exception as e:
                        pass
                        
                # 3. Last fallback: Default generic sizes if completely missing
                if not dims:
                    log("Dimensions not found, using category defaults.")
                    if cat_name == "refrigerators":
                        dims = {"width": 912, "height": 1860, "depth": 918}
                    elif cat_name == "washers":
                        dims = {"width": 700, "height": 990, "depth": 770}
                    elif cat_name == "air-conditioners":
                        dims = {"width": 390, "height": 1820, "depth": 380}
                    else: # dryers
                        dims = {"width": 700, "height": 990, "depth": 800}
                
                # Locate Image gallery URLs
                img_elements = driver.find_elements(By.TAG_NAME, "img")
                gallery_urls = []
                for img in img_elements:
                    try:
                        src = img.get_attribute("src")
                        if src and "/images/" in src and "gallery" in src and ".jpg" in src.lower():
                            full_url = urljoin("https://www.lge.co.kr", src)
                            if full_url not in gallery_urls:
                                gallery_urls.append(full_url)
                    except Exception as e:
                        pass
                            
                # Fallback to general images containing model code or category
                if len(gallery_urls) < 2:
                    for img in img_elements:
                        try:
                            src = img.get_attribute("src")
                            if src and ("/images/" in src or "/upload/" in src) and ".jpg" in src.lower():
                                full_url = urljoin("https://www.lge.co.kr", src)
                                if full_url not in gallery_urls:
                                    gallery_urls.append(full_url)
                        except Exception as e:
                            pass
                                
                log(f"Found {len(gallery_urls)} candidate image URLs.")
                
                # Decide front and side images
                front_url, side_url = choose_images(gallery_urls)
                
                # Let's clean up urls (change small to medium for better assets)
                if front_url and "small" in front_url:
                    front_url = front_url.replace("small", "medium")
                if side_url and "small" in side_url:
                    side_url = side_url.replace("small", "medium")
                
                front_filename = f"{model_code}_front.jpg"
                side_filename = f"{model_code}_side.jpg"
                
                front_path = os.path.join(IMAGES_DIR, cat_name, front_filename)
                side_path = os.path.join(IMAGES_DIR, cat_name, side_filename)
                
                front_ok = False
                side_ok = False
                
                if front_url:
                    log(f"Downloading Front: {front_url}")
                    front_ok = download_file(front_url, front_path)
                if side_url:
                    log(f"Downloading Side: {side_url}")
                    side_ok = download_file(side_url, side_path)
                
                # Save metadata
                products_db[cat_name].append({
                    "name": model_title,
                    "code": model_code,
                    "width_mm": dims["width"],
                    "height_mm": dims["height"],
                    "depth_mm": dims["depth"],
                    "front_image": f"assets/images/{cat_name}/{front_filename}" if front_ok else None,
                    "side_image": f"assets/images/{cat_name}/{side_filename}" if side_ok else None
                })
                
        # Write metadata JSON
        os.makedirs(DATA_DIR, exist_ok=True)
        json_path = os.path.join(DATA_DIR, "products.json")
        with open(json_path, "w", encoding="utf-8") as f:
            json.dump(products_db, f, indent=2, ensure_ascii=False)
        log(f"Finished writing metadata database to {json_path}")
        
    finally:
        driver.quit()

if __name__ == "__main__":
    main()
