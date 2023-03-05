package main

import "core:os"
import "core:log"
import "core:fmt"
import "core:slice"
import "core:runtime"
import "core:strings"
import "core:math"
import "core:testing"
import tc "tests/common"

// odin run decode_asm.odin -file -- test asm no-print
main :: proc() {
    logger: runtime.Logger;
    if slice.contains(os.args, "logs") {
        logger = log.create_console_logger(runtime.Logger_Level.Debug, { .Level, .Time, .Short_File_Path, .Line, .Terminal_Color });
    }
    context.logger = logger;

    inputs := []string {
        "./computer_enhance/perfaware/part1/listing_0037_single_register_mov",
        "./computer_enhance/perfaware/part1/listing_0038_many_register_mov",
        // "./computer_enhance/perfaware/part1/listing_0039_more_movs",
        // "./computer_enhance/perfaware/part1/listing_0040_challenge_movs",
    };

    for input_bin_file_path in inputs {
        parts := strings.split(input_bin_file_path, "/");
        input_bin_file_name := parts[len(parts) - 1];

        asm_sb := strings.builder_make();
        decode_instructions(input_bin_file_path, &asm_sb);

        if slice.contains(os.args, "no-print") == false {
            fmt.print(strings.to_string(asm_sb));
        }
        if slice.contains(os.args, "asm") {
            output_asm_file_path := strings.concatenate([]string { "./", input_bin_file_name, ".asm" });
            write_asm(output_asm_file_path, asm_sb.buf[:]);
        }
        if slice.contains(os.args, "test") {
            t := testing.T {};
            input_asm_file_path := strings.concatenate([]string { input_bin_file_path, ".asm" });
            test_asm(&t, &asm_sb, input_asm_file_path);
            tc.report(&t);
        }
    }
}

decode_instructions :: proc(input_bin_file_path: string, asm_sb: ^strings.Builder) {
    op_codes := map[u8]string {
        0b100010 = "mov",
    };
    w0_mapping := map[u8]string {
        0b000 = "al",
        0b001 = "cl",
        0b010 = "dl",
        0b011 = "bl",
        0b100 = "ah",
        0b101 = "ch",
        0b110 = "dh",
        0b111 = "bh",
    };
    w1_mapping := map[u8]string {
        0b000 = "ax",
        0b001 = "cx",
        0b010 = "dx",
        0b011 = "bx",
        0b100 = "sp",
        0b101 = "bp",
        0b110 = "si",
        0b111 = "di",
    };

    input_data := load_bin(input_bin_file_path);

    strings.write_string(asm_sb, "bits 16\n\n");
    instruction_length := 2;

    for i := 0; i < len(input_data); i += instruction_length {
        byte_0 := input_data[i + 0];
        byte_1 := input_data[i + 1];

        op_code := (byte_0 & 0b1111_1100) >> 2;
        // 0 -> source in reg
        // 1 -> destination in reg
        d       := (byte_0 & 0x0000_0010) >> 1;
        // 0 -> byte data
        // 1 -> w data
        w       := (byte_0 & 0x0000_0001) >> 0;
        // 00 -> memory mode, no displacement (except when register_memory = 110, then 16bit displacement)
        // 01 -> memory mode, 8bit displacement
        // 10 -> memory mode, 16bit displacement
        // 11 -> register mode, no displacement
        mod     := (byte_1 & 0b1100_0000) >> 6;
        reg     := (byte_1 & 0b0011_1000) >> 3;
        rm      := (byte_1 & 0b0000_0111) >> 0;

        // log.debugf("data: %b", data);
        // log.debugf("op:   %b %v -> %v", op_code, op_code, op_codes[op_code]);
        // log.debugf("d:    %b %v", d, d);
        // log.debugf("w:    %b %v", w, w);
        // log.debugf("mod:  %b %v", mod, mod);
        // log.debugf("reg:  %b %v -> %v", reg, reg, w0_mapping[reg]);
        // log.debugf("r/m:  %b %v -> %v", rm, rm, w1_mapping[rm]);

        dest := w0_mapping[reg];
        source := w0_mapping[rm];
        if w == 1 {
            dest = w1_mapping[reg];
            source = w1_mapping[rm];
        }

        operation: string;
        if d == 1 {
            operation = fmt.tprintf("%s %s, %s\n", op_codes[op_code], dest, source);
        } else {
            operation = fmt.tprintf("%s %s, %s\n", op_codes[op_code], source, dest);
        }

        strings.write_string(asm_sb, operation);
    }
}

load_bin :: proc(file_path: string) -> []u8 {
    data, success := os.read_entire_file_from_filename(file_path);
    assert(success, fmt.tprintf("Couldn't load file: %v", file_path));

    log.debugf("Loaded file: %v", file_path);
    return data;
}

write_asm :: proc(file_path: string, data: []u8) {
    success := os.write_entire_file(file_path, data);
    log.debugf("Written file: %v", file_path);
}

@test
test_asm :: proc(t: ^testing.T, asm_sb: ^strings.Builder, expected_file_path: string) {
    data, success := os.read_entire_file_from_filename(expected_file_path);
    assert(success);
    expected := strings.clone_from_bytes(data);
    expected_lines: [dynamic]string;
    for line in strings.split(expected, "\n") {
        if strings.has_prefix(line, ";") || line == "" {
            continue;
        }
        append(&expected_lines, line);
    }

    result := strings.to_string(asm_sb^);
    result_lines: [dynamic]string;
    for line in strings.split(expected, "\n") {
        if strings.has_prefix(line, ";") || line == "" {
            continue;
        }
        append(&result_lines, line);
    }
    for expected_line, i in expected_lines {
        result_line := result_lines[i];
        tc.expect(t, result_line == expected_line, fmt.tprintf("%s -> \n%v\n != \n%v", #procedure, result_line, expected_line));
    }
}
