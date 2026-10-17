# oh_my_doc: Pandoc and XeLaTeX.

[← Back to the README](../../../../README.md#optional-tooling-packs)

Markdown to PDF and the document chain around it:
- pandoc for the conversion,
- XeLaTeX and its font packages for the typesetting,
- poppler to open the result,
- the font and CSL-catalogue targets that feed them.

**Type:** installable

## Packages

| Package | What it is |
| :--- | :--- |
| `pandoc` | the document converter |
| `texlive-xetex` | the XeLaTeX engine |
| `texlive-latex-extra` | the LaTeX package set |
| `texlive-fonts-recommended` | the recommended font set |
| `texlive-lang-french` | French typesetting |
| `fontconfig` | font discovery |
| `poppler-utils` | the PDF tools |

## Requires

oh_my_shell.

## gmake

| Target | What it does |
| :--- | :--- |
| `pdf_from_md` | Build the project's markdown into a PDF (pandoc + XeLaTeX) |
| `pdf_open` | Open a built PDF (`PDF_OUT`'s, `PDF_SRC`'s, or the folder's own - the menu lists those) |
| `docx_from_md` | Build the project's markdown in Word format (.docx) - Word is not needed |
| `csl_from_catalog` | Fetch a citation style from the official CSL catalog, into this project |
| `font_from_windows` | Copy a font family from the Windows side |
| `font_from_google` | Copy a font family from Google Fonts (~1,800 free families - menu, or `FONT=`) |
| `font_from_ubuntu` | Install a font package from the archive (menu, or `FONT=`) |

```sh
gmake pdf_from_md
gmake font_from_google
```

## Cheatsheets

Offered by `fcheat` (Alt+Z) beside every installed pack's:

| Sheet | What it covers |
| :--- | :--- |
| `pandoc` | the targets, what a document needs, the YAML header, the bare command, the PDF tools, build failures - shown while `pandoc` is installed |
