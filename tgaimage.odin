package main

import "core:fmt"
import "core:io"
import "core:mem"
import "core:mem/virtual"
import "core:os"

TGAHeader :: struct {
	idlength:        u8,
	colormaptype:    u8,
	datatypecode:    u8,
	colormaporigin:  u16,
	colormaplength:  u16,
	colormapdepth:   u8,
	x_origin:        u16,
	y_origin:        u16,
	width:           u16,
	height:          u16,
	bitsperpixel:    u8,
	imagedescriptor: u8,
}
TGAColor :: struct {
	bgra:    [4]u8,
	bytespp: u8,
}

TGAFormat :: enum u8 {
	GRAYSCALE = 1,
	RGB       = 3,
	RGBA      = 4,
}

TGAImage :: struct {
	width, height: int,
	bpp:           u8,
	data:          [dynamic]u8,
}

initTGAImage :: proc(w, h: int, bpp: TGAFormat) -> TGAImage {
	total_bytes := int(w) * int(h) * int(bpp)

	img := TGAImage {
		width  = w,
		height = h,
		bpp    = u8(bpp),
		data   = make([dynamic]u8, total_bytes),
	}

	return img
}

readTgaFile :: proc(filename: string) {}

writeTgaFile :: proc(filename: string, vflip: bool, rle: bool) {}


getColor :: proc(img: ^TGAImage, x, y: int) -> TGAColor {
	if len(img.data) == 0 || x < 0 || y < 0 || x >= img.width || y >= img.height {
		return TGAColor{}
	}

	color: TGAColor = {
		bgra    = {0, 0, 0, 0},
		bytespp = img.bpp,
	}

	offset := (x + y * img.width) * int(img.bpp)

	for i in 0 ..< img.bpp {
		color.bgra[i] = img.data[offset + int(i)]
	}

	return color
}

setColor :: proc(img: ^TGAImage, x, y: int, color: ^TGAColor) {
	if len(img.data) == 0 || x < 0 || y < 0 || x >= img.width || y >= img.height {
		return
	}

	offset := (x + y * img.width) * int(img.bpp)
	mem.copy(&img.data[offset], &color.bgra[0], int(img.bpp))
}

loadRleData :: proc(img: ^TGAImage, file: io.Stream) -> bool {
	numberOfPixels := int(img.width) * int(img.height)
	currentPixel := 0
	currentByte := 0

	totalBytes := numberOfPixels * int(img.bpp)
	resize(&img.data, totalBytes)

	arena: virtual.Arena
	_ = virtual.arena_init_static(&arena, uint(totalBytes * 4))
	arena_allocator := virtual.arena_allocator(&arena)
	defer free_all(arena_allocator)

	colorBuffer := make([]u8, int(img.bpp), arena_allocator)

	for currentPixel < numberOfPixels {
		headerBuff: [1]u8
		_, err := io.read(file, headerBuff[:])
		if err != nil {
			fmt.eprintln("Error: An error occurred while reading the chunk header")
			return false
		}

		chunkHeader := headerBuff[0]

		if chunkHeader < 128 {
			//non compress packet
			chunkHeader += 1
			for _ in 0 ..< chunkHeader {
				if _, readError := io.read(file, colorBuffer); readError != nil {
					fmt.eprintln("Error: An error occurred while reading the pixel data")
					return false
				}

				for t in 0 ..< int(img.bpp) {
					img.data[currentByte] = colorBuffer[t]
				}

				currentPixel += 1
				if currentPixel > numberOfPixels {
					fmt.eprintln("Error: Too many pixels read")
					return false
				}
			}
		} else {
			//rle packet
			chunkHeader -= 127
			if _, readError := io.read(file, colorBuffer); readError != nil {
				fmt.eprintln("Error: An error occurred while reading the pixel data")
				return false
			}

			for i in 0 ..< chunkHeader {
				for t in 0 ..< img.bpp {
					img.data[currentByte] = colorBuffer[t]
					currentByte += 1
				}
				currentPixel += 1
				if currentPixel > numberOfPixels {
					fmt.eprintln("Error: Too many pixels read")
					return false
				}
			}
		}
	}

	return true
}

unloadRleData :: proc(img: ^TGAImage, file: io.Stream) -> bool {
	maxChunkLen :: 128
	numberOfPixels := int(img.width) * int(img.height)
	currentPixel := 0
	for currentPixel < numberOfPixels {
		chunkStart := currentPixel * int(img.bpp)
		currentByte := currentPixel * int(img.bpp)
		runLen := 1
		isRawBytes := true

		for currentPixel < numberOfPixels && runLen < maxChunkLen {
			isSequenceEqual := true

			for t in 0 ..< int(img.bpp) {
				if img.data[currentByte + t] != img.data[currentByte + t + int(img.bpp)] {
					isSequenceEqual = false
					break
				}
			}

			currentByte += int(img.bpp)
			if runLen == 1 {
				isRawBytes = !isSequenceEqual
			}

			if isRawBytes && isSequenceEqual {
				runLen -= 1
				break
			}

			if !isRawBytes && !isSequenceEqual {
				break
			}

			runLen += 1
		}

		currentPixel += runLen

		header := u8(isRawBytes ? runLen - 1 : runLen + 127)
		if _, err := io.write(file, {header}); err != nil {
			return false
		}

		bytesToWrite := isRawBytes ? runLen * int(img.bpp) : int(img.bpp)
		if _, err := io.write(file, img.data[chunkStart:chunkStart + bytesToWrite]); err != nil {
			return false
		}
	}

	return true
}

flipHorizontally :: proc(img: ^TGAImage) {
	for i := 0; i < img.width / 2; i += 1 {
		for j := 0; j < img.height; j += 1 {
			for b: u8 = 0; b < img.bpp; b += 1 {
				index1 := (i + j * img.width) * int(img.bpp) + int(b)
				index2 := (img.width - 1 - i + j * img.width) * int(img.bpp) + int(b)

				img.data[index1], img.data[index2] = img.data[index2], img.data[index1]
			}
		}
	}
}

flipVertically :: proc(img: ^TGAImage) {
	for i := 0; i < img.width; i += 1 {
		for j := 0; j < img.height / 2; j += 1 {
			for b: u8 = 0; b < img.bpp; b += 1 {
				index1 := (i + j * img.width) * int(img.bpp) + int(b)
				index2 := (i + (img.height - 1 - j) * img.width) * int(img.bpp) + int(b)

				img.data[index1], img.data[index2] = img.data[index2], img.data[index1]
			}
		}
	}
}
