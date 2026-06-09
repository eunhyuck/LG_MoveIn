import requests

url = "http://127.0.0.1:1234/v1/models"
try:
    print(f"Connecting to local LLM at {url}...")
    response = requests.get(url, timeout=5)
    if response.status_code == 200:
        print("Success! Models available:")
        print(response.json())
    else:
        print(f"Failed with status: {response.status_code}")
except Exception as e:
    print(f"Error connecting: {e}")
