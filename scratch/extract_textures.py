import os
import struct
import json

def extract_textures(glb_path, output_dir):
    print(f"Extracting textures from {glb_path}...")
    os.makedirs(output_dir, exist_ok=True)
    
    with open(glb_path, 'rb') as f:
        magic = f.read(4)
        if magic != b'glTF':
            print("Invalid GLB")
            return
        version = struct.unpack('<I', f.read(4))[0]
        length = struct.unpack('<I', f.read(4))[0]
        
        # JSON Chunk
        json_len = struct.unpack('<I', f.read(4))[0]
        json_type = f.read(4)
        json_bytes = f.read(json_len)
        data = json.loads(json_bytes.decode('utf-8'))
        
        # BIN Chunk
        bin_len = struct.unpack('<I', f.read(4))[0]
        bin_type = f.read(4)
        bin_start = f.tell()
        
        images = data.get('images', [])
        buffer_views = data.get('bufferViews', [])
        
        for i, img in enumerate(images):
            name = img.get('name', f'texture_{i}')
            mime_type = img.get('mimeType', 'image/png')
            ext = '.jpg' if mime_type == 'image/jpeg' else '.png'
            
            bv_idx = img.get('bufferView')
            if bv_idx is not None:
                bv = buffer_views[bv_idx]
                offset = bv.get('byteOffset', 0)
                length = bv.get('byteLength')
                
                f.seek(bin_start + offset)
                img_data = f.read(length)
                
                out_path = os.path.join(output_dir, f"{name}{ext}")
                with open(out_path, 'wb') as out_f:
                    out_f.write(img_data)
                print(f"Extracted {out_path} ({len(img_data)} bytes)")

if __name__ == '__main__':
    extract_textures('/Users/gunmandu/Desktop/LG MoveIn/lg_move_in/assets/models/washing_machine.glb', '/Users/gunmandu/Desktop/LG MoveIn/lg_move_in/scratch/extracted')
