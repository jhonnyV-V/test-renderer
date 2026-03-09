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
	width := 800
	heigth := 800
	frameBuffer := initTGAImage(width, heigth, .RGB)

	drawTriangle(&frameBuffer, [2]int{7, 45}, [2]int{35, 100}, [2]int{45, 60}, &red)
	drawTriangle(&frameBuffer, [2]int{120, 35}, [2]int{90, 5}, [2]int{45, 110}, &white)
	drawTriangle(&frameBuffer, [2]int{115, 83}, [2]int{80, 90}, [2]int{85, 120}, &green)

	writeTgaFile(&frameBuffer, "framebuffer.tga", true, true)
}
