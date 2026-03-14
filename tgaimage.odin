package main

import "core:fmt"
import "core:io"
import "core:math"
import "core:mem"
import "core:os"

TGAHeader :: struct #packed {
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
	bgra:          [4]u8,
	bytesPerPixel: u8,
}

TGAFormat :: enum u8 {
	GRAYSCALE = 1,
	RGB       = 3,
	RGBA      = 4,
}

TGAImage :: struct {
	width, height: int,
	bytesPerPixel: u8,
	data:          [dynamic]u8,
}

initTGAImage :: proc(w, h: int, bytesPerPixel: TGAFormat) -> TGAImage {
	total_bytes := int(w) * int(h) * int(bytesPerPixel)

	img := TGAImage {
		width         = w,
		height        = h,
		bytesPerPixel = u8(bytesPerPixel),
		data          = make([dynamic]u8, total_bytes),
	}

	return img
}

readTgaFile :: proc(img: ^TGAImage, filename: string) -> bool {
	file, err := os.open(filename, os.O_RDONLY)
	if err != nil {
		fmt.eprintln("Can't open file:", filename)
		return false
	}
	defer os.close(file)
	stream := os.to_stream(file)

	header: TGAHeader
	header_bytes := mem.ptr_to_bytes(&header)
	if _, read_err := io.read(stream, header_bytes); read_err != nil {
		fmt.eprintln("An error occurred while reading the header")
		return false
	}

	img.width = int(header.width)
	img.height = int(header.height)
	img.bytesPerPixel = header.bitsperpixel >> 3

	if img.width <= 0 {
		fmt.eprintln("Bad width value")
		return false
	}

	if img.height <= 0 {
		fmt.eprintln("Bad height value")
		return false
	}

	if (img.bytesPerPixel != 1 && img.bytesPerPixel != 3 && img.bytesPerPixel != 4) {
		fmt.eprintln("Bad bpp value")
		return false
	}

	nBytes := int(img.bytesPerPixel) * int(img.width) * int(img.height)
	resize(&img.data, nBytes)

	if header.datatypecode == 2 || header.datatypecode == 3 {
		if _, read_err := io.read(stream, img.data[:]); read_err != nil {
			fmt.eprintln("An error occurred while reading the raw data")
			return false
		}
	} else if header.datatypecode == 10 || header.datatypecode == 11 {
		// 10: RLE RGB, 11: RLE Grayscale
		if !loadRleData(img, stream) {
			fmt.eprintln("An error occurred while reading the RLE data")
			return false
		}
	} else {
		fmt.eprintf("Unknown file format: %d\n", header.datatypecode)
		return false
	}

	// TGA Image Descriptor byte:
	// bit 4: horizontal flip (right-to-left)
	// bit 5: vertical flip (top-to-bottom)
	if (header.imagedescriptor & 0x20) == 0 {
		flipVertically(img)
	}
	if (header.imagedescriptor & 0x10) != 0 {
		flipHorizontally(img)
	}

	fmt.eprintf("read %dx%d/%d\n", img.width, img.height, img.bytesPerPixel * 8)
	return true
}

writeTgaFile :: proc(img: ^TGAImage, filename: string, vflip: bool, rle: bool) -> bool {
	DEVELOPER_AREA_REF := [4]u8{0, 0, 0, 0}
	EXTENSION_AREA_REF := [4]u8{0, 0, 0, 0}
	// The signature "TRUEVISION-XFILE.\0"
	FOOTER := "TRUEVISION-XFILE.\x00"

	file, err := os.open(filename, os.O_WRONLY | os.O_CREATE | os.O_TRUNC)
	if err != nil {
		fmt.eprintln("Can't open file:", filename)
		return false
	}
	defer os.close(file)
	stream := os.to_stream(file)

	header := TGAHeader {
		bitsperpixel    = img.bytesPerPixel << 3,
		width           = u16(img.width),
		height          = u16(img.height),
		imagedescriptor = vflip ? 0x00 : 0x20, // top-left or bottom-left origin
	}

	if img.bytesPerPixel == u8(TGAFormat.GRAYSCALE) {
		header.datatypecode = (rle ? 11 : 3)
	} else {
		header.datatypecode = (rle ? 10 : 2)
	}

	header_bytes := mem.ptr_to_bytes(&header)
	if _, err = io.write(stream, header_bytes); err != nil {
		fmt.eprintln("Can't dump the tga file")
		return false
	}

	if !rle {
		if _, err = io.write(stream, img.data[:]); err != nil {
			fmt.eprintln("Can't dump the tga file")
			return false
		}
	} else {
		if !unloadRleData(img, stream) {
			fmt.eprintln("Can't dump the tga file")
			return false
		}
	}

	if _, err = io.write(stream, DEVELOPER_AREA_REF[:]); err != nil {
		fmt.eprintln("Can't dump the tga file")
		return false
	}
	if _, err = io.write(stream, EXTENSION_AREA_REF[:]); err != nil {
		fmt.eprintln("Can't dump the tga file")
		return false
	}
	if _, err = io.write(stream, transmute([]u8)FOOTER); err != nil {
		fmt.eprintln("Can't dump the tga file")
		return false
	}

	return true
}


getColor :: proc(img: ^TGAImage, x, y: int) -> TGAColor {
	if len(img.data) == 0 || x < 0 || y < 0 || x >= img.width || y >= img.height {
		return TGAColor{}
	}

	color: TGAColor = {
		bgra          = {0, 0, 0, 0},
		bytesPerPixel = img.bytesPerPixel,
	}

	offset := (x + y * img.width) * int(img.bytesPerPixel)

	mem.copy(&color.bgra, &img.data[offset], int(img.bytesPerPixel))

	return color
}

setColor :: proc(img: ^TGAImage, x, y: int, color: ^TGAColor) {
	if len(img.data) == 0 || x < 0 || y < 0 || x >= img.width || y >= img.height {
		return
	}

	offset := (x + y * img.width) * int(img.bytesPerPixel)
	mem.copy(&img.data[offset], &color.bgra[0], int(img.bytesPerPixel))
}

loadRleData :: proc(img: ^TGAImage, file: io.Stream) -> bool {
	numberOfPixels := int(img.width) * int(img.height)
	currentPixel := 0
	currentByte := 0

	totalBytes := numberOfPixels * int(img.bytesPerPixel)
	resize(&img.data, totalBytes)

	colorBuffer := [4]u8{}

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
				if _, readError := io.read(file, colorBuffer[:img.bytesPerPixel]);
				   readError != nil {
					fmt.eprintln("Error: An error occurred while reading the pixel data")
					return false
				}

				mem.copy(&img.data[currentByte], &colorBuffer, int(img.bytesPerPixel))
				currentByte += int(img.bytesPerPixel)

				currentPixel += 1
				if currentPixel > numberOfPixels {
					fmt.eprintln("Error: Too many pixels read")
					return false
				}
			}
		} else {
			//rle packet
			chunkHeader -= 127
			if _, readError := io.read(file, colorBuffer[:img.bytesPerPixel]); readError != nil {
				fmt.eprintln("Error: An error occurred while reading the pixel data")
				return false
			}

			for i in 0 ..< chunkHeader {
				mem.copy(&img.data[currentByte], &colorBuffer, int(img.bytesPerPixel))
				currentByte += int(img.bytesPerPixel)

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
		chunkStart := currentPixel * int(img.bytesPerPixel)
		currentByte := currentPixel * int(img.bytesPerPixel)
		runLen := 1
		isRawBytes := true

		for (currentPixel + runLen) < numberOfPixels && runLen < maxChunkLen {
			isSequenceEqual := true

			for t := 0; isSequenceEqual && (t < int(img.bytesPerPixel)); t += 1 {
				isSequenceEqual =
					img.data[currentByte + t] == img.data[currentByte + t + int(img.bytesPerPixel)]
			}

			currentByte += int(img.bytesPerPixel)
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

		bytesToWrite := isRawBytes ? runLen * int(img.bytesPerPixel) : int(img.bytesPerPixel)
		if _, err := io.write(file, img.data[chunkStart:chunkStart + bytesToWrite]); err != nil {
			return false
		}
	}

	return true
}

flipHorizontally :: proc(img: ^TGAImage) {
	for col := 0; col < img.width / 2; col += 1 {
		for row := 0; row < img.height; row += 1 {
			for b: u8 = 0; b < img.bytesPerPixel; b += 1 {
				index1 := (col + row * img.width) * int(img.bytesPerPixel) + int(b)
				index2 := (img.width - 1 - col + row * img.width) * int(img.bytesPerPixel) + int(b)

				img.data[index1], img.data[index2] = img.data[index2], img.data[index1]
			}
		}
	}
}

flipVertically :: proc(img: ^TGAImage) {
	for col := 0; col < img.width; col += 1 {
		for row := 0; row < img.height / 2; row += 1 {
			for b: u8 = 0; b < img.bytesPerPixel; b += 1 {
				index1 := (col + row * img.width) * int(img.bytesPerPixel) + int(b)
				index2 :=
					(col + (img.height - 1 - row) * img.width) * int(img.bytesPerPixel) + int(b)

				img.data[index1], img.data[index2] = img.data[index2], img.data[index1]
			}
		}
	}
}

// END OF library code

drawLine :: proc(img: ^TGAImage, axp, ayp, bxp, byp: int, color: ^TGAColor) {
	ax, ay, bx, by := axp, ayp, bxp, byp
	steep := math.abs(ax - bx) < math.abs(ay - by)
	if steep {
		ax, ay = ay, ax
		bx, by = by, bx
	}

	if ax > bx {
		ax, bx = bx, ax
		ay, by = by, ay
	}

	for x := ax; x <= bx; x += 1 {
		t: f32 = f32(x - ax) / f32(bx - ax)
		y := int(math.round(f32(ay) + f32(by - ay) * t))
		if (steep) { 	//if transpose detranspose
			setColor(img, y, x, color)
		} else {
			setColor(img, x, y, color)
		}
	}
}

// First of all, (x,y) is an orthogonal projection of the vector (x,y,z).
projectVector :: proc(vec: Vector3, width, height: int) -> [3]int {
	projection: [3]int = {}
	// Second, since the input models are scaled to have fit in the [-1,1]^3 world coordinates,
	projection[0] = int((vec.x + 1.) * f32(width) / 2)
	// we want to shift the vector (x,y) and then scale it to span the entire screen.
	projection[1] = int((vec.y + 1.) * f32(height) / 2)

	projection[2] = int((vec.z + 1.) * f32(255) / 2)

	return projection
}


signedTriangleArea :: proc(a, b, c: [2]int) -> f32 {
	return(
		0.5 *
		f32((b.y - a.y) * (b.x + a.x) + (c.y - b.y) * (c.x + b.x) + (a.y - c.y) * (a.x + c.x)) \
	)
}

drawTriangle :: proc(img: ^TGAImage, depthMap: ^TGAImage, a, b, c: [3]int, color: ^TGAColor) {
	boundingBoxMin := [3]int {
		math.min(math.min(a.x, b.x), c.x),
		math.min(math.min(a.y, b.y), c.y),
		0,
	}
	boundingBoxMax := [3]int {
		math.max(math.max(a.x, b.x), c.x),
		math.max(math.max(a.y, b.y), c.y),
		0,
	}
	totalArea := signedTriangleArea([2]int{a.x, a.y}, [2]int{b.x, b.y}, [2]int{c.x, c.y})
	if totalArea < 1 {
		return
	}

	for x := boundingBoxMin.x; x <= boundingBoxMax.x; x += 1 {
		for y := boundingBoxMin.y; y <= boundingBoxMax.y; y += 1 {
			alpha :=
				signedTriangleArea([2]int{x, y}, [2]int{b.x, b.y}, [2]int{c.x, c.y}) / totalArea
			beta :=
				signedTriangleArea([2]int{x, y}, [2]int{c.x, c.y}, [2]int{a.x, a.y}) / totalArea
			gamma :=
				signedTriangleArea([2]int{x, y}, [2]int{a.x, a.y}, [2]int{b.x, b.y}) / totalArea
			if alpha < 0 || beta < 0 || gamma < 0 {
				continue // negative barycentric coordinate => the pixel is outside the triangle
			}

			blue := u8(alpha * f32(a.z) + beta * f32(b.z) + gamma * f32(c.z))
			depthColor := TGAColor {
				bgra = [4]u8{blue, 0, 0, 0},
			}
			setColor(depthMap, x, y, &depthColor)
			setColor(img, x, y, color)
		}
	}
}
