import struct
import json

def print_glb_json(glb_path):
    with open(glb_path, 'rb') as f:
        f.read(12) # Header
        json_len = struct.unpack('<I', f.read(4))[0]
        f.read(4) # JSON Type
        json_bytes = f.read(json_len)
        data = json.loads(json_bytes.decode('utf-8'))
        
        print("=== MATERIALS ===")
        print(json.dumps(data.get('materials', []), indent=2))
        
        print("\n=== TEXTURES ===")
        print(json.dumps(data.get('textures', []), indent=2))
        
        print("\n=== IMAGES ===")
        print(json.dumps(data.get('images', []), indent=2))

if __name__ == '__main__':
    print_glb_json('/Users/gunmandu/Desktop/LG MoveIn/lg_move_in/assets/models/washing_machine.glb')
