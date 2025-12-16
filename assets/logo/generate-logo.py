"""
Generate the RIGUP logo with circuit-board aesthetics and chromatic aberration.
Circuit Luminescence design philosophy applied to ASCII art branding.
"""

from PIL import Image, ImageDraw, ImageFont
import numpy as np
from pathlib import Path

# Canvas setup
width, height = 1600, 600
canvas = Image.new('RGB', (width, height), color=(15, 20, 35))
draw = ImageDraw.Draw(canvas, 'RGBA')

# Color palette
CYAN = (0, 255, 200)
MAGENTA = (255, 0, 150)
DARK_CYAN = (0, 150, 120)

# SCAN LINES throughout (CRT effect)
for y in range(0, height, 3):
    draw.line([(0, y), (width, y)], fill=(20, 25, 40), width=1)

# Load monospace font - larger for the ASCII art
font_file = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf"
if Path(font_file).exists():
    font_ascii = ImageFont.truetype(font_file, 48)
else:
    font_ascii = ImageFont.load_default()

ascii_art = [
    # "─────────────────────────────────",
    " ───    ╭─╮ ╶┬╴ ╭─╮   ╷ ╷ ┌┬╮    ─── ",
    " ──     ├┼╯ │ │ ├ ┬ : │││ ├─╯     ── ",
    " ───    ╵╰─ ╶┴╴ ╰─╯   ╰─╯ ╵      ─── ",
    # "─────────────────────────────────"
]

# Calculate dimensions to center the ASCII art block
# Measure the first line to get width
first_line_bbox = draw.textbbox((0, 0), ascii_art[0], font=font_ascii)
line_width = first_line_bbox[2] - first_line_bbox[0]
line_height = first_line_bbox[3] - first_line_bbox[1]

# Add spacing between lines for proper breathing room
line_spacing = int(line_height * 1)  # 80% of line height as gap
total_height = (line_height * 5) + (line_spacing * 1)

# Center horizontally and vertically
art_x = (width - line_width) // 2
art_y = (height - total_height) // 2

# Draw glow effect for ASCII
for line_idx, line in enumerate(ascii_art):
    y_pos = art_y + (line_idx * (line_height + line_spacing))
    for offset_x in [-2, -1, 0, 1, 2]:
        for offset_y in [-1, 0, 1]:
            if offset_x != 0 or offset_y != 0:
                draw.text((art_x + offset_x, y_pos + offset_y), line,
                         fill=(0, 80, 80, 100), font=font_ascii)

# Main ASCII art in bright cyan
for line_idx, line in enumerate(ascii_art):
    y_pos = art_y + (line_idx * (line_height + line_spacing))
    draw.text((art_x, y_pos), line, fill=CYAN, font=font_ascii)

# CIRCUIT FRAME - Outer border with connection points
left_x = 100
right_x = width - 100
top_y = 120
bottom_y = height - 120

# Vertical sides
draw.line([(left_x, top_y), (left_x, bottom_y)], fill=DARK_CYAN, width=3)
draw.line([(right_x, top_y), (right_x, bottom_y)], fill=DARK_CYAN, width=3)

# Add branch nodes on vertical sides
for y in range(top_y + 40, bottom_y, 60):
    # Left side branches
    draw.line([(left_x, y), (left_x - 20, y)], fill=CYAN, width=2)
    draw.ellipse([(left_x - 25, y - 4), (left_x - 15, y + 4)], fill=CYAN)

    # Right side branches
    draw.line([(right_x, y), (right_x + 20, y)], fill=CYAN, width=2)
    draw.ellipse([(right_x + 15, y - 4), (right_x + 25, y + 4)], fill=CYAN)

# TOP CIRCUIT TRACE
y_trace_top = 90
spacing = 60
x_positions = list(range(80, width - 80, spacing))
for i, x in enumerate(x_positions):
    draw.line([(x - spacing//2, y_trace_top), (x + spacing//2, y_trace_top)], fill=CYAN, width=2)
    if i % 3 == 0:
        draw.ellipse([(x - 5, y_trace_top - 5), (x + 5, y_trace_top + 5)], outline=CYAN, width=2)

# BOTTOM CIRCUIT TRACE
y_trace_bottom = height - 90
for i, x in enumerate(x_positions):
    draw.line([(x - spacing//2, y_trace_bottom), (x + spacing//2, y_trace_bottom)],
             fill=CYAN, width=2)
    if i % 3 == 0:
        draw.ellipse([(x - 5, y_trace_bottom - 5), (x + 5, y_trace_bottom + 5)],
                    outline=CYAN, width=2)

# Corner connections
draw.line([(left_x, 90), (left_x, top_y)], fill=DARK_CYAN, width=3)
draw.line([(right_x, 90), (right_x, top_y)], fill=DARK_CYAN, width=3)
draw.line([(left_x, bottom_y), (left_x, y_trace_bottom)], fill=DARK_CYAN, width=3)
draw.line([(right_x, bottom_y), (right_x, y_trace_bottom)], fill=DARK_CYAN, width=3)

# MAGENTA ACCENT NODES at corners
corner_nodes = [
    (left_x, 90), (right_x, 90),
    (left_x, y_trace_bottom), (right_x, y_trace_bottom)
]
for x, y in corner_nodes:
    draw.ellipse([(x - 10, y - 10), (x + 10, y + 10)], fill=MAGENTA)
    draw.ellipse([(x - 15, y - 15), (x + 15, y + 15)], outline=MAGENTA, width=2)

# ============================================================================
# CHROMATIC ABERRATION - Split RGB channels with offset
# ============================================================================
array = np.array(canvas)
aberration_amount = 5

# Shift red channel left, blue channel right
r_shifted = np.roll(array[:, :, 0], -aberration_amount, axis=1)
b_shifted = np.roll(array[:, :, 2], aberration_amount, axis=1)

# Reconstruct
result = array.copy()
result[:, :, 0] = r_shifted
result[:, :, 2] = b_shifted

canvas = Image.fromarray(result.astype('uint8'), 'RGB')
canvas.save('rigup-logo.jpg', 'JPEG', quality=95)
print("✓ RIGUP logo generated: rigup-logo.jpg")
print(f"  Dimensions: {width}x{height}")
