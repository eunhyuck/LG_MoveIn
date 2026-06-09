import os
import struct
import json

def inspect_materials(glb_path):
    print(f"=== Inspecting Materials in {glb_path} ===")
    with open(glb_path, 'rb') as f:
        f.read(12) # Header
        json_len = struct.unpack('<I', f.read(4))[0]
        f.read(4) # JSON Type
        json_bytes = f.read(json_len)
        data = json.loads(json_bytes.decode('utf-8'))
        
        materials = data.get('materials', [])
        textures = data.get('textures', [])
        images = data.get('images', [])
        
        print(f"Total Materials: {len(materials)}")
        print(f"Total Textures: {len(textures)}")
        print(f"Total Images: {len(images)}")
        
        for i, mat in enumerate(materials):
            name = mat.get('name', 'Unnamed')
            print(f"\nMaterial {i}: {name}")
            pbr = mat.get('pbrMetallicRoughness', {})
            base_tex = pbr.get('baseColorTexture')
            if base_tex:
                tex_idx = base_tex.get('index')
                tex = textures[tex_idx]
                img_idx = tex.get('source')
                img = images[img_idx]
                print(f"  -> Base Color Texture: index={tex_idx}, source image={img_idx} (name={img.get('name')})")
            
            normal_tex = mat.get('normalTexture')
            if normal_tex:
                tex_idx = normal_tex.get('index')
                tex = textures[tex_idx]
                img_idx = tex.get('source')
                img = images[img_idx]
                print(f"  -> Normal Texture: index={tex_idx}, source image={img_idx} (name={img.get('name')})")
                
            mr_tex = pbr.get('metallicRoughnessTexture')
            if mr_tex:
                tex_idx = mr_tex.get('index')
                tex = textures[tex_idx]
                img_idx = tex.get('source')
                img = images[img_idx]
                print(f"  -> Metallic Roughness Texture: index={tex_idx}, source image={img_idx} (name={img.get('name')})")

if __name__ == '__main__':
    inspect_materials('/Users/gunmandu/Desktop/LG MoveIn/lg_move_in/assets/models/washing_machine.glb')
