# Vision & OCR

[← Back to the README](../../../../../README.md#bundled-software--stack)

## What it brings

| Tool | For | Commands |
| :--- | :--- | :--- |
| Tesseract OCR | reading the text out of an image | `tesseract` |
| ImageMagick | converting, resizing and cleaning images | `convert`, `identify`, `mogrify` |
| FFmpeg | audio and video | `ffmpeg`, `ffprobe` |

Tesseract reads **English and French** out of the box (the `tesseract-ocr-fra`
package is part of the pack). Another language is one command away:
`sudo apt-get install tesseract-ocr-<code>`.

## Installing and removing it

```powershell
.\wsl-fleet.ps1 manage_packs  # pick the instance, then tick vision
.\wsl-fleet.ps1 manage_packs   # untick to take it back
```

## From Python

| Tool | Reached through |
| :--- | :--- |
| Tesseract | `pytesseract`, which drives the `tesseract` binary |
| FFmpeg | `opencv-python` or `ffmpeg-python`, for the video formats |

Those libraries are **project** dependencies: they live in the project's
`.venv` (a `pyproject.toml` entry), not in this pack. The pack only makes sure
the machine has the tools underneath.
