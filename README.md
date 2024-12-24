# q3disasm
Disassembles a QVM file to stdout for funsies.

## Building
Requires [zig 0.13.0](https://ziglang.org/download/).
```sh
zig build-exe q3disasm.zig
./q3disasm -help
# or
zig run q3disasm.zig -- -help
```

## Example
Here's the truncated output when running the tool on the assembled [`cgame.qvm`](https://github.com/id-Software/Quake-III-Arena/blob/master/code/cgame/cg_main.c).
```
$ ./q3disasm -header cgame.qvm
cgame.qvm header:
    vm_magic:          0x12721444
    instruction_count: 99903
    code_offset:       0x20
    code_length:       294824
    data_offset:       0x47FC8
    data_length:       9980
    lit_length:        20384
    bss_length:        3856588

vmMain:
    ENTER 36
    LOCAL 20
    LOCAL 44
    LOAD4
    STORE4
    LOCAL 20
    LOAD4
    CONST 0
    LTI 123
    LOCAL 20
    LOAD4
    CONST 8
    GTI 123
    LOCAL 20
    LOAD4
    CONST 2
    LSH
    CONST 8
    ADD
    LOAD4
    JUMP
    LOCAL 48
    LOAD4
    ARG 8
    LOCAL 52
    LOAD4
    ARG 12
    LOCAL 56
    LOAD4
    ARG 16
    CONST 3356
    CALL
    POP
    CONST 0
    LEAVE 36
    CONST 133
    JUMP
    CONST 3638
    CALL
    POP
    CONST 0
    LEAVE 36
    CONST 133
    JUMP
    LOCAL 24
    CONST 4060
    CALL
    STORE4
    LOCAL 24
    LOAD4
    LEAVE 36
    CONST 133
    JUMP
    LOCAL 48
    LOAD4
    ARG 8
    LOCAL 52
    LOAD4
    ARG 12
    LOCAL 56
    LOAD4
    ARG 16
    CONST 65579
    CALL
    POP
    CONST 0
    LEAVE 36
    CONST 133
    JUMP
    LOCAL 28
    CONST 381
    CALL
    STORE4
    LOCAL 28
    LOAD4
    LEAVE 36
    CONST 133
    JUMP
    LOCAL 32
    CONST 398
    CALL
    STORE4
    LOCAL 32
    LOAD4
    LEAVE 36
    CONST 133
    JUMP
    LOCAL 48
    LOAD4
    ARG 8
    LOCAL 52
    LOAD4
    ARG 12
    CONST 3644
    CALL
    POP
    CONST 0
    LEAVE 36
    CONST 133
    JUMP
    LOCAL 48
    LOAD4
    ARG 8
    LOCAL 52
    LOAD4
    ARG 12
    CONST 3647
    CALL
    POP
    CONST 0
    LEAVE 36
    CONST 133
    JUMP
    LOCAL 48
    LOAD4
    ARG 8
    CONST 3641
    CALL
    POP
    CONST 0
    LEAVE 36
    CONST 133
    JUMP
    CONST 15849
    ARG 8
    LOCAL 44
    LOAD4
    ARG 12
    CONST 440
    CALL
    POP
    CONST -1
    LEAVE 36
    PUSH
    LEAVE 36

CG_RegisterCvars:
    ENTER 1060
    ...
```
