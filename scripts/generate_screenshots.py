
import os
import sys
from PIL import Image, ImageOps, ImageDraw, ImageFont

# Configuration
SCREENSHOTS_DIR = "screenshots"
OUTPUT_DIR = "screenshots/generated"
# Ensure output directory exists
if not os.path.exists(OUTPUT_DIR):
    os.makedirs(OUTPUT_DIR)

# Colors
BACKGROUND_COLOR = "#000000" # Black background per user design style
TEXT_COLOR = "#FFFFFF"
SUBTITLE_COLOR = "#A1A1AA"

# Fonts
# Try to find a nice system font
POSSIBLE_FONTS = [
    "/System/Library/Fonts/SFNS.ttf",
    "/System/Library/Fonts/SFNSDisplay.ttf",
    "/System/Library/Fonts/HelveticaNeue.ttc",
    "/Library/Fonts/Arial.ttf"
]

def get_font(size):
    for font_path in POSSIBLE_FONTS:
        if os.path.exists(font_path):
            try:
                print(f"Using font: {font_path}")
                return ImageFont.truetype(font_path, size)
            except Exception as e:
                print(f"Failed to load {font_path}: {e}")
                continue
    print("Using default font")
    return ImageFont.load_default()

# Target Dimensions
# iPhone 6.5" / 6.7" (1284 x 2778)
IOS_TARGET_SIZE = (1284, 2778)

# Config Content
# Mapping raw filenames to Copy
SCREENSHOT_CONFIG = [
    {
        "filename": "scan.PNG",
        "title": "Is This Vegan?",
        "subtitle": "Instantly check ingredients with AI.",
        "platform": "ios"
    },
    {
        "filename": "analysing.PNG", # Note spelling from directory list
        "title": "Smart Analysis",
        "subtitle": "Powered by Gemini for accuracy.",
        "platform": "ios"
    },
     {
        "filename": "result_safe.PNG",
        "title": "Eat with Confidence",
        "subtitle": "Clear 'Vegan Friendly' confirmation.",
        "platform": "ios"
    },
    {
        "filename": "result risk.PNG", # Note space from directory list
        "title": "Spot Hidden Nasties",
        "subtitle": "Detects non-vegan additives instantly.",
        "platform": "ios"
    }
]

def process_screenshot(config):
    filename = config["filename"]
    input_path = os.path.join(SCREENSHOTS_DIR, filename)
    
    if not os.path.exists(input_path):
        print(f"Skipping {filename}: File not found.")
        return

    try:
        img = Image.open(input_path)
    except Exception as e:
        print(f"Error opening {filename}: {e}")
        return

    # Canvas
    target_width, target_height = IOS_TARGET_SIZE
    canvas = Image.new("RGB", (target_width, target_height), BACKGROUND_COLOR)
    draw = ImageDraw.Draw(canvas)

    # Text Settings
    title_size = 110
    subtitle_size = 55
    text_padding_top = 180
    
    title_font = get_font(title_size)
    subtitle_font = get_font(subtitle_size)

    # Draw Title
    title_text = config["title"]
    # Calculate text position to center it
    # Anchor 'mt' = Middle Top
    center_x = target_width // 2
    
    draw.text((center_x, text_padding_top), title_text, font=title_font, fill=TEXT_COLOR, anchor="mt")
    
    # Draw Subtitle
    subtitle_text = config["subtitle"]
    subtitle_y = text_padding_top + title_size + 20
    draw.text((center_x, subtitle_y), subtitle_text, font=subtitle_font, fill=SUBTITLE_COLOR, anchor="mt")

    # Image Placement
    # We want the image to start below the text and possibly be cut off at the bottom or fit nicely
    # Let's add some padding below subtitle
    image_y_start = subtitle_y + subtitle_size + 120
    
    # Resize image to fit width with some padding
    # Let's say 85% width
    target_img_width = int(target_width * 0.85)
    scale_factor = target_img_width / img.width
    target_img_height = int(img.height * scale_factor)
    
    resized_img = img.resize((target_img_width, target_img_height), Image.Resampling.LANCZOS)
    
    # Apply a border or shadow?
    # Simple rounded corners mask could be nice but let's stick to simple composition first
    # Or just a simple border?
    
    # Centered X
    image_x = (target_width - target_img_width) // 2
    
    canvas.paste(resized_img, (image_x, image_y_start))
    
    # Save
    output_filename = f"AppStore_{filename.replace(' ', '_')}"
    output_path = os.path.join(OUTPUT_DIR, output_filename)
    canvas.save(output_path)
    print(f"Generated {output_path}")

def main():
    print("Starting screenshot generation...")
    for config in SCREENSHOT_CONFIG:
        process_screenshot(config)
    print("Done.")

if __name__ == "__main__":
    main()
