package main

import "core:fmt"
import "core:math/linalg"
import "core:math/rand"
import "core:os"

drawObj :: proc() {
	width := 800
	heigth := 800
	filename := "./diablo3_pose/test.obj"

	frameBuffer := initTGAImage(width, heigth, .RGB)
	zbuffer := make([dynamic]f32, heigth * width)

	if len(os.args) > 1 && os.args[1] != "" {
		filename = os.args[1]
	}

	obj := readObj(filename)

	eye := Vector3{-1, 0, 2} // camera position
	center := Vector3{0, 0, 0} // camera direction
	up := Vector3{0, 1, 0} // camera up vector

	lookat(eye, center, up) // build the ModelView   matrix
	perspective(linalg.length(eye - center)) // build the Perspective matrix
	viewport(width / 16, heigth / 16, width * 7 / 8, heigth * 7 / 8) // build the Viewport    matrix

	fmt.println("Perspective", Perspective)
	fmt.println("ModelView", ModelView)
	transformation := Perspective * ModelView
	fmt.println("transformation", transformation)

	for face in obj.faces {
		fa := obj.vertices[face[0]]
		fb := obj.vertices[face[1]]
		fc := obj.vertices[face[2]]
		triangle := [3]Vector4 {
			transformation * Vector4{fa.x, fa.y, fa.z, 1},
			transformation * Vector4{fb.x, fb.y, fb.z, 1},
			transformation * Vector4{fc.x, fc.y, fc.z, 1},
		}

		color := TGAColor {
			bgra          = {
				u8(rand.uint32_max(256)),
				u8(rand.uint32_max(256)),
				u8(rand.uint32_max(256)),
				255,
			},
			bytesPerPixel = frameBuffer.bytesPerPixel,
		}

		drawTriangle(&frameBuffer, zbuffer[:], triangle, &color)
	}

	writeTgaFile(&frameBuffer, "framebuffer.tga", true, true)
}
