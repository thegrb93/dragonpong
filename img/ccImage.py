from PIL import Image
import sys

# Input image is any size 16 color indexed. Indeces 16 and higher will be transparent
# You should scale the original by 41/27 vertically to account for CC's taller pixels.
# The full screen resolution of my full 4x4 screen is 668x333 therefor input before scaling should be 668x506
filename = sys.argv[1]

with Image.open(filename) as im:
    width, height = im.size
    px = im.load()
    with open(filename.replace(".png",".txt"), 'w') as f:
        for y in range(height):
            for x in range(width):
                v = px[x,y]
                if v<16:
                    f.write("{:x}".format(v))
                else:
                    f.write(" ")
            f.write("\n")
