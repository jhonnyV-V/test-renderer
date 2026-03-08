package main

import "core:fmt"

white := TGAColor {
	bgra = {255, 255, 255, 255},
}
blue := TGAColor {
	bgra = {255, 128, 64, 255},
}
green := TGAColor {
	bgra = {0, 255, 0, 255},
}
red := TGAColor {
	bgra = {0, 0, 255, 255},
}
yellow := TGAColor {
	bgra = {0, 200, 255, 255},
}

main :: proc() {
	// width := 64
	// heigth := 64
	//
	// frameBuffer := initTGAImage(width, heigth, .RGB)
	//
	// ax := 7
	// ay := 3
	// bx := 12
	// by := 37
	// cx := 62
	// cy := 53
	//
	// drawLine(&frameBuffer, ax, ay, bx, by, &blue)
	// drawLine(&frameBuffer, cx, cy, bx, by, &green)
	// drawLine(&frameBuffer, cx, cy, ax, ay, &yellow)
	// drawLine(&frameBuffer, ax, ay, cx, cy, &red)
	//
	// setColor(&frameBuffer, ax, ay, &white)
	// setColor(&frameBuffer, bx, by, &white)
	// setColor(&frameBuffer, cx, cy, &white)
	//
	// writeTgaFile(&frameBuffer, "framebuffer.tga", true, true)

	obj := readObj("./diablo3_pose/diablo3_pose.obj")

	fmt.printf("faces:%d, vertices:%d\n", len(obj.faces), len(obj.vertices))
}
