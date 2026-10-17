# oh_my_peg: ffmpeg, ImageMagick and Tesseract OCR

[← Back to the README](../../../../README.md#optional-tooling-packs)

Computer vision and OCR in the instance:
- ffmpeg for audio and video,
- ImageMagick for images, Tesseract for text recognition, with the French data.

**Type:** installable

## Packages

| Package | What it is |
| :--- | :--- |
| `ffmpeg` | video and audio |
| `imagemagick` | image editing |
| `tesseract-ocr` | the OCR engine |
| `tesseract-ocr-fra` | the French OCR data |

## Requires

oh_my_shell.

## Cheatsheets

Offered by `fcheat` (Alt+Z) beside every installed pack's:

| Sheet | What it covers |
| :--- | :--- |
| `vision` | Tesseract OCR, ImageMagick, ffmpeg - shown while `tesseract` is installed |

```sh
tesseract image.png out -l fra              # the text of an image, in French
tesseract image.png out pdf                 # ... as a searchable PDF
```
