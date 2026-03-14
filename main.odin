package main

import "core:fmt"
import "core:os"

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
	// width := 800
	// heigth := 800
	// frameBuffer := initTGAImage(width, heigth, .RGB)
	//
	// drawTriangle(&frameBuffer, [3]int{17, 4, 13}, [3]int{55, 39, 128}, [3]int{23, 59, 255}, &red)
	//
	// writeTgaFile(&frameBuffer, "framebuffer.tga", true, true)

	drawObj()
}
