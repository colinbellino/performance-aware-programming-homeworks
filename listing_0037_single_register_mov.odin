package main

import "core:os"
import "core:log"
import "core:fmt"
import "core:slice"
import "core:runtime"
import "core:strings"

// odin run listing_0037_single_register_mov.odin -file -- input=listing_0038_many_register_mov logs
main :: proc() {
    logger: runtime.Logger;

    if slice.contains(os.args, "logs") {
        logger = log.create_console_logger(runtime.Logger_Level.Debug, { .Level, .Time, .Short_File_Path, .Line, .Terminal_Color });
    }

    context.logger = logger;

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

    bin_folder_path := "./computer_enhance/perfaware/part1/";
    bin_file_name := "listing_0037_single_register_mov";
    // bin_file_name := "listing_0038_many_register_mov";
    input_arg_index, found := slice.linear_search_proc(os.args, proc(item: string) -> bool {
        return strings.has_prefix(item, "input=");
    });
    if found {
        parts := strings.split(os.args[input_arg_index], "=");
        bin_file_name = parts[1];
    }
    bin_file_path := strings.concatenate([]string { "./computer_enhance/perfaware/part1/", bin_file_name });
    asm_file_path := strings.concatenate([]string { "./", bin_file_name, ".asm" });
    data := load_bin(bin_file_path);

    asm_sb := strings.builder_make();
    strings.write_string(&asm_sb, "bits 16\n\n");

    for i := 0; i < len(data); i += 2 {
        byte_0 := data[i + 0];
        byte_1 := data[i + 1];

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

        strings.write_string(&asm_sb, operation);
    }

    if slice.contains(os.args, "no-print") == false {
        fmt.print(strings.to_string(asm_sb));
    }
    if slice.contains(os.args, "asm") {
        write_asm(asm_file_path, asm_sb.buf[:]);
    }
}

load_bin :: proc(file_path: string) -> []u8 {
    data, success := os.read_entire_file_from_filename(file_path);

    if success == false {
        log.errorf("Couldn't load file: %v", file_path);
        os.exit(1);
    }

    log.debugf("Loaded file: %v", file_path);
    return data;
}

write_asm :: proc(file_path: string, data: []u8) {
    success := os.write_entire_file(file_path, data);
    log.debugf("Written file: %v", file_path);
}
