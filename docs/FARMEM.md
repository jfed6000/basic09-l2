# farmem: memory beyond 64K for Basic09

`farmem` is a Basic09 subroutine module for NitrOS-9 Level 2. It gives a program RAM outside its 64K address space, in whole 8K blocks. It needs no interpreter changes and works with stock Basic09, stock RunB and `l2b09run`.

## Usage

    DIM fm(4):INTEGER               (* far memory descriptor *)
    DIM rec(64):REAL                (* any variable can be a record *)

    RUN farmem("alloc",fm,256)      (* 256K = 32 blocks *)
    RUN farmem("put",fm,i,rec)      (* store rec as record i *)
    RUN farmem("get",fm,i,rec)      (* load record i into rec *)
    RUN farmem("free",fm)           (* give the blocks back *)

| Command | Parameters | Effect |
|---|---|---|
| `alloc` | `fm, kb` | Allocate `kb` kilobytes, rounded up to 8K blocks (at most 255 blocks, about 2MB). `fm(1)` is the first block and `fm(2)` the block count. |
| `put` | `fm, index, var` | Copy `var` into record `index`. |
| `get` | `fm, index, var` | Copy record `index` into `var`. |
| `unmap` | `fm` | Release the 8K address window (it is mapped again on the next get or put). |
| `free` | `fm` | Unmap, then release the blocks. |

- **Records.** A record is `SIZE(var)` bytes, and record `index` starts at byte `index * SIZE(var)`. So far memory acts like an array of whatever you pass:
  - a single REAL (5 bytes per record);
  - a string (its declared length);
  - a whole array, as above (320 bytes per record);
  - a TYPE record.

  Use the same record size for the same data. Records may cross 8K block boundaries.
- **`index`** is an INTEGER, taken as unsigned (0 to 65535; values past 32767 are written as negative numbers).
- **Several areas.** Each descriptor is independent, so use one `fm` per data set.

## Things to know

- **Always `free`.** Blocks from `F$AllRAM` do not belong to the process. If a program ends without `free`, including when it stops on an error, the blocks stay allocated until the system restarts. Use `ON ERROR` to make sure `free` runs.
- **Leave an 8K slot free.** `farmem` maps one block at a time into an 8K window of the program's address space, and keeps it mapped between calls. So the program needs one free 8K slot of its 64K, besides the slot the `farmem` module itself is linked into. If there is no room, `get`/`put` fail with error 207 (`E$MemFul`).
  - Under stock Basic09 or RunB, `#24k` leaves enough room.
  - Under `l2b09run`, use `#16k`. Its code (24K) cannot use the top slot, which `l2b09run` keeps for its own windows (ARCHITECTURE.md, P7).
- **In `l2b09run`, prefer far arrays.** `DIM x(n):FAR type` ([FARARRAYS.md](FARARRAYS.md)) needs no descriptor, `get`/`put` or `free`, and is faster.
- **Cost.**
  - A `get`/`put` within the block already mapped costs about 0.5 ms at 6.29 MHz, mostly Basic09's `RUN` overhead.
  - Moving to a different block adds two system calls, about 0.3–0.4 ms.
  - So work through far memory in order where possible (`test/p4`, `p4bench`).
- **Descriptor contents.** The descriptor holds the mapping state (`fm(3)` = mapped block, `fm(4)` = window address). Do not change it, and do not let two copies of one area both map.

## Errors

| Code | Meaning |
|---|---|
| 55 | Record past the end of the area, or `alloc` size out of range (1 to 2040 KB). |
| 56 | Bad parameters: wrong count or types, descriptor not 4 INTEGERs, unknown command, area not allocated. |
| 237 | `alloc`: not enough free RAM. |
| 207 | No free 8K slot for the window. |

## Installing

Put `farmem` in the execution directory (`/dd/cmds`), or `load` it before running the program. As with `syscall` and `gfx`, it can be merged with `runb` for packed programs.
