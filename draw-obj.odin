package main

import "core:fmt"
import "core:math/rand"
import "core:os"

drawObj :: proc() {
	width := 800
	heigth := 800
	filename := "./diablo3_pose/test.obj"

	fmt.println(os.args[1])

	frameBuffer := initTGAImage(width, heigth, .RGB)

	if os.args[1] != "" {
		filename = os.args[1]
	}

	obj := readObj(filename)

	for face in obj.faces {
		a := projectVector(obj.vertices[face[0]], width, heigth)
		b := projectVector(obj.vertices[face[1]], width, heigth)
		c := projectVector(obj.vertices[face[2]], width, heigth)

		color := TGAColor {
			bgra          = {
				u8(rand.uint32_max(256)),
				u8(rand.uint32_max(256)),
				u8(rand.uint32_max(256)),
				255,
			},
			bytesPerPixel = frameBuffer.bytesPerPixel,
		}
		drawTriangle(&frameBuffer, a, b, c, &color)
	}

	writeTgaFile(&frameBuffer, "framebuffer.tga", true, true)
}
