import os
from PIL import Image

def analyze_textures(dir_path):
    for f_name in sorted(os.listdir(dir_path)):
        if f_name.endswith(('.jpg', '.png')):
            p = os.path.join(dir_path, f_name)
            img = Image.open(p)
            
            # Get basic stats
            colors = img.getcolors(maxcolors=256)
            is_constant = colors is not None and len(colors) == 1
            
            print(f"File: {f_name}")
            print(f"  Size: {img.size}")
            print(f"  Format: {img.format}")
            print(f"  Mode: {img.mode}")
            print(f"  Is Constant/Solid Color: {is_constant}")
            if is_constant:
                print(f"    Color Value: {colors[0][1]}")
            else:
                # Calculate simple average color
                stat = img.resize((1, 1)).getpixel((0,0))
                print(f"  Average Color: {stat}")

if __name__ == '__main__':
    analyze_textures('/Users/gunmandu/Desktop/LG MoveIn/lg_move_in/scratch/extracted')
