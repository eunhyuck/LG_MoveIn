import os
import sys
import json
import base64
import requests

json_path = "/Users/baenaongunmandu/Desktop/LG MoveIn/lg_move_in/assets/data/products.json"
url = "http://127.0.0.1:1234/v1/chat/completions"

def log(msg):
    print(f"[*] {msg}")
    sys.stdout.flush()

def encode_image(filepath):
    if not os.path.exists(filepath):
        return None
    with open(filepath, "rb") as f:
        return base64.b64encode(f.read()).decode("utf-8")

def query_vlm(image_base64, category, model_code):
    prompt = f"""You are analyzing a photo of an LG {category} (Model: {model_code}).
Identify its structural and visual design elements.
You must return ONLY a valid JSON string (no markdown, no surrounding text, no formatting other than plain JSON) with the following keys:
{{
  "primary_color_hex": "primary color hex code, default to grey if unsure",
  "secondary_color_hex": "secondary or accent color hex code, default to grey if unsure",
  "layout_type": "4-door" or "2-door-vertical" or "2-door-horizontal" or "single-door" or "front-load" or "top-load" or "stand" or "wall-mount",
  "panel_count": integer (number of visible panel divisions/doors),
  "has_display_screen": boolean (true if it has a display screen, touch panel, or round window indicator)
}}"""

    payload = {
        "model": "zai-org/glm-4.6v-flash",
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{image_base64}"}}
                ]
            }
        ],
        "temperature": 0.1
    }

    try:
        response = requests.post(url, json=payload, timeout=30)
        if response.status_code == 200:
            res_content = response.json()["choices"][0]["message"]["content"].strip()
            # Clean potential markdown packaging
            if res_content.startswith("```json"):
                res_content = res_content.split("```json")[1].split("```")[0].strip()
            elif res_content.startswith("```"):
                res_content = res_content.split("```")[1].split("```")[0].strip()
            return json.loads(res_content)
    except Exception as e:
        log(f"Error querying VLM for {model_code}: {e}")
    return None

def main():
    if not os.path.exists(json_path):
        log(f"Error: products.json not found at {json_path}")
        return

    with open(json_path, "r", encoding="utf-8") as f:
        db = json.load(f)

    updated = False
    for cat_name, products in db.items():
        log(f"\nProcessing category: {cat_name}")
        for p in products:
            code = p["code"]
            front_rel = p.get("front_image")
            if not front_rel:
                continue
            
            front_abs = os.path.join("/Users/baenaongunmandu/Desktop/LG MoveIn/lg_move_in", front_rel)
            log(f"Analyzing {code} via VLM ({front_abs})...")
            
            img_b64 = encode_image(front_abs)
            if not img_b64:
                log(f"Image not found: {front_abs}")
                continue
                
            specs = query_vlm(img_b64, cat_name, code)
            if specs:
                log(f"Result for {code}: {specs}")
                p["visual_specs"] = specs
                updated = True
            else:
                log(f"Failed to get visual specs for {code}")
                # Set default specs to prevent crash
                p["visual_specs"] = {
                    "primary_color_hex": "#D2D2D2",
                    "secondary_color_hex": "#5F5D58",
                    "layout_type": "single-door" if cat_name != "refrigerators" else "4-door",
                    "panel_count": 4 if cat_name == "refrigerators" else 1,
                    "has_display_screen": False
                }
                updated = True

    if updated:
        with open(json_path, "w", encoding="utf-8") as f:
            json.dump(db, f, indent=2, ensure_ascii=False)
        log("Successfully updated products.json with VLM visual specs!")

if __name__ == "__main__":
    main()
