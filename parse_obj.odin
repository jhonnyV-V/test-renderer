package main

import "core:bufio"
import "core:bytes"
import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"

Vector3 :: [3]f32
Vector2 :: [3]f32

Model :: struct {
	vertices: [dynamic]Vector3,
	faces:    [dynamic][3]int,
	name:     string,
}

readObj :: proc(filename: string) -> Model {
	fileHandle, fileOpenErr := os.open(filename)
	assert(fileOpenErr == 0, "failed to open file")
	defer os.close(fileHandle)

	model := Model {
		name = filename,
	}

	reader: bufio.Reader
	buffer: [2048]byte
	bufio.reader_init_with_buf(&reader, os.to_stream(fileHandle), buffer[:])
	defer bufio.reader_destroy(&reader)

	for {
		line, err := bufio.reader_read_slice(&reader, '\n')

		if err != nil {
			break
		}

		if line[0] == '#' ||
		   line[0] == 'g' ||
		   line[0] == 's' ||
		   bytes.is_space(rune(line[0])) ||
		   bytes.is_null(rune(line[0])) ||
		   line[0] == '\n' {
			continue
		}

		offset := 2
		if line[0] == 'v' && (line[1] == 't' || line[1] == 'n') {
			//make offset 4
			continue
		}

		valueString := strings.Builder{}
		valueCounter := 0
		vec := Vector3{}
		face := [3]int{}
		ignore := false
		isFace := line[0] == 'f'

		for i := offset; i < len(line) && valueCounter < 3; i += 1 {
			if bytes.is_space(rune(line[i])) {
				ignore = false
				if isFace {
					face[valueCounter], _ = strconv.parse_int(strings.to_string(valueString))
				} else {
					vec[valueCounter], _ = strconv.parse_f32(strings.to_string(valueString))
				}
				valueCounter += 1
				strings.builder_reset(&valueString)
				continue
			}

			if bytes.is_null(rune(line[i])) || line[i] == '\n' {
				break
			}

			(!ignore) or_continue

			if line[i] == '/' {
				ignore = true
				continue
			}

			_ = strings.write_byte(&valueString, line[i])
		}

		if line[0] == 'v' {
			append(&model.vertices, vec)
		} else if line[0] == 'f' {
			face.x -= 1
			face.y -= 1
			face.z -= 1
			append(&model.faces, face)
		}
	}

	return model
}
