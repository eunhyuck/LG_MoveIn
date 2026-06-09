import sys
import struct
import json

def inspect_glb(filepath):
    print(f"=== Inspecting {filepath} ===")
    with open(filepath, 'rb') as f:
        # Read GLB header
        magic = f.read(4)
        if magic != b'glTF':
            print("Not a valid GLB file")
            return
        version = struct.unpack('<I', f.read(4))[0]
        length = struct.unpack('<I', f.read(4))[0]
        
        # Read JSON chunk header
        chunk_length = struct.unpack('<I', f.read(4))[0]
        chunk_type = f.read(4)
        if chunk_type != b'JSON':
            print("First chunk is not JSON")
            return
        
        # Read JSON chunk content
        json_data = f.read(chunk_length).decode('utf-8')
        data = json.loads(json_data)
        
        # Print nodes/meshes info
        nodes = data.get('nodes', [])
        meshes = data.get('meshes', [])
        materials = data.get('materials', [])
        
        print(f"Total Nodes: {len(nodes)}")
        print(f"Total Meshes: {len(meshes)}")
        print(f"Total Materials: {len(materials)}")
        
        print("\n--- Materials ---")
        for i, mat in enumerate(materials):
            print(f"Material {i}: name={mat.get('name')}, alphaMode={mat.get('alphaMode')}, pbrMetallicRoughness={mat.get('pbrMetallicRoughness')}")
            
        print("\n--- Meshes and their Primitives/Materials ---")
        for i, mesh in enumerate(meshes[:50]): # Show first 50 meshes
            name = mesh.get('name', 'Unnamed')
            prims = mesh.get('primitives', [])
            mat_indices = [p.get('material') for p in prims if p.get('material') is not None]
            print(f"Mesh {i}: name={name}, materials={mat_indices}")

if __name__ == '__main__':
    inspect_glb('/Users/gunmandu/Desktop/LG MoveIn/lg_move_in/assets/models/washing_machine.glb')
    inspect_glb('/Users/gunmandu/Desktop/LG MoveIn/lg_move_in/assets/models/washer_dryer_machine.glb')
