# Far arrays: DIM x(n):FAR type

In `l2b09run`, an array declared `FAR` keeps its elements in RAM outside the program's 64K, in whole 8K blocks. It is used with normal syntax. Only the declaration changes. Far arrays are an `l2b09run` feature: stock Basic09 and RunB do not have them, and PACK refuses procedures that use them.

## Usage

    TYPE pt=px,py:REAL; pn:INTEGER
    DIM big(14000):FAR REAL          (* 70,000 bytes *)
    DIM img(320,240):FAR BYTE        (* 76,800 elements *)
    DIM names(3000):FAR STRING[20]
    DIM pts(2000):FAR pt

    big(i):=big(i-1)*2.
    img(x,y):=MOD(x+y,256)
    names(1):=names(2993)
    pts(5).px:=1.5 \pts(6):=pts(5)

- **`FAR` goes after the colon, before the type.** The type is required. `FAR` applies to every array named before that colon: in `DIM a(10),b(20):FAR REAL`, both are far.
- **Any element type:** BYTE, INTEGER, REAL, BOOLEAN, STRING, or a TYPE record. An element may be at most 7,424 bytes.
- **Size.** Up to three dimensions, each up to 32,767 (as usual, subscripts are INTEGERs), and up to 255 blocks per array. Unlike near arrays, the total can exceed 64K: `img` above has 76,800 elements.
- **Everything else works as normal:** expressions, assignments in both directions (including far to far), READ, GET and PUT, SIZE of an element, LIST, SAVE, and the debugger's PRINT and LET. INPUT stores through the same code as READ, but it has not been tested.

## Lifetime

A far array belongs to one call of its procedure, like any other local variable.
- Its blocks are allocated (`F$AllRAM`) the first time the call uses the array.
- They are freed when the procedure returns.
- Recursion works: each call has its own copy.
- When a program stops, whether by END, STOP, an error you quit from with `q`, BYE or CHAIN, `l2b09run` frees all far arrays. Nothing is left allocated, and no `free` call is needed (unlike `farmem`).
- Like other variables, far arrays start with whatever was in memory. Clear them before relying on their contents.
- CHAIN frees them before it tries to chain. If the CHAIN then fails and the program carries on, its far arrays come back as new, uninitialised blocks.
- Only killing `l2b09run` itself (`S$Kill`) leaks the blocks.

## Not allowed

| Use | Error |
|---|---|
| Whole-array reference: `x:=SIZE(big)`, `RUN p(big)` | 65 (insufficient or excessive subscripts), at run time |
| An element passed by reference: `RUN p(big(1))` | 67 (illegal argument). Pass it by value instead: `RUN p(big(1)+0.)`, or for a string `RUN p(s(1)+"")` |
| `ADDR(big(1))` | 67 |
| `FAR` on a simple variable, a PARAM, or a TYPE field | 72 (illegal declarative statement), when the procedure is loaded |
| More than 255 blocks, or an element over 7,424 bytes | 73 (array size overflow), when loaded |

Addresses of far elements are meaningless outside one statement, because the window they appear in is reused. Assembly subroutines (`syscall`, `gfx`, ...) cannot be given far elements either; copy them to a near variable first.

## Things to know

- **`FAR` is a reserved word in `l2b09run`.** A program with a variable called `far` must rename it.
- **Address space.** Far elements are reached through one 8K data window.
  - Without `-b`, `l2b09run` keeps the window in the top 8K slot, which nothing else can use safely (see ARCHITECTURE.md, P7).
  - With `-b`, the code window has that slot, and the data window needs a free slot of its own. `l2b09run #24k -b=<kb>` works (tested). `#32k` with both leaves no slot, so the first far access fails with error 207.
- **Speed** (10,000 reads at 6.29 MHz; the clock has one-second resolution):
  - near array: about 3 s;
  - far, within one block: about 3 s;
  - far, alternating between two blocks: about 8 s, because each block change costs two system calls.

  Work through far arrays in order where you can. Elements are stored with the first subscript varying fastest, so for `img(x,y)` loop over `x` inside `y`.
- **Memory.** Each block holds a whole number of elements in its first 7,424 bytes; the rest of the block is unused. For example, a block holds 1,484 REALs.
- **Whole far records** that are assigned far to far across blocks are copied through the string stack, so a very large record can fail with error 47 (string stack overflow) in a small workspace.

## How it works

See ARCHITECTURE.md, P7. In short:
- The binder gives each far array a 6-byte handle in the part of the procedure's storage that is cleared on every call.
- The first access allocates the blocks.
- Each access computes a 24-bit element number, divides it by the number of elements per block, and maps that block into the data window.
- Procedure return frees the blocks of the procedure's own far arrays.
