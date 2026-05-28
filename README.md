# qkit <a href="https://github.com/GabboCg/qkit"><img src="man/figures/logo.png" align="right" height="138" /></a>

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Overview

qkit is an R package that provides a small set of useful [Quarto](https://quarto.org) templates, currently shipping a Beamer presentation format and an academic CV format. It includes professional styling, enhanced author/affiliation support (including ORCID), and RStudio integration. Inspired by [beamer-tips](https://github.com/paulgp/beamer-tips), adapted for a Quarto-based workflow.

## Installation

```r
# Install from GitHub
# install.packages("remotes")
remotes::install_github("GabboCg/qkit")
```

## Usage

### From RStudio

File > New Project > New Directory > **qkit Beamer Presentation**

This creates a `.qmd` file with a full skeleton and installs the extension automatically.

### From R

```r
# Render a Quarto document (auto-installs the relevant qkit extension if needed)
qkit::qkit_render("slides.qmd")

# Preview with live reload
qkit::qkit_preview("slides.qmd")

# Or install the extension manually in any project
qkit::install_extension()
```

### Beamer format

Use `qkit-beamer` as the format in your YAML front matter:

```yaml
---
title: "My Presentation"
author:
  - name: Author Name
    orcid: 0000-0000-0000-0000
    affiliations:
      - ref: inst1

affiliations:
  - id: inst1
    name: Institution Name
    department: Department Name

format:
  qkit-beamer: default
---
```

### CV format

Use `qkit-pdf` for an academic CV:

```yaml
---
title: "CV"
author: "Your Name"
format:
  qkit-pdf: default
---
```

Scaffold a new CV project with:

```r
qkit::create_project("my-cv", type = "cv")
```

## Features

- Custom color palette (blue, red, yellow, green)
- Modified bullet styling and itemize/enumerate spacing
- Custom footline with frame numbers and navigation buttons
- Yellow section break slides
- ORCID support for author metadata
- Multiple authors with affiliations
- Short title and short author support
- Callout styling (note, warning)
- Text justification across all frames
