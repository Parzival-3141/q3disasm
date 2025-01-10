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
Here's the truncated output when running the tool on an assembled [`cgame.qvm`](https://github.com/id-Software/Quake-III-Arena/blob/master/code/cgame/cg_main.c).
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

vmMain():
00000000      ENTER 0x24      
00000001      LOCAL 0x14      
00000002      LOCAL 0x2C      
00000003      LOAD4
00000004     STORE4
00000005      LOCAL 0x14      
00000006      LOAD4
00000007      CONST 0x0       
00000008        LTI 0x7B       ; vmMain()+0x7B (0000007B)
00000009      LOCAL 0x14      
0000000A      LOAD4
0000000B      CONST 0x8       
0000000C        GTI 0x7B       ; vmMain()+0x7B (0000007B)
0000000D      LOCAL 0x14      
0000000E      LOAD4
0000000F      CONST 0x2       
00000010        LSH
00000011      CONST 0x8       
00000012        ADD
00000013      LOAD4
00000014       JUMP
00000015      LOCAL 0x30      
00000016      LOAD4
00000017        ARG 0x8       
00000018      LOCAL 0x34      
00000019      LOAD4
0000001A        ARG 0xC       
0000001B      LOCAL 0x38      
0000001C      LOAD4
0000001D        ARG 0x10      
0000001E      CONST 0xD1C      ; CG_Init()
0000001F       CALL
00000020        POP
00000021      CONST 0x0       
00000022      LEAVE 0x24      
00000023      CONST 0x85       ; vmMain()+0x85 (00000085)
00000024       JUMP
00000025      CONST 0xE36      ; CG_Shutdown()
00000026       CALL
00000027        POP
00000028      CONST 0x0       
00000029      LEAVE 0x24      
0000002A      CONST 0x85       ; vmMain()+0x85 (00000085)
0000002B       JUMP
0000002C      LOCAL 0x18      
0000002D      CONST 0xFDC      ; CG_ConsoleCommand()
0000002E       CALL
0000002F     STORE4
00000030      LOCAL 0x18      
00000031      LOAD4
00000032      LEAVE 0x24      
00000033      CONST 0x85       ; vmMain()+0x85 (00000085)
00000034       JUMP
00000035      LOCAL 0x30      
00000036      LOAD4
00000037        ARG 0x8       
00000038      LOCAL 0x34      
00000039      LOAD4
0000003A        ARG 0xC       
0000003B      LOCAL 0x38      
0000003C      LOAD4
0000003D        ARG 0x10      
0000003E      CONST 0x1002B    ; CG_DrawActiveFrame()
0000003F       CALL
00000040        POP
00000041      CONST 0x0       
00000042      LEAVE 0x24      
00000043      CONST 0x85       ; vmMain()+0x85 (00000085)
00000044       JUMP
00000045      LOCAL 0x1C      
00000046      CONST 0x17D      ; CG_CrosshairPlayer()
00000047       CALL
00000048     STORE4
00000049      LOCAL 0x1C      
0000004A      LOAD4
0000004B      LEAVE 0x24      
0000004C      CONST 0x85       ; vmMain()+0x85 (00000085)
0000004D       JUMP
0000004E      LOCAL 0x20      
0000004F      CONST 0x18E      ; CG_LastAttacker()
00000050       CALL
00000051     STORE4
00000052      LOCAL 0x20      
00000053      LOAD4
00000054      LEAVE 0x24      
00000055      CONST 0x85       ; vmMain()+0x85 (00000085)
00000056       JUMP
00000057      LOCAL 0x30      
00000058      LOAD4
00000059        ARG 0x8       
0000005A      LOCAL 0x34      
0000005B      LOAD4
0000005C        ARG 0xC       
0000005D      CONST 0xE3C      ; CG_KeyEvent()
0000005E       CALL
0000005F        POP
00000060      CONST 0x0       
00000061      LEAVE 0x24      
00000062      CONST 0x85       ; vmMain()+0x85 (00000085)
00000063       JUMP
00000064      LOCAL 0x30      
00000065      LOAD4
00000066        ARG 0x8       
00000067      LOCAL 0x34      
00000068      LOAD4
00000069        ARG 0xC       
0000006A      CONST 0xE3F      ; CG_MouseEvent()
0000006B       CALL
0000006C        POP
0000006D      CONST 0x0       
0000006E      LEAVE 0x24      
0000006F      CONST 0x85       ; vmMain()+0x85 (00000085)
00000070       JUMP
00000071      LOCAL 0x30      
00000072      LOAD4
00000073        ARG 0x8       
00000074      CONST 0xE39      ; CG_EventHandling()
00000075       CALL
00000076        POP
00000077      CONST 0x0       
00000078      LEAVE 0x24      
00000079      CONST 0x85       ; vmMain()+0x85 (00000085)
0000007A       JUMP
0000007B      CONST 0x3DE9    
0000007C        ARG 0x8       
0000007D      LOCAL 0x2C      
0000007E      LOAD4
0000007F        ARG 0xC       
00000080      CONST 0x1B8      ; CG_Error()
00000081       CALL
00000082        POP
00000083      CONST 0xFFFFFFFF
00000084      LEAVE 0x24      
00000085       PUSH
00000086      LEAVE 0x24      

CG_RegisterCvars():
00000087      ENTER 0x424     
    ...
```
