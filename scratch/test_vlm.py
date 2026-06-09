import requests
import base64
import json

# Let's read a sample crawled image
image_path = "/Users/baenaongunmandu/Desktop/LG MoveIn/lg_move_in/assets/images/refrigerators/M876GBB231_front.jpg"

try:
    with open(image_path, "rb") as f:
        img_base64 = base64.b64encode(f.read()).decode("utf-8")

    payload = {
        "model": "zai-org/glm-4.6v-flash",
        "messages": [
            {
                "role": "user",
                "content": [
                    {
                        "type": "text",
                        "text": "Analyze this appliance image and return its characteristics. You must output ONLY a valid JSON string (no markdown block, no explanation) with these keys:\n"
                               "{\n"
                               "  \"primary_color_hex\": \"#HEXCODE\",\n"
                               "  \"secondary_color_hex\": \"#HEXCODE\",\n"
                               "  \"door_layout_type\": \"4-door\" or \"2-door-vertical\" or \"2-door-horizontal\" or \"single-door\" or \"front-load\" or \"top-load\",\n"
                               "  \"panel_count\": 1, 2, 3, or 4,\n"
                               "  \"has_display_screen\": true or false\n"
                               "}"
                    },
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": f"data:image/jpeg;base64,{img_base64}"
                        }
                    }
                ]
            }
        ],
        "temperature": 0.1
    }

    url = "http://127.0.0.1:1234/v1/chat/completions"
    print("Sending request to local VLM...")
    response = requests.post(url, json=payload, timeout=30)
    if response.status_code == 200:
        result = response.json()
        print("Success! Response text:")
        print(result["choices"][0]["message"]["content"])
    else:
        print(f"Failed with status: {response.status_code} - {response.text}")
except Exception as e:
    print(f"Error: {e}")
