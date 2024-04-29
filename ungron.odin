package ungron

import "core:bufio"
import "core:fmt"
import "core:log"
import "core:mem/virtual"
import "core:os"

main :: proc() {
	context.logger = log.create_console_logger(lowest = .Info)


	rdr: bufio.Reader
	rdr_buf: [4096 * 8]u8
	if len(os.args) > 1 {
		f, _ := os.open(os.args[1])
		bufio.reader_init_with_buf(&rdr, os.stream_from_handle(f), rdr_buf[:])
	} else {
		bufio.reader_init_with_buf(&rdr, os.stream_from_handle(os.stdin), rdr_buf[:])
	}

	wtr: bufio.Writer
	wtr_buf: [4096]u8
	bufio.writer_init_with_buf(&wtr, os.stream_from_handle(os.stdout), wtr_buf[:])

	_ = ungron(&rdr, &wtr)
}

ungron :: proc(rdr: ^bufio.Reader, wtr: ^bufio.Writer) -> (err: any) {
	input := rdr
	stdout := wtr

	buf: [4096]u8
	arena: virtual.Arena
	_ = virtual.arena_init_buffer(&arena, buf[:])
	arena_alloc := virtual.arena_allocator(&arena)
	stack := make([dynamic]StackItem, len = 0, cap = 1024, allocator = arena_alloc)
	append(&stack, StackItem.root)
	last_field_str := make([dynamic]u8, len = 0, cap = 256, allocator = arena_alloc)

	parse_state: ParseState = .startline
	prev_path_nest: int = 0
	curr_path_nest: int = 0
	last_field: LastField = .root
	main_loop: for {
		switch (parse_state) {
		case .startline:
			root: [4]u8
            root_bytes_read:= 0
            for root_bytes_read < 4 {
                bytes_read, rerr := bufio.reader_read(input, root[root_bytes_read:])
                root_bytes_read += bytes_read
                if rerr != nil {
                    parse_state = .end
                    continue main_loop
                }
            }
            // There's a problem here when compiling with -disable-assert
            // suddenly the last byte of the root is not read? It's a zero,
            // even though it should have a byte written in.
            fmt.printf("root_bytes_read: %d", root_bytes_read)
			log.debugf(".startline::prefix: %s", root)
			assert(transmute(string)root[:] == "json")
			c, _ := bufio.reader_read_byte(input)
			fmt.printf("after_root_c: '%c'", c)
			log.debugf(".startline: %c", c)
			switch (c) {
			case '.':
				parse_state = .dot
			case '[':
				parse_state = .bracket
			case ' ':
				parse_state = .path_end
			case:
				fmt.panicf("unreachable at start of line: %c", c)
			}
		case .dot:
			log.debugf(".dot")
			last_field = .object
			clear(&last_field_str)
			curr_path_nest += 1
			parse_state = .name
		case .bracket:
			c, _ := bufio.reader_read_byte(input)
			log.debugf(".bracket: %c", c)
			switch c {
			case '"':
				last_field = .object
				parse_state = .bracketed_name
			case:
				last_field = .array
				parse_state = .array_idx
			}
			clear(&last_field_str)
			curr_path_nest += 1
		case .name:
			c, _ := bufio.reader_read_byte(input)
			log.debugf(".name: %c", c)
			switch c {
			case '.':
				parse_state = .dot
			case '[':
				parse_state = .bracket
			case ' ':
				parse_state = .path_end
			case:
				append(&last_field_str, c)
			}
		case .bracketed_name:
			c, _ := bufio.reader_read_byte(input)
			log.debugf(".bracketed_name: %c", c)
			switch c {
			case '\\':
				// this will skip over escaped double quotes
				// in the switch expr.
				append(&last_field_str, '\\')
				append(&last_field_str, bufio.reader_read_byte(input) or_return)
			case '"':
				assert((bufio.reader_read_byte(input) or_return) == ']')
				switch bufio.reader_read_byte(input) or_return {
				case '.':
					parse_state = .dot
				case '[':
					parse_state = .bracket
				case ' ':
					parse_state = .path_end
				case:
					panic("unreachable in bracketed name")
				}
			case:
				append(&last_field_str, c)
			}
		case .array_idx:
			c, _ := bufio.reader_read_byte(input)
			log.debugf(".array_idx: %c", c)
			switch c {
			case '.':
				parse_state = .dot
			case '[':
				parse_state = .bracket
			case ' ':
				parse_state = .path_end
			case:
				{}
			}
		case .path_end:
			log.debugf(".path_end: curr nest %d, prev nest %d", curr_path_nest, prev_path_nest)
			// Reading across buffer breaks is a pain to deal with.
			c_00 := bufio.reader_read_byte(input) or_return
			assert(c_00 == '=')
			c_01 := bufio.reader_read_byte(input) or_return
			assert(c_01 == ' ')
			c := bufio.reader_read_byte(input) or_return
			log.debugf(".path_end::value start %c}", c)
			log.debugf(".path_end::stack_end %v", stack[len(stack) - 1])
			val_is_new_objarr := c == '{' || c == '['
			// Need to pop one more if prev line was empty objarr, and this one also is.
			new_objarr_follows_empty_objarr := false
			#partial switch stack[len(stack) - 1] {
			case .array_first, .object_first:
				new_objarr_follows_empty_objarr = val_is_new_objarr
			case:
				{}
			}

			// Try to end objects and arrays
			if curr_path_nest == prev_path_nest && new_objarr_follows_empty_objarr {
				// There's a significant perf slowdown if this `if` is merged into the
				// following `else if` as (curr_path_nest <= prev_path_nest) because all
				// diffs == 0 have to be checked, where this allows many fewer diffs to
				// be checked. And adding an additional `if` to this block doesn't appear
				// to impact perf.
				switch pop(&stack) {
				case .array, .array_first:
					bufio.writer_write_byte(stdout, ']')
				case .object, .object_first:
					bufio.writer_write_byte(stdout, '}')
				case .root:
					panic("unreachable stack item when ending object/array")
				}
			} else if curr_path_nest < prev_path_nest {
				i := len(stack)
				diff := prev_path_nest - curr_path_nest
				diff += new_objarr_follows_empty_objarr ? 1 : 0
				log.debugf(".path_end::updated_diff %d", diff)
				for i > len(stack) - diff {
					log.debugf(".path_end::pop_stack")
					i -= 1
					switch stack[i] {
					case .array, .array_first:
						bufio.writer_write_byte(stdout, ']')
					case .object, .object_first:
						bufio.writer_write_byte(stdout, '}')
					case .root:
						panic("unreachable stack item when ending object/array")
					}
				}
				resize(&stack, len(stack) - diff)
			}
			prev_path_nest = curr_path_nest
			curr_path_nest = 0

			// insert comma if needed
			#partial switch stack[len(stack) - 1] {
			case .root:
				{}
			case .array_first:
				stack[len(stack) - 1] = .array
			case .object_first:
				stack[len(stack) - 1] = .object
			case:
				bufio.writer_write_byte(stdout, ',')
			}

			// flushing more often helps with debugfging
			bufio.writer_flush(stdout)

			// write fields and values
			#partial switch last_field {
			case .object:
				// expects field name without quotes
				bufio.writer_write_byte(stdout, '"')
				bufio.writer_write(stdout, last_field_str[:])
				bufio.writer_write(stdout, transmute([]u8)string("\":"))
			case:
				{}
			}
			switch c {
			case '{':
				// Reading across buffer breaks is a pain to deal with.
				c_00 := bufio.reader_read_byte(input) or_return
				assert(c_00 == '}')
				c_01 := bufio.reader_read_byte(input) or_return
				assert(c_01 == ';')
				bufio.writer_write_byte(stdout, '{')
				append(&stack, StackItem.object_first)
				parse_state = .endline
			case '[':
				// Reading across buffer breaks is a pain to deal with.
				c_00 := bufio.reader_read_byte(input) or_return
				assert(c_00 == ']')
				c_01 := bufio.reader_read_byte(input) or_return
				assert(c_01 == ';')
				bufio.writer_write_byte(stdout, '[')
				append(&stack, StackItem.array_first)
				parse_state = .endline
			case '"':
				bufio.writer_write_byte(stdout, '"')
				parse_state = .value_string
			case:
				bufio.writer_write_byte(stdout, c)
				parse_state = .value_non_string
			}
		case .value_string:
			c := bufio.reader_read_byte(input) or_return
			log.debugf(".value_string: %c", c)
			switch c {
			case '\\':
				// this will skip over escaped double quotes
				// in the switch expr.
				bufio.writer_write_byte(stdout, '\\')
				bufio.writer_write_byte(stdout, bufio.reader_read_byte(input) or_return)
			case '"':
				bufio.writer_write_byte(stdout, '"')
				assert((bufio.reader_read_byte(input) or_return) == ';')
				parse_state = .endline
			case:
				bufio.writer_write_byte(stdout, c)
			}
		case .value_non_string:
			c := bufio.reader_read_byte(input) or_return
			log.debugf(".value_non_string: %c}", c)
			switch c {
			case ';':
				parse_state = .endline
			case:
				bufio.writer_write_byte(stdout, c)
			}
		case .endline:
			c := bufio.reader_read_byte(input) or_return
			log.debugf(".endline: %c", c)
			assert(c == '\n')
			parse_state = .startline
			// flushing more often helps with debugfging
			bufio.writer_flush(stdout)
		case .end:
			log.debugf(".end")
			// Close any remaining objects or arrays
			loop: for {
				if len(stack) > 0 {
					switch pop(&stack) {
					case .array, .array_first:
						bufio.writer_write_byte(stdout, ']')
					case .object, .object_first:
						bufio.writer_write_byte(stdout, '}')
					case .root:
						break loop
					}
				}
			}
			bufio.writer_write_byte(stdout, '\n')
			bufio.writer_flush(stdout)
			return
		}
	}
}

// *_first means that it's the first iteration through the array/object
StackItem :: enum {
	root,
	array_first,
	array,
	object,
	object_first,
}

LastField :: enum {
	root,
	array,
	object,
}

ParseState :: enum {
	startline,
	name,
	dot,
	bracket,
	bracketed_name,
	array_idx,
	path_end,
	value_string,
	value_non_string,
	endline,
	end,
}
