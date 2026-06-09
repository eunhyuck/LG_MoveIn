import os
from PIL import Image, ImageChops

def trim_background(img_path, output_path):
    print(f"Trimming background from {img_path}...")
    img = Image.open(img_path)
    
    # Convert to RGB if needed
    if img.mode != 'RGB':
        img = img.convert('RGB')
        
    # Get background color (top-left pixel is usually background)
    bg_color = img.getpixel((0, 0))
    
    # Create background image to find difference
    bg = Image.new(img.mode, img.size, bg_color)
    diff = ImageChops.difference(img, bg)
    diff = ImageChops.add(diff, diff, 2.0, -100)
    
    # Bounding box of non-background area
    bbox = diff.getbbox()
    if bbox:
        cropped = img.crop(bbox)
        cropped.save(output_path, 'JPEG', quality=95)
        print(f"  Cropped from {img.size} to {cropped.size} and saved to {output_path}")
    else:
        # Fallback if no bbox found
        img.save(output_path, 'JPEG', quality=95)
        print(f"  No bbox found, saved original to {output_path}")

def process_all_images():
    base_dir = '/Users/gunmandu/Desktop/LG MoveIn/lg_move_in/assets/images'
    for category in os.listdir(base_dir):
        cat_path = os.path.join(base_dir, category)
        if not os.path.isdir(cat_path):
            continue
            
        for f_name in os.listdir(cat_path):
            if f_name.endswith(('_front.jpg', '_side.jpg')) and not f_name.startswith('cropped_'):
                img_path = os.path.join(cat_path, f_name)
                output_name = 'cropped_' + f_name
                output_path = os.path.join(cat_path, output_name)
                trim_background(img_path, output_path)

if __name__ == '__main__':
    process_all_images()
