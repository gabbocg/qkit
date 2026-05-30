# qkit <a href="https://github.com/GabboCg/qkit"><img src="man/figures/logo.png" align="right" height="138" /></a>

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A small set of opinionated [Quarto](https://quarto.org) project templates
with RStudio integration. `qkit` ships four template types — a Beamer
presentation, an academic CV, a Quarto book project, and a minimalist
academic paper — each with a sensible LaTeX preamble, ORCID-aware
author handling, and a one-click *File > New Project* entry in RStudio.

Inspired by [beamer-tips](https://github.com/paulgp/beamer-tips), adapted
for a Quarto-based workflow and extended with three more formats.

## Installation

```r
# install.packages("remotes")
remotes::install_github("GabboCg/qkit")
```

You also need [Quarto](https://quarto.org/docs/get-started/) and a
working TeX distribution (TinyTeX or TeX Live). After installing
`qkit`, restart RStudio once so the wizard picks up the new project
templates.

## Templates

| Type | RStudio wizard entry | Output | Files dropped |
|------|----------------------|--------|---------------|
| `beamer` | qkit Beamer Presentation | XeLaTeX slides | `index.qmd` + `_extensions/qkit/` |
| `cv` | qkit CV | LuaLaTeX one-pager | `index.qmd` + `_extensions/qkit/` |
| `book` | qkit Book | XeLaTeX book (Krantz class) | full multi-file Quarto book project |
| `paper` | qkit Paper | XeLaTeX article + Internet Appendix | `index.qmd`, `internet-appendix.qmd`, two `.bib` stubs, two `.tex` preambles |

The Beamer and CV formats are backed by a Quarto extension; Book and
Paper are self-contained project scaffolds (no extension installed).

## Usage

### From RStudio

*File > New Project > New Directory*, pick one of the four `qkit`
entries, fill in the wizard fields, and click *Create*. RStudio
opens the scaffolded `index.qmd` in the editor.

### From the R console

```r
qkit::create_project("my-slides", type = "beamer", title = "Talk Title")
qkit::create_project("my-cv",     type = "cv",     author = "Your Name")
qkit::create_project("my-book",   type = "book",   title = "Book Title", author = "Your Name")
qkit::create_project("my-paper",  type = "paper",  title = "Paper Title")
```

To render an already-scaffolded document:

```r
qkit::qkit_render("my-slides/index.qmd")
qkit::qkit_preview("my-slides/index.qmd")   # live-reload preview
```

`qkit_render()` auto-installs the qkit Quarto extension into the
project directory if it isn't already there (only relevant for
`beamer` and `cv` — the book and paper formats don't use the
extension).

To install the qkit Quarto extension manually into any existing
Quarto project:

```r
qkit::install_extension(path = ".")
```

### YAML format keys

| Format | YAML `format:` entry |
|--------|----------------------|
| Beamer | `qkit-beamer` |
| CV     | `qkit-pdf` |
| Book   | configured in `_quarto.yml`'s `format: pdf:` block (no extension key) |
| Paper  | configured in `index.qmd`'s `format: pdf:` block (no extension key) |

## Per-template features

### Beamer (`qkit-beamer`)

- Custom color palette (blue, red, yellow, green)
- Bullet styling, itemize / enumerate spacing
- Custom footline with frame numbers and navigation buttons
- Yellow section-break slides
- Multiple authors with affiliations and ORCID
- Short title and short author support
- Callout styling (note, warning)
- Text justification across frames

### CV (`qkit-pdf`)

- LuaLaTeX engine with `mathpazo` font
- A small Pandoc Lua filter lets you write the CV in mostly-pure
  markdown via four semantic divs: `.cv-entries` (italic-key two-col
  table), `.cv-keys` (bold-key two-col table), `.cv-publications`
  (hanging-indent numbered list), `.cv-references` (two-column
  multicols block of `.referee` subdivs)
- Automatic horizontal rule under every `# Section` heading
- Fontawesome contact icons in the title header (email, phone,
  GitHub, web)
- Optional ORCID link via `orcidlink`
- Right-aligned "Updated: \today" stamp at the end of the document,
  controlled by `updated: true` in YAML
- Page footer with author / title on the centre and `page / total`
  on the right

### Book (qkit Book)

- Multi-file Quarto book project (`_quarto.yml` with `project: type:
  book`)
- Krantz document class (`krantz.cls` shipped in the scaffold)
- xelatex engine, `makeindex`, `sourcecodepro` font for code
- Generic title-page partial with optional ORCID and affiliation;
  no PhD-thesis specifics
- Optional dedication page (uncomment a block in `index.qmd` to
  enable; renders for both PDF and HTML)
- Book-friendly date format (`MMMM YYYY` → "May 2026")
- Sample chapter scaffold: preface, intro, one part with two
  chapters, references, one appendix

### Paper (qkit Paper)

- Minimalist 12pt `article`, 1in margins, doublespaced body,
  one-and-a-half-spaced title block and tables
- Three-author YAML scaffold with clickable
  `\href{mailto:...}{...}` emails, ORCID superscripts via
  `\orcidlink`, and per-author `\thanks{}` address footnotes
- Italic subsection headings, period-after-section numbering
  (`1. Introduction`), 1.5cm-indented quote env, symmetric
  display-equation spacing
- "Preliminary draft --- please do not cite without permission"
  italic subtitle inline under the title
- JEL Classification line below the abstract's Keywords
- In-paper Appendix block (`\appendix` + `\thesection = Appendix
  A`)
- Separate `internet-appendix.qmd` with its own `\maketitle`
  ("Internet Appendix for: \<Title\>" / authors / SUPPLEMENTARY
  RESULTS) and its own `references-appendix.bib`
- LaTeX preamble externalised into `preamble.tex` /
  `preamble-appendix.tex` so it can be edited without touching YAML
- References on a new page after the Conclusion (and at the end of
  the Internet Appendix)
- Pandoc `citeproc` for bibliographies (Chicago author-date by
  default)
- Body sections wired with an example two-way fixed-effects
  regression worked through Newton's law of cooling on a generic
  coffee dataset, just to demonstrate typography

## License

MIT © 2026 Gabriel Cabrera Guzmán. See [LICENSE.md](LICENSE.md) for
the full text.
