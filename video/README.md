# The basic09-l2 video

The video is built from the slide deck, recorded clips of the program running, and narration, following `shotlist.txt`. `build.py` does the work with ffmpeg (`make video`).

## Files

| Path | What |
|---|---|
| `shotlist.txt` | The video, shot by shot. Edit it and rebuild. |
| `slides.txt` | The deck's slide ids in deck order: page *n* of the PDF is the slide on line *n*. Update it when slides are added, removed or moved. |
| `build.py` | The builder. |
| `media/` | Recordings and the slides PDF. Not in git (`.gitignore`): they are large, and they belong to the recording, not the source. |
| `media/slides.pdf` | The deck exported as PDF (Share ▸ Export ▸ PDF in the deck). Until it is there, each slide is a placeholder with its id. |
| `media/clips/` | Clips recorded with OBS. |
| `media/narration/` | Narration, one file per slide or run of slides (WAV, FLAC, MP3, ...). |

Output goes to `build/video/`: `basic09-l2.mp4`, `chapters.txt` (paste into the YouTube description), the slide images, and the segments.

## The shot list

```
chapter <title>                      a YouTube chapter starts at the next shot
slide <id> [<time>] [<audio>]        a slide, shown for <time>, or for its narration plus 0.75 s
clip <file> [<start>|-] [<end>|-] [audio=keep|mute|<file>] [crop=W:H:X:Y] [scale=int]
```

- **Times:** `5`, `5s`, `1:23`, `1:23.5`, `0:01:23`. `-` means the start or the end of the clip.
- **A slide with both a time and narration** is shown for the longer of the two.
- **`audio=`:** `keep` (the default) uses the clip's own sound; `mute` drops it; a file replaces it (narration recorded afterwards over a silent demo), cut or padded with silence to the clip's length.
- **`crop=W:H:X:Y`:** keeps only that part of the frame, before scaling: for example the machine's screen out of a full OBS canvas.
- **Scaling:** each clip fills 1920×1080 as far as its shape allows, centred on the deck's dark slate (`#13202B`). Enlarged 1.5 times or more, it keeps hard pixel edges, so the 80-column text stays sharp. `scale=int` enlarges by a whole number instead (640×480 becomes 1280×960), so every pixel is the same size, at the cost of wider borders.
- `#` starts a comment.

## Building

```sh
make video                  # or: video/build.py
video/build.py --list       # check the shot list without building
```

Each shot becomes a segment encoded the same way (H.264, 60 fps, AAC 48 kHz stereo), so the segments join without re-encoding. Segments are cached by their shot-list line and the dates and sizes of their files: changing one line rebuilds one segment. The last step evens out the loudness (EBU R128, −16 LUFS, YouTube's level).

`build.py` checks the YouTube chapter rules: the first chapter at 0:00, at least three, each at least 10 s.

## Recording

- **One clip per demo,** named in the shot list (`media/clips/editor.mkv`, ...). Short clips are easier to redo, and trimming is a start and end time in the shot list.
- **OBS:** record MKV (it survives a crash), at the capture card's native resolution. Leave scaling to `build.py`: it enlarges with hard pixel edges, and OBS's scaler blurs.
- **Narration:** live while you demo (`audio=keep`), or recorded afterwards per clip (`audio=<file>`). For slides, one file per slide.
