# The basic09-l2 manuals

Two books, in the format of the Wildbits *GPU Programmer's Manual* (A4, numbered sections one to a page, navy tables, teal callouts):

- **`user/`: the basic09-l2 User's Manual.** The IDE: the editor, Make and Run, the debugger, PACK, the new features and help. It follows the video's order (`video/shotlist.txt`) and assumes the reader knows Basic09.
- **Learning Basic09 on basic09-l2** (not started): a book that teaches the language, written later.

## Building

```sh
make manual            # build/manual/basic09-l2-users-manual.pdf
```

The first `make manual` makes a virtualenv in `build/manual/venv` with ReportLab 4.2.5. Screenshots come from `build/shots/` (`make shots`); a missing one is drawn as a grey box with its name.

## Files

| Path | What |
|---|---|
| `build.py` | The builder: the markup below to a PDF, with the contents filled in on a second pass. |
| `figures.py` | The drawings (`@figure <name>`), drawn with ReportLab's graphics. |
| `fonts/` | IBM Plex Sans and JetBrains Mono (SIL Open Font License, `OFL-*.txt`), the slide deck's fonts. |
| `user/book.txt` | The cover, header and footer lines, the revision and its date. |
| `user/*.txt` | The text, in name order. |

## Markup

```
# <n> <title>              a chapter: a group in the contents and the outline
## <n> <title>             a section, on a new page ("## - Preface": no number)
### <title>                a heading inside a section
> <title>                  a callout; the following "> " lines are its text
| a | b                    a table; the first row is the header
- <text>                   a bullet (indented lines carry on)
```                        a code block
@figure <name>             a drawing from figures.py
@image <file> <mm> [<caption>]
@images <mm> <file> <file> ... [| <caption>]   side by side
@pagebreak
% <text>                   a comment
```

Inline: `**bold**`, `*italic*`, `` `code` ``. Menu paths use ▸ (Run ▸ Run to cursor).
