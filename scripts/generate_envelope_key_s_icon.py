from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "icons"
OUT.mkdir(exist_ok=True)
SCALE = 4
W = H = 256
img = Image.new("RGBA", (W * SCALE, H * SCALE), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
S = SCALE

def sc(points):
    return [(int(x*S), int(y*S)) for x, y in points]

def ellipse(box, fill, outline=None, width=1):
    box = tuple(int(v*S) for v in box)
    d.ellipse(box, fill=fill, outline=outline, width=width*S if outline else 1)

def rounded_rect(box, radius, fill, outline=None, width=1):
    box = tuple(int(v*S) for v in box)
    d.rounded_rectangle(box, radius=radius*S, fill=fill, outline=outline, width=width*S if outline else 1)

def line(points, fill, width, joint="curve"):
    d.line(sc(points), fill=fill, width=width*S, joint=joint)

# Soft red S symbol in the background, inspired by the supplied red S reference.
s_points = [(154, 35), (112, 47), (72, 64), (55, 82), (54, 96), (68, 107), (91, 116), (103, 130), (101, 147), (82, 166), (42, 190)]
line(s_points, (217, 0, 0, 255), 18)
line([(40, 194), (78, 183), (113, 174), (149, 167)], (217, 0, 0, 255), 6)

# Drop shadow layer for the envelope.
shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
sd = ImageDraw.Draw(shadow)
sd.rounded_rectangle(tuple(int(v*S) for v in (47, 73, 201, 182)), radius=16*S, fill=(0, 0, 0, 70))
shadow = shadow.filter(ImageFilter.GaussianBlur(6*S))
img.alpha_composite(shadow, (0, 7*S))
d = ImageDraw.Draw(img)

# Envelope body and paper flap.
rounded_rect((47, 73, 201, 182), 16, (253, 204, 91, 255), (195, 135, 39, 255), 5)
d.polygon(sc([(58, 81), (124, 135), (190, 81)]), fill=(248, 250, 253, 255))
line([(58, 81), (124, 135), (190, 81)], (211, 216, 222, 255), 5)
line([(55, 174), (103, 126)], (207, 154, 58, 255), 5)
line([(194, 174), (145, 126)], (207, 154, 58, 255), 5)
d.polygon(sc([(58, 176), (113, 124), (124, 119), (135, 124), (190, 176)]), fill=(255, 211, 106, 255))
line([(58, 176), (113, 124), (124, 119), (135, 124), (190, 176)], (195, 135, 39, 255), 5)

# Key composed on a separate layer and rotated like the Windows shell reference.
key = Image.new("RGBA", img.size, (0, 0, 0, 0))
kd = ImageDraw.Draw(key)
def kellipse(box, fill, outline=None, width=1):
    kd.ellipse(tuple(int(v*S) for v in box), fill=fill, outline=outline, width=width*S if outline else 1)
def krect(box, radius, fill, outline=None, width=1):
    kd.rounded_rectangle(tuple(int(v*S) for v in box), radius=radius*S, fill=fill, outline=outline, width=width*S if outline else 1)

kellipse((78, 61, 128, 111), (178, 187, 196, 255), (96, 107, 116, 255), 4)
kellipse((91, 74, 115, 98), (255, 248, 223, 255), (137, 148, 158, 255), 4)
krect((126, 78, 198, 94), 7, (217, 160, 52, 255), (153, 103, 15, 255), 4)
krect((178, 91, 192, 115), 3, (217, 160, 52, 255), (153, 103, 15, 255), 4)
krect((194, 91, 207, 109), 3, (217, 160, 52, 255), (153, 103, 15, 255), 4)
kellipse((88, 71, 102, 85), (248, 251, 255, 150))
key = key.rotate(-36, resample=Image.Resampling.BICUBIC, center=(142*S, 90*S))
key_shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
key_shadow.alpha_composite(key)
# Convert colored key into a soft shadow mask.
alpha = key_shadow.getchannel("A").filter(ImageFilter.GaussianBlur(4*S))
sh = Image.new("RGBA", img.size, (0, 0, 0, 85))
sh.putalpha(alpha)
img.alpha_composite(sh, (0, 5*S))
img.alpha_composite(key)

final = img.resize((W, H), Image.Resampling.LANCZOS)
final.save(OUT / "envelope-key-s.png")
# Windows ICO with several shell-friendly sizes.
final.save(OUT / "envelope-key-s.ico", sizes=[(256, 256), (128, 128), (64, 64), (48, 48), (32, 32), (16, 16)])
print(OUT / "envelope-key-s.png")
print(OUT / "envelope-key-s.ico")
