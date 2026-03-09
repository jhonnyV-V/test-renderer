package main

import "core:fmt"
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

		drawLine(&frameBuffer, a.x, a.y, b.x, b.y, &red)
		drawLine(&frameBuffer, b.x, b.y, c.x, c.y, &red)
		drawLine(&frameBuffer, c.x, c.y, a.x, a.y, &red)
	}

	for vec in obj.vertices {
		point := projectVector(vec, width, heigth)
		setColor(&frameBuffer, point.x, point.y, &white)
	}
}
