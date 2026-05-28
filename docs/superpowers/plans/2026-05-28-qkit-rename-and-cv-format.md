# qkit Rename and CV Format Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename the R package `qbeamer` to `qkit`, generalize its scaffold API for multiple Quarto formats, migrate the existing Beamer extension into a `beamer/` subdirectory of the new single `qkit` extension, and add a CV (`pdf` format) under the same extension with a feature-demo skeleton.

**Architecture:** The package ships ONE Quarto extension at `inst/extdata/_extensions/qkit/` that contributes two formats (`beamer` and `pdf`). Format-specific LaTeX assets live in `beamer/` and `cv/` subdirectories. `install_extension()` (no `type` arg) copies the single extension into a project. `create_project(type = ...)` scaffolds a new project with the matching skeleton (always written as `index.qmd`). `qkit_render()` / `qkit_preview()` are format-agnostic wrappers around `quarto::quarto_render/preview` that call an internal `ensure_extension()` which scans the YAML for any `qkit-*` reference and auto-installs the extension if absent.

**Tech Stack:** R (S3-style functions, `fs` for filesystem ops, `yaml` for front-matter parsing, `testthat` for tests, `devtools`/`roxygen2` for package management), Quarto extensions (YAML config + Pandoc partials), LuaLaTeX (CV), XeLaTeX (Beamer).

**Spec reference:** `docs/superpowers/specs/2026-05-28-qkit-rename-and-cv-format-design.md`

**Working location:** `/Users/gabbocg/Dropbox (Personal)/Documentos/AI/qbeamer/.worktrees/qkit-rename/` on branch `feature/qkit-rename`. All commits land on the feature branch; the worktree merges back to `main` at the end via `superpowers:finishing-a-development-branch`. The rename is a hard cut.

**Plan revision history**:
- **2026-05-28 initial**: planned two extensions `qkit-beamer/` and `qkit-cv/` with YAML keys `qkit-beamer` / `qkit-cv`.
- **2026-05-28 pivot (during Phase 1 execution)**: discovered Quarto resolves `format: <ext>-<fmt>` by splitting at the last hyphen, so `format: qkit-beamer` referenced a non-existent extension `qkit`. Pivoted to ONE extension `qkit/` contributing both formats, with subdirectories. Clean YAML keys (`qkit-beamer`, `qkit-pdf`) and matches Quarto ecosystem conventions. Plan tasks below reflect the revised design.

**Out of scope (deferred to Spec B):** `qkit-manuscript` format, GitHub repo rename, pkgdown site, CI, NEWS.md, `qbeamer` deprecation shims.

---

## Phase 0: Pre-flight

### Task 0.1: Verify toolchain

**Files:** none

- [ ] **Step 1: Verify R, devtools, fs, quarto, yaml, testthat are installed**

Run from the package root:
```bash
Rscript -e 'cat("R:", R.version.string, "\n"); for (p in c("devtools","fs","quarto","yaml","testthat","roxygen2")) cat(p, ":", as.character(packageVersion(p)), "\n")'
```
Expected: each package prints a version. If any is missing, install it: `Rscript -e 'install.packages("yaml")'` (etc.).

- [ ] **Step 2: Verify LuaLaTeX and XeLaTeX are available**

```bash
lualatex --version | head -1
xelatex --version | head -1
```
Expected: both print version strings. If missing, install via the user's TeX distribution (TinyTeX, MacTeX, or TeX Live).

- [ ] **Step 3: Verify required LaTeX packages exist**

```bash
kpsewhich fontawesome.sty marvosym.sty orcidlink.sty multicol.sty enumitem.sty sectsty.sty titlesec.sty fancyhdr.sty
```
Expected: each line prints a path. Empty output means the package is missing — install it (`tlmgr install <pkg>` for TeX Live, or use the user's distribution-specific tool).

- [ ] **Step 4: Verify clean working tree**

```bash
git status
```
Expected: "working tree clean" or only show the (committed) spec and plan files.

---

## Phase 1: Rename foundation (preserve Beamer behavior end-to-end)

The goal of this phase: at the end, `library(qbeamer)` no longer works, `library(qkit)` does, and the existing Beamer extension still renders. No CV yet, no multi-format API yet.

### Task 1.1: Rename package in DESCRIPTION

**Files:**
- Modify: `DESCRIPTION`

- [ ] **Step 1: Edit DESCRIPTION**

Change line 1 from `Package: qbeamer` to `Package: qkit`.
Change line 2 from `Title: Custom Quarto Beamer Presentation Template` to `Title: A Small Set of Useful Quarto Templates`.
Change line 9 description first sentence from `Provides a Quarto extension and RStudio integration for creating professional Beamer presentations.` to `Provides Quarto extensions and RStudio integration for creating Beamer presentations and academic CVs.`.
**Important — GitHub handle correction:** the existing `DESCRIPTION` has `URL: https://github.com/gcabrerag/qbeamer` and `BugReports: https://github.com/gcabrerag/qbeamer/issues`, **but the actual repo handle is `GabboCg`** (verified via `git remote -v` → `https://github.com/GabboCg/qbeamer`). Update to:
- `URL: https://github.com/GabboCg/qkit`
- `BugReports: https://github.com/GabboCg/qkit/issues`

Use `GabboCg` (capital G, capital C) consistently across every renamed file in this plan — never `gcabrerag`.

- [ ] **Step 2: Verify**

```bash
grep -n "qbeamer\|qkit" DESCRIPTION
```
Expected: no `qbeamer` matches; `qkit` appears in Package, URL, BugReports.

### Task 1.2: Rename startup message

**Files:**
- Modify: `R/zzz.R`

- [ ] **Step 1: Replace both `"qbeamer"` strings**

Final contents:
```r
.onAttach <- function(libname, pkgname) {
  packageStartupMessage("qkit v", utils::packageVersion("qkit"))
}
```

- [ ] **Step 2: Verify**

```bash
grep -n "qbeamer" R/zzz.R
```
Expected: no matches.

### Task 1.3: Rename render/preview functions

**Files:**
- Modify: `R/render.R`

- [ ] **Step 1: Rename functions and update docs**

In `R/render.R`:
- Rename function `qbeamer_render` → `qkit_render` (both the function name and the `#' @name`/title in roxygen if explicit; the function name in the code is enough since roxygen reads it).
- Rename `qbeamer_preview` → `qkit_preview`.
- Update the title lines in roxygen comments (`#' Render a qbeamer presentation` → `#' Render a qkit Quarto document`; same for preview).
- The internal `ensure_extension()` is rewritten in a later task. For now, change only its body to install the **beamer** extension (so behavior is identical to today):

```r
ensure_extension <- function(input) {
  project_dir <- fs::path_dir(fs::path_abs(input))
  ext_dir <- fs::path(project_dir, "_extensions", "qkit")
  if (!fs::dir_exists(ext_dir)) {
    install_extension(path = project_dir)
  }
  invisible(TRUE)
}
```

Note: this assumes `install_extension(type = "beamer")` works. That refactor happens in Task 1.5 — sequence Tasks 1.3 → 1.5 → 1.4 if running out of order, but committed together this works since both files end up at their final shape by phase end. We commit at the end of the phase for this reason.

- [ ] **Step 2: Verify**

```bash
grep -n "qbeamer_" R/render.R
```
Expected: no matches.

### Task 1.4: Reorganize extension directory into the single `qkit/` layout

**Files:**
- Restructure: `inst/extdata/_extensions/qbeamer/` → `inst/extdata/_extensions/qkit/beamer/` (preamble.tex, title.tex move into the `beamer/` subdirectory)
- Replace: `inst/extdata/_extensions/qkit/_extension.yml` (new content; old `qbeamer/_extension.yml` removed)

- [ ] **Step 1: Move the LaTeX assets into the beamer/ subdirectory**

```bash
mkdir -p inst/extdata/_extensions/qkit/beamer
git mv inst/extdata/_extensions/qbeamer/preamble.tex inst/extdata/_extensions/qkit/beamer/preamble.tex
git mv inst/extdata/_extensions/qbeamer/title.tex inst/extdata/_extensions/qkit/beamer/title.tex
git rm inst/extdata/_extensions/qbeamer/_extension.yml
rmdir inst/extdata/_extensions/qbeamer 2>/dev/null || true
```

- [ ] **Step 2: Write the new `_extension.yml`**

Create `inst/extdata/_extensions/qkit/_extension.yml` with the following content (declares only the `beamer` format for now; the `pdf` format is added in Phase 3):

```yaml
title: qkit
author: Gabriel Cabrera Guzmán
version: 0.1.0
contributes:
  formats:
    beamer:
      include-in-header:
        - beamer/preamble.tex
      template-partials:
        - beamer/title.tex
      pdf-engine: xelatex
      navigation: horizontal
      theme: default
      colortheme: default
      aspectratio: 43
      keep-tex: true
```

Note the subdirectory paths `beamer/preamble.tex` and `beamer/title.tex` — Quarto resolves these relative to the extension folder.

- [ ] **Step 3: Verify**

```bash
ls inst/extdata/_extensions/
ls inst/extdata/_extensions/qkit/
ls inst/extdata/_extensions/qkit/beamer/
grep title inst/extdata/_extensions/qkit/_extension.yml
```
Expected: only `qkit/` listed at the extensions root; `_extension.yml` and `beamer/` directory inside `qkit/`; `preamble.tex` and `title.tex` inside `qkit/beamer/`; the title line reads `title: qkit`.

### Task 1.5: Rewrite install_extension (no type arg)

**Files:**
- Modify: `R/install_extension.R`

- [ ] **Step 1: Rewrite the function**

Under the single-extension design, `install_extension()` takes no `type` argument — there's only one extension to install. Final contents of `R/install_extension.R`:

```r
#' Install the qkit Quarto extension
#'
#' Copies the qkit Quarto extension files into a project directory,
#' making the `qkit-beamer` and `qkit-pdf` formats available.
#'
#' @param path Path to the project directory. Defaults to the current
#'   working directory.
#' @param overwrite If `TRUE`, overwrite the existing extension.
#'   Defaults to `FALSE`.
#'
#' @return Invisibly returns the installed target directory.
#' @export
install_extension <- function(path = ".", overwrite = FALSE) {
  target <- fs::path(path, "_extensions", "qkit")
  if (fs::dir_exists(target) && !overwrite) {
    message("qkit extension already installed at '", target,
            "'. Use overwrite = TRUE to reinstall.")
    return(invisible(target))
  }
  fs::dir_create(fs::path(path, "_extensions"))
  source <- system.file("extdata", "_extensions", "qkit",
                        package = "qkit", mustWork = TRUE)
  fs::dir_copy(source, target, overwrite = overwrite)
  message("qkit extension installed to '", target, "'.")
  invisible(target)
}
```

- [ ] **Step 2: Verify file syntactically valid**

```bash
Rscript -e 'parse(file = "R/install_extension.R")' && echo OK
```
Expected: prints `OK`.

### Task 1.6: Refactor create_project to take type argument

**Files:**
- Modify: `R/create_project.R`

- [ ] **Step 1: Rewrite the function**

Final contents of `R/create_project.R`:

```r
#' Create a new qkit project
#'
#' Scaffolds a Quarto project of the requested type (Beamer presentation
#' or CV), drops the appropriate skeleton document, and installs the
#' matching qkit extension.
#'
#' @param path Path to the new project directory.
#' @param type Either `"beamer"` or `"cv"`. Defaults to `"beamer"`.
#' @param title Presentation title (used when `type = "beamer"`).
#' @param author Author name (used when `type = "cv"`).
#' @param ... Additional arguments passed by RStudio (ignored).
#'
#' @return Invisibly returns the project path.
#' @export
create_project <- function(path,
                           type = "beamer",
                           title = "Untitled Presentation",
                           author = "Your Name",
                           ...) {
  type <- match.arg(type, choices = c("beamer", "cv"))
  fs::dir_create(path)

  skeleton_name <- paste0(type, ".qmd")
  skeleton <- system.file("rstudio", "templates", "project", "skeleton",
                          skeleton_name, package = "qkit", mustWork = TRUE)
  content <- readLines(skeleton, encoding = "UTF-8")

  if (type == "beamer") {
    content <- gsub("Untitled Presentation", title, content, fixed = TRUE)
  } else {
    content <- gsub("Your Name", author, content, fixed = TRUE)
  }

  writeLines(content, fs::path(path, "index.qmd"), useBytes = TRUE)
  install_extension(path = path)
  invisible(path)
}
```

- [ ] **Step 2: Verify**

```bash
Rscript -e 'parse(file = "R/create_project.R")' && echo OK
```
Expected: prints `OK`.

### Task 1.7: Rename and split RStudio templates

**Files:**
- Rename: `inst/rstudio/templates/project/qbeamer.dcf` → `inst/rstudio/templates/project/qkit-beamer.dcf`
- Rename: `inst/rstudio/templates/project/skeleton/skeleton.qmd` → `inst/rstudio/templates/project/skeleton/beamer.qmd`
- Modify: `inst/rstudio/templates/project/qkit-beamer.dcf`
- Modify: `inst/rstudio/templates/project/skeleton/beamer.qmd`

- [ ] **Step 1: Rename files**

```bash
git mv inst/rstudio/templates/project/qbeamer.dcf inst/rstudio/templates/project/qkit-beamer.dcf
git mv inst/rstudio/templates/project/skeleton/skeleton.qmd inst/rstudio/templates/project/skeleton/beamer.qmd
```

- [ ] **Step 2: Update qkit-beamer.dcf**

Read the current file. Final contents:

```
Binding: create_project
Title: qkit Beamer Presentation
OpenFiles: index.qmd
Subtitle: Create a new Beamer presentation from the qkit template.

Parameter: title
Widget: TextInput
Label: Presentation title
Default: Untitled Presentation
Position: left

Parameter: type
Widget: TextInput
Label: (do not edit) format type
Default: beamer
Position: left
```

**Note on the `type` parameter UX**: RStudio's project-template `.dcf` widgets do not include a hidden type; the available options are `TextInput`, `CheckboxInput`, `SelectInput`, `FileInput`. We use `TextInput` with a clear "(do not edit)" label, and `create_project()` validates the value via `match.arg()`, so an invalid edit fails fast with a readable error instead of silently producing the wrong skeleton. This is intentional and acceptable. Programmatic callers (`qkit::create_project(path, type = "beamer")`) bypass this widget entirely.

- [ ] **Step 3: Update beamer.qmd skeleton**

In `inst/rstudio/templates/project/skeleton/beamer.qmd`, replace **every** `qbeamer` reference (there are four: the format key on line 33, the prose "**qbeamer**" on line 38, the prose "qbeamer defines four custom colors" on line 76, and the URL/label pair on line 227). Specific replacements:

- Line 33: `qbeamer-beamer: default` → `qkit-beamer: default`
- Line 38: `This skeleton demonstrates the main features of **qbeamer**` → `This skeleton demonstrates the main features of **qkit-beamer**`
- Line 76: `qbeamer defines four custom colors` → `qkit-beamer defines four custom colors`
- Line 227: `- **qbeamer source**: [https://github.com/GabboCg/qbeamer](https://github.com/GabboCg/qbeamer)` → `- **qkit source**: [https://github.com/GabboCg/qkit](https://github.com/GabboCg/qkit)`

Verify with:
```bash
grep -n "qbeamer" inst/rstudio/templates/project/skeleton/beamer.qmd
```
Expected: no matches.

### Task 1.8: Rename example file

**Files:**
- Rename: `inst/examples/example.qmd` → `inst/examples/beamer-example.qmd`
- Modify: `inst/examples/beamer-example.qmd`

- [ ] **Step 1: Rename**

```bash
git mv inst/examples/example.qmd inst/examples/beamer-example.qmd
```

- [ ] **Step 2: Update qbeamer references**

In `inst/examples/beamer-example.qmd`, replace **every** `qbeamer` reference (mirroring the skeleton — same file structure). At minimum the format key on line ~42 needs updating. Use the same find/replace mapping as Task 1.7 Step 3.

```bash
grep -n "qbeamer" inst/examples/beamer-example.qmd
```
Expected: no matches.

### Task 1.9: Rename .Rproj file

**Files:**
- Rename: `qbeamer.Rproj` → `qkit.Rproj`

- [ ] **Step 1: Rename**

```bash
git mv qbeamer.Rproj qkit.Rproj
```

- [ ] **Step 2: Verify**

```bash
ls *.Rproj
```
Expected: `qkit.Rproj`.

### Task 1.10: Update README and CLAUDE.md

**Files:**
- Modify: `README.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Inspect current README**

```bash
cat README.md
```

- [ ] **Step 2: Replace `qbeamer` references**

In `README.md`: replace every literal `qbeamer` with `qkit` where it refers to the package name, and `qbeamer-beamer` with `qkit-beamer` where it refers to the format key.

Specific replacements based on the current README:
- Heading `# qbeamer` → `# qkit`
- Logo link `<a href="https://github.com/GabboCg/qbeamer">` → `<a href="https://github.com/GabboCg/qkit">`
- Overview paragraph: `qbeamer is an R package that provides…` → `qkit is an R package that provides…`. Expand the description to acknowledge it now ships multiple formats (Beamer presentations and academic CVs).
- Install instruction `remotes::install_github("GabboCg/qbeamer")` → `remotes::install_github("GabboCg/qkit")` (use `GabboCg`, not `gcabrerag`).
- RStudio entry name `Quarto Beamer Presentation (qbeamer)` → `qkit Beamer Presentation`.
- Function call `qbeamer::qbeamer_render` → `qkit::qkit_render` (and same for preview / install_extension).
- Format key example `qbeamer-beamer: default` → `qkit-beamer: default`.

Add a brief "CV format" section after the Beamer section showing the equivalent `format: qkit-pdf: default` YAML stub and a one-line `qkit::create_project("my-cv", type = "cv")` example.

- [ ] **Step 3: Update CLAUDE.md (if it exists)**

`CLAUDE.md` may or may not be present in the working tree (it has been deleted in past commits and is gitignored). Check:
```bash
ls CLAUDE.md 2>/dev/null
```

If present:
- Replace `qbeamer` with `qkit` throughout.
- In the "Architecture" section, update extension path references from `inst/extdata/_extensions/qbeamer/` to `inst/extdata/_extensions/qkit/` and describe the single-extension layout with `beamer/` and `cv/` subdirectories.
- Remove any reference to a non-existent `inst/rmarkdown/templates/qbeamer-presentation/` directory.
- Update function name references (`qbeamer_render` → `qkit_render`).
- Update format key examples to `qkit-beamer` and `qkit-pdf`.

If absent, this step is a no-op — proceed to Step 4.

- [ ] **Step 4: Verify**

```bash
grep -rn "qbeamer" README.md CLAUDE.md
```
Expected: no matches.

### Task 1.11: Regenerate documentation and NAMESPACE

**Files:**
- Modify (generated): `NAMESPACE`
- Modify (generated): `man/*.Rd`

- [ ] **Step 1: Delete stale man pages**

```bash
ls man/
rm -f man/qbeamer_render.Rd man/qbeamer_preview.Rd
```

- [ ] **Step 2: Regenerate**

```bash
Rscript -e 'devtools::document()'
```
Expected output: `Writing NAMESPACE`, new `.Rd` files for `qkit_render`, `qkit_preview`, `install_extension`, `create_project`.

- [ ] **Step 3: Verify NAMESPACE**

```bash
cat NAMESPACE
```
Expected: `export(create_project)`, `export(install_extension)`, `export(qkit_preview)`, `export(qkit_render)`, no `qbeamer_*` entries.

```bash
ls man/
```
Expected: `create_project.Rd`, `install_extension.Rd`, `qkit_preview.Rd`, `qkit_render.Rd`. No `qbeamer_*.Rd`.

### Task 1.12: Validate Phase 1 by rendering the Beamer example

**Files:** none

- [ ] **Step 1: Install the package locally**

```bash
Rscript -e 'devtools::install(quiet = TRUE)'
```
Expected: installs without errors. Note: this installs `qkit`, replacing any previously-installed `qbeamer`.

- [ ] **Step 2: Render the beamer example**

```bash
mkdir -p /tmp/qkit-phase1-render
cp inst/examples/beamer-example.qmd /tmp/qkit-phase1-render/
Rscript -e 'qkit::qkit_render("/tmp/qkit-phase1-render/beamer-example.qmd")'
```
Expected: a `.pdf` file appears at `/tmp/qkit-phase1-render/beamer-example.pdf`. Auto-install drops `_extensions/qkit/` (containing the `beamer/` subdirectory) into that directory. Exit status 0.

- [ ] **Step 3: Verify the PDF**

```bash
ls -la /tmp/qkit-phase1-render/beamer-example.pdf
```
Expected: nonzero file size. Optionally `open /tmp/qkit-phase1-render/beamer-example.pdf` and confirm the slides render with the qkit theme (no visual changes from before).

- [ ] **Step 4: Run R CMD check (informational at this stage)**

```bash
Rscript -e 'devtools::check(error_on = "never", quiet = FALSE)'
```
Expected: 0 errors, 0 warnings. Notes about new directory or about `yaml` not being declared yet are acceptable — `yaml` becomes an Imports in Phase 2.

### Task 1.13: Commit Phase 1

- [ ] **Step 1: Stage everything**

```bash
git add -A
git status
```
Expected: all renamed/modified/deleted files staged. Sanity check there's no stray file.

- [ ] **Step 2: Commit**

```bash
git commit -m "$(cat <<'EOF'
Rename qbeamer to qkit and prepare multi-format API

Phase 1 of Spec A. Renames the R package (DESCRIPTION, R/zzz.R,
R/render.R, R/install_extension.R, R/create_project.R), the
Quarto extension directory (qbeamer -> qkit, with the existing
beamer assets relocated to a beamer/ subdirectory inside the
single qkit extension), the RStudio
project template (.dcf and skeleton), the example file, the
.Rproj filename, README, and CLAUDE.md. Regenerates NAMESPACE
and man pages. install_extension() and create_project() now take
a type argument with "beamer" as default; "cv" wiring lands in
Phase 3.

The Beamer extension still renders end-to-end after the rename.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Phase 2: Add `yaml` dependency and test infrastructure

The new `ensure_extension()` needs to parse YAML front matter to detect which `qkit-*` format the document uses. This phase adds the `yaml` Imports and a `testthat` test suite for that single piece of logic. We do NOT add tests for trivial `fs::dir_copy` wrappers — they have no real logic.

### Task 2.1: Add yaml to DESCRIPTION Imports

**Files:**
- Modify: `DESCRIPTION`

- [ ] **Step 1: Edit DESCRIPTION**

Change `Imports: fs` to:
```
Imports:
    fs,
    yaml
```

- [ ] **Step 2: Add testthat to Suggests**

Change `Suggests: quarto` to:
```
Suggests:
    quarto,
    testthat (>= 3.0.0)
```

Add `Config/testthat/edition: 3` as a new line below `RoxygenNote`.

- [ ] **Step 3: Verify**

```bash
cat DESCRIPTION
```
Expected: `Imports` lists `fs` and `yaml`; `Suggests` lists `quarto` and `testthat`; `Config/testthat/edition: 3` present.

### Task 2.2: Set up testthat scaffolding

**Files:**
- Create: `tests/testthat.R`
- Create: `tests/testthat/` (directory)

- [ ] **Step 1: Run testthat scaffolding**

```bash
Rscript -e 'usethis::use_testthat(3)'
```
Expected: creates `tests/testthat.R` and `tests/testthat/` directory. If `usethis` is unavailable, manually create:

`tests/testthat.R`:
```r
library(testthat)
library(qkit)

test_check("qkit")
```

And `mkdir -p tests/testthat`.

- [ ] **Step 2: Verify**

```bash
ls tests/testthat.R tests/testthat
```
Expected: both exist.

### Task 2.3: TDD — write failing test for format detection

**Files:**
- Create: `tests/testthat/test-detect-format.R`

- [ ] **Step 1: Write the test file**

```r
# Tests for the internal qkit format-detection helper used by ensure_extension().
# The helper takes a path to a .qmd file and returns a character vector of
# detected qkit base formats ("beamer", "pdf"), normalizing across the YAML
# `format:` key being either a scalar string or a named map.
# Under Option B all qkit formats live under one extension folder; the
# helper's job is just to confirm at least one qkit-* format is referenced
# so ensure_extension() can install the extension when missing.

test_that("detect_qkit_formats reads a scalar format key", {
  tmp <- tempfile(fileext = ".qmd")
  on.exit(unlink(tmp))
  writeLines(c("---", "title: x", "format: qkit-beamer", "---", "body"), tmp)
  expect_equal(qkit:::detect_qkit_formats(tmp), "beamer")
})

test_that("detect_qkit_formats reads a mapped format key", {
  tmp <- tempfile(fileext = ".qmd")
  on.exit(unlink(tmp))
  writeLines(c("---", "title: x", "format:", "  qkit-pdf: default", "---", "body"), tmp)
  expect_equal(qkit:::detect_qkit_formats(tmp), "pdf")
})

test_that("detect_qkit_formats returns multiple types when multiple listed", {
  tmp <- tempfile(fileext = ".qmd")
  on.exit(unlink(tmp))
  writeLines(c("---", "title: x", "format:", "  qkit-beamer: default",
               "  qkit-pdf: default", "---", "body"), tmp)
  expect_setequal(qkit:::detect_qkit_formats(tmp), c("beamer", "pdf"))
})

test_that("detect_qkit_formats returns empty for non-qkit format", {
  tmp <- tempfile(fileext = ".qmd")
  on.exit(unlink(tmp))
  writeLines(c("---", "title: x", "format: html", "---", "body"), tmp)
  expect_equal(qkit:::detect_qkit_formats(tmp), character(0))
})

test_that("detect_qkit_formats returns empty when YAML parse fails", {
  tmp <- tempfile(fileext = ".qmd")
  on.exit(unlink(tmp))
  # Unterminated single-quoted string is a guaranteed yaml.load parse error.
  writeLines(c("---", "key: 'unterminated", "---", "body"), tmp)
  expect_equal(qkit:::detect_qkit_formats(tmp), character(0))
})

test_that("detect_qkit_formats returns empty when no front matter", {
  tmp <- tempfile(fileext = ".qmd")
  on.exit(unlink(tmp))
  writeLines(c("no front matter at all"), tmp)
  expect_equal(qkit:::detect_qkit_formats(tmp), character(0))
})
```

- [ ] **Step 2: Run and verify it fails**

```bash
Rscript -e 'devtools::test(filter = "detect-format")'
```
Expected: failure — `detect_qkit_formats` is not defined yet.

### Task 2.4: Implement detect_qkit_formats

**Files:**
- Modify: `R/render.R`

- [ ] **Step 1: Add the helper**

Append to `R/render.R` (before or after `ensure_extension`):

```r
#' Detect qkit base formats referenced in a Quarto document's YAML
#'
#' @param input Path to a `.qmd` file.
#' @return Character vector of detected qkit base formats (subset of
#'   `c("beamer", "pdf")`). Empty if no qkit format is referenced or
#'   if the front matter cannot be parsed.
#' @noRd
detect_qkit_formats <- function(input) {
  lines <- tryCatch(readLines(input, warn = FALSE, encoding = "UTF-8"),
                    error = function(e) character(0))
  fence <- which(lines == "---")
  if (length(fence) < 2) return(character(0))
  yaml_text <- paste(lines[(fence[[1]] + 1):(fence[[2]] - 1)], collapse = "\n")
  meta <- tryCatch(yaml::yaml.load(yaml_text), error = function(e) NULL)
  if (is.null(meta) || is.null(meta$format)) return(character(0))

  fmt <- meta$format
  keys <- if (is.character(fmt)) fmt else names(fmt)
  keys <- keys[!is.na(keys) & nzchar(keys)]

  prefix <- "qkit-"
  hits <- keys[startsWith(keys, prefix)]
  types <- substring(hits, nchar(prefix) + 1L)
  types <- types[types %in% c("beamer", "pdf")]
  unique(types)
}
```

- [ ] **Step 2: Run tests and verify pass**

```bash
Rscript -e 'devtools::load_all(); devtools::test(filter = "detect-format")'
```
Expected: all 6 tests pass.

### Task 2.5: Refactor ensure_extension to use detect_qkit_formats

**Files:**
- Modify: `R/render.R`

- [ ] **Step 1: Rewrite ensure_extension**

Replace the `ensure_extension()` body from Phase 1 with:

```r
#' Auto-install the qkit extension when referenced by a Quarto file
#'
#' Inspects the YAML front matter of `input`. If any `qkit-*` format is
#' referenced and `_extensions/qkit/` is missing next to `input`,
#' installs it.
#'
#' Silent no-op if no qkit format is referenced or the YAML cannot
#' be parsed — Quarto will report any actual error.
#'
#' @param input Path to a `.qmd` file.
#' @noRd
ensure_extension <- function(input) {
  types <- detect_qkit_formats(input)
  if (length(types) == 0L) return(invisible(FALSE))
  project_dir <- fs::path_dir(fs::path_abs(input))
  if (!fs::dir_exists(fs::path(project_dir, "_extensions", "qkit"))) {
    install_extension(path = project_dir)
  }
  invisible(TRUE)
}
```

- [ ] **Step 2: Run all tests**

```bash
Rscript -e 'devtools::test()'
```
Expected: all tests pass.

### Task 2.6: Regenerate docs and commit Phase 2

- [ ] **Step 1: Regenerate**

```bash
Rscript -e 'devtools::document()'
```

- [ ] **Step 2: Run R CMD check**

```bash
Rscript -e 'devtools::check(error_on = "never", quiet = FALSE)' 2>&1 | tail -50
```
Expected: 0 errors, 0 warnings, 0 notes (or only acceptable notes per spec §7.1 gate 2).

- [ ] **Step 3: Re-render the beamer example as a regression check**

```bash
rm -rf /tmp/qkit-phase2-render && mkdir /tmp/qkit-phase2-render
cp inst/examples/beamer-example.qmd /tmp/qkit-phase2-render/
Rscript -e 'devtools::install(quiet = TRUE); qkit::qkit_render("/tmp/qkit-phase2-render/beamer-example.qmd")'
ls /tmp/qkit-phase2-render/beamer-example.pdf
```
Expected: PDF exists. No regression from Phase 1.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
Add YAML front-matter scanning for format auto-install

Phase 2 of Spec A. Adds yaml to Imports, sets up testthat (edition 3),
introduces an internal detect_qkit_formats() helper that parses a
.qmd file's YAML front matter, normalizes the format: key whether
it's a scalar or a map, and returns the qkit format types referenced.
Rewrites ensure_extension() to use it, so qkit_render() now installs
whichever subset of qkit extensions the document actually references
(beamer, cv, or both).

Includes six unit tests covering scalar/map formats, multiple
formats, non-qkit formats, malformed YAML, and missing front matter.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Phase 3: Add the CV format to the qkit extension

This phase adds the `pdf` format (the CV) as a second contributed format under the existing single `qkit` extension, with its LaTeX assets in a `cv/` subdirectory.

### Task 3.1: Extend `_extension.yml` with the pdf format

**Files:**
- Modify: `inst/extdata/_extensions/qkit/_extension.yml`

- [ ] **Step 1: Append the pdf format block to the existing _extension.yml**

The file already declares the `beamer` format (from Task 1.4). Add a sibling `pdf` block under `contributes.formats`. Final contents:

```yaml
title: qkit
author: Gabriel Cabrera Guzmán
version: 0.1.0
contributes:
  formats:
    beamer:
      include-in-header:
        - beamer/preamble.tex
      template-partials:
        - beamer/title.tex
      pdf-engine: xelatex
      navigation: horizontal
      theme: default
      colortheme: default
      aspectratio: 43
      keep-tex: true
    pdf:
      include-in-header:
        - cv/preamble.tex
      template-partials:
        - cv/before-body.tex
      pdf-engine: lualatex
      geometry:
        - margin=0.70in
      fontfamily: mathpazo
      fontfamilyoptions:
        - sc
        - osf
      fontsize: 10pt
      linkcolor: blue
      urlcolor: blue
      keep-tex: true
```

- [ ] **Step 2: Verify**

```bash
cat inst/extdata/_extensions/qkit/_extension.yml
```
Expected: contents above with both `beamer` and `pdf` formats declared.

### Task 3.2: Create cv/preamble.tex

**Files:**
- Create: `inst/extdata/_extensions/qkit/cv/preamble.tex`

- [ ] **Step 1: Write the preamble**

```bash
mkdir -p inst/extdata/_extensions/qkit/cv
```

`inst/extdata/_extensions/qkit/cv/preamble.tex`:
```latex
% qkit CV preamble — included by Quarto via include-in-header for the
% qkit-pdf format. Adds CV-specific packages, macros, and styling on
% top of Quarto's default Pandoc LaTeX template.

\usepackage{multicol}
\usepackage{fontspec}
\usepackage{marvosym}
\usepackage{fontawesome}
\usepackage{orcidlink}
\usepackage{enumitem}
\usepackage{calc}
\usepackage{array}
\usepackage{xcolor}

% Custom column types and divider for L | R tabulars used throughout the CV.
\definecolor{lightgray}{gray}{0.8}
\newcolumntype{L}{>{\raggedleft}p{0.14\textwidth}}
\newcolumntype{R}{p{0.8\textwidth}}
\newcommand\VRule{\color{lightgray}\vrule width 0.5pt}

% Section font and spacing overrides.
\usepackage{sectsty}
\sectionfont{\rmfamily\mdseries\large\bf}
\subsectionfont{\rmfamily\mdseries\normalsize\itshape}

\usepackage{titlesec}
\titlespacing\section{0pt}{12pt plus 4pt minus 2pt}{4pt plus 2pt minus 2pt}
\titlespacing\subsection{0pt}{12pt plus 4pt minus 2pt}{4pt plus 2pt minus 2pt}

% Itemize without bullets, indented.
\renewenvironment{itemize}{%
  \begin{list}{}{\setlength{\leftmargin}{1.5em}}%
}{%
  \end{list}%
}

% Paragraph spacing in lists.
\usepackage{parskip}

% Page footer: author + title on the center, page/total on the right.
\usepackage{fancyhdr}
\usepackage{lastpage}
\pagestyle{fancy}
\renewcommand{\headrulewidth}{0pt}
\renewcommand{\footrulewidth}{0pt}
\lhead{}
\chead{}
\rhead{}
\lfoot{}
\cfoot{\scriptsize $author$ - $title$}
\rfoot{\scriptsize \thepage/{\hypersetup{linkcolor=black}\pageref{LastPage}}}

% Plain URL style (don't use monospace font for urls).
\urlstyle{same}
```

- [ ] **Step 2: Verify**

```bash
wc -l inst/extdata/_extensions/qkit/cv/preamble.tex
```
Expected: ~50 lines.

### Task 3.3: Create cv/before-body.tex

**Files:**
- Create: `inst/extdata/_extensions/qkit/cv/before-body.tex`

- [ ] **Step 1: Write the partial**

`inst/extdata/_extensions/qkit/cv/before-body.tex`:
```latex
% qkit CV before-body partial — renders the title header block for the
% qkit-pdf format.
% Reads YAML metadata: author (required), jobtitle, address, email,
% phone, github, web, orcid, fontawesome (bool, default true), updated
% (bool, default false).

\centerline{\huge \bf $author$}

\vspace{2 mm}

$if(jobtitle)$\moveleft.5\hoffset\centerline{$jobtitle$}$endif$
$if(address)$\moveleft.5\hoffset\centerline{$address$}$endif$

\vspace{1 mm}

\moveleft.5\hoffset\centerline{%
$if(email)$$if(fontawesome)$\faEnvelopeO \hspace{1 mm}$else$\emph{E-mail:}\hspace{1 mm}$endif$\href{mailto:$email$}{\tt $email$} \hspace{2 mm}$endif$%
$if(phone)$$if(fontawesome)$\faPhone \hspace{1 mm}$else$\emph{Phone:}\hspace{1 mm}$endif$$phone$ \hspace{2 mm}$endif$%
$if(github)$$if(fontawesome)$\faGithub \hspace{1 mm}$else$\emph{Github:}\hspace{1 mm}$endif$\href{https://github.com/$github$}{\tt $github$} \hspace{2 mm}$endif$%
$if(web)$$if(fontawesome)$\faGlobe \hspace{1 mm}$else$\emph{Web:}\hspace{1 mm}$endif$\href{https://$web$}{\tt $web$}$endif$%
$if(orcid)$ \hspace{2 mm} \orcidlink{$orcid$} {\tt $orcid$}$endif$%
$if(updated)$ \hspace{2 mm} \emph{Updated:} \today$endif$%
}

\vspace{4 mm}
```

- [ ] **Step 2: Verify**

```bash
wc -l inst/extdata/_extensions/qkit/cv/before-body.tex
```
Expected: ~25 lines.

### Task 3.4: Create the CV skeleton (feature demo)

**Files:**
- Create: `inst/rstudio/templates/project/skeleton/cv.qmd`

- [ ] **Step 1: Write the skeleton**

`inst/rstudio/templates/project/skeleton/cv.qmd`:
```markdown
---
title: "CV"
author: "Your Name"
jobtitle: ""
address: "Department, Institution, City, Country"
email: "you@example.org"
phone: ""
github: "your-github-handle"
web: "your-website.example.org"
orcid: ""
fontawesome: true
updated: true
keywords:
  - academic CV
  - Quarto
  - LaTeX

format:
  qkit-pdf: default
---

\vspace{5pt}
# Education
\vspace{-15pt}
\noindent\rule{\textwidth}{1pt}

\begin{tabular}{L!{\VRule width 1pt}R}
\textit{2022 - Current}&{\textbf{Your Department}, Your University, Country \newline Ph.D. in Your Field}\\[15pt]
\textit{2017 - 2019}&{\textbf{Your Department}, Earlier University, Country \newline M.Sc. in Your Field}\\[15pt]
\textit{2012 - 2017}&{\textbf{Your Department}, Earlier University, Country \newline B.A. in Your Field}
\end{tabular}

# Publications
\vspace{-15pt}
\noindent\rule{\textwidth}{1pt}

\begin{enumerate}[labelindent=0pt,labelwidth=\widthof{\ref{last-item}},label=\arabic*.,itemindent=0em,leftmargin=2.75em]
\item Title of Your First Published Paper, 2026, with Co-Author A and Co-Author B. \textbf{Journal Name}, vol. X, p. 1-20. [\href{https://example.org/paper1}{Link}]
\item Title of Your Second Published Paper, 2025, with Co-Author C. \textbf{Another Journal}, vol. Y, p. 100-150. [\href{https://example.org/paper2}{Link}]
\end{enumerate}

# Working Papers
\vspace{-15pt}
\noindent\rule{\textwidth}{1pt}

\begin{enumerate}[labelindent=0pt,labelwidth=\widthof{\ref{last-item}},label=\arabic*.,itemindent=0em,leftmargin=2.75em]
\item Title of Your First Working Paper, 2026, with Co-Author A.
\item Title of Your Second Working Paper, 2026. Available at \href{https://example.org/ssrn}{SSRN}.
\end{enumerate}

# Work-in-Progress
\vspace{-15pt}
\noindent\rule{\textwidth}{1pt}

\begin{enumerate}[labelindent=0pt,labelwidth=\widthof{\ref{last-item}},label=\arabic*.,itemindent=0em,leftmargin=2.75em]
\item Title of an In-Progress Project, with Co-Author A.
\item Another In-Progress Project.
\end{enumerate}

# Statistical Software Packages
\vspace{-15pt}
\noindent\rule{\textwidth}{1pt}

\begin{enumerate}[labelindent=0pt,labelwidth=\widthof{\ref{last-item}},label=\arabic*.,itemindent=0em,leftmargin=2.75em]
\item yourpackage: One-line Description, 2026. \textit{R package version 0.1.0}. [\href{https://example.org/yourpackage}{Link}]
\end{enumerate}

# Conferences and Workshops
\vspace{-15pt}
\noindent\rule{\textwidth}{1pt}

\begin{itemize}
\item Conference Name A (City, Year), Conference Name B (City, Year), Workshop C* (City, Year).
\item \hspace{1em} *\textit{Presentations by co-authors}
\end{itemize}

# Research Experience
\vspace{-15pt}
\noindent\rule{\textwidth}{1pt}

- **Your University**, Country

    \begin{tabular}{L!{\VRule width 1pt}R}
    \textit{2022 - Current}&{Postgraduate Researcher}\\[2.5pt]
    \end{tabular}

# Teaching Experience
\vspace{-15pt}
\noindent\rule{\textwidth}{1pt}

- **Undergraduate** \textbf{\small as Teaching Assistant}

    \begin{tabular}{L!{\VRule width 1pt}R}
    \textit{Fall 2025}&{\textbf{Course Name} \newline Your Department, Your University}
    \end{tabular}

# Grants and Scholarships
\vspace{-15pt}
\noindent\rule{\textwidth}{1pt}

\begin{tabular}{L!{\VRule width 1pt}R}
\textit{2022 - Current}&{Name of Your Scholarship.}
\end{tabular}

# Other Academic Services
\vspace{-15pt}
\noindent\rule{\textwidth}{1pt}

\begin{tabular}{L!{\VRule width 1pt}R}
\textbf{Referee}&{Journal A, Journal B, Journal C.}
\end{tabular}

# Languages
\vspace{-15pt}
\noindent\rule{\textwidth}{1pt}

\begin{tabular}{L!{\VRule width 1pt}R}
\textbf{Language A}&{Native}\\[2.5pt]
\textbf{Language B}&{Fluent}
\end{tabular}

# Research Interests
\vspace{-15pt}
\noindent\rule{\textwidth}{1pt}

List your research interests here as a comma-separated paragraph.

# References
\vspace{-15pt}
\noindent\rule{\textwidth}{1pt}

\begin{multicols}{2}

    \textbf{\href{https://example.org/referee-a}{Referee A, Ph.D.}}\\
    Department \\
    University \\
    Address \\
    \Letter\ \href{mailto:a@example.org}{a@example.org}

\vfill\columnbreak

    \textbf{\href{https://example.org/referee-b}{Referee B, Ph.D.}}\\
    Department \\
    University \\
    Address \\
    \Letter\ \href{mailto:b@example.org}{b@example.org}

\end{multicols}

# Other
\vspace{-15pt}
\noindent\rule{\textwidth}{1pt}

\begin{tabular}{L!{\VRule width 1pt}R}
\textbf{Nationality}&{Your Nationality}\\
\end{tabular}
```

- [ ] **Step 2: Verify**

```bash
wc -l inst/rstudio/templates/project/skeleton/cv.qmd
grep -c "qkit-pdf" inst/rstudio/templates/project/skeleton/cv.qmd
```
Expected: ~130 lines; `qkit-pdf` appears once (in the format key).

### Task 3.5: Create the CV example

**Files:**
- Create: `inst/examples/cv-example.qmd`

- [ ] **Step 1: Copy the skeleton as the example**

The example is identical to the project skeleton for now — both ship as feature demos with placeholder content. We keep them as separate files so future divergence (e.g., a richer example) doesn't touch the scaffold.

```bash
cp inst/rstudio/templates/project/skeleton/cv.qmd inst/examples/cv-example.qmd
```

- [ ] **Step 2: Verify**

```bash
diff -q inst/rstudio/templates/project/skeleton/cv.qmd inst/examples/cv-example.qmd
```
Expected: no diff.

### Task 3.6: Render the CV example end-to-end

**Files:** none

- [ ] **Step 1: Reinstall the package**

```bash
Rscript -e 'devtools::install(quiet = TRUE)'
```

- [ ] **Step 2: Render**

```bash
rm -rf /tmp/qkit-cv-render && mkdir /tmp/qkit-cv-render
cp inst/examples/cv-example.qmd /tmp/qkit-cv-render/
Rscript -e 'qkit::qkit_render("/tmp/qkit-cv-render/cv-example.qmd")'
```
Expected: succeeds, `cv-example.pdf` appears. Auto-install drops `_extensions/qkit/` next to the file (the same extension that the beamer example also uses; now with the `cv/` subdirectory present). Exit status 0.

- [ ] **Step 3: Check PDF**

```bash
ls -la /tmp/qkit-cv-render/cv-example.pdf
```
Expected: nonzero size.

- [ ] **Step 4: Open and visually check**

```bash
open /tmp/qkit-cv-render/cv-example.pdf
```
Run the manual visual review checklist from spec §7.2:
- [ ] Title header centered, large bold name, jobtitle/address below, fontawesome icon row.
- [ ] Each section heading followed by a horizontal rule.
- [ ] L|R tabulars with thin gray vertical rule between date and description columns.
- [ ] Publications/Working Papers use numbered hanging-indent lists.
- [ ] References section laid out in two columns.
- [ ] Footer shows author + title + page/total; page count not colored.
- [ ] URLs in upright (not monospace) font.

If any item fails, debug the corresponding LaTeX in preamble.tex or before-body.tex.

### Task 3.7: Commit Phase 3

- [ ] **Step 1: Stage**

```bash
git add -A
git status
```
Expected: new files in `inst/extdata/_extensions/qkit/cv/`, a modified `inst/extdata/_extensions/qkit/_extension.yml` (now with both formats), `inst/rstudio/templates/project/skeleton/cv.qmd`, and `inst/examples/cv-example.qmd`.

- [ ] **Step 2: Commit**

```bash
git commit -m "$(cat <<'EOF'
Add CV format (qkit-pdf) to the qkit extension

Phase 3 of Spec A. Extends the existing qkit extension's
_extension.yml to contribute a second format (pdf) for academic
CVs, alongside the beamer format from Phase 1. Adds a LaTeX
preamble at inst/extdata/_extensions/qkit/cv/preamble.tex
carrying the CV-specific packages and macros (multicol, marvosym,
fontawesome, orcidlink, enumitem, the L|R column types with
VRule, sectsty/titlesec spacing, fancyhdr footer with author/
title and page/total), and a cv/before-body.tex partial that
renders the centered name plus the contact icon row from YAML
metadata. Ships a feature-demo skeleton (format: qkit-pdf) at
the project template and example locations, covering all
sections from Education to Other with placeholder content and
the LaTeX patterns the user will copy from.

Renders end-to-end via qkit::qkit_render() on the example file.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Phase 4: Second RStudio project template (CV)

### Task 4.1: Create qkit-cv.dcf

**Files:**
- Create: `inst/rstudio/templates/project/qkit-cv.dcf`

- [ ] **Step 1: Write the dcf**

`inst/rstudio/templates/project/qkit-cv.dcf`:
```
Binding: create_project
Title: qkit CV
OpenFiles: index.qmd
Subtitle: Create a new academic CV from the qkit template.

Parameter: author
Widget: TextInput
Label: Your name
Default: Your Name
Position: left

Parameter: type
Widget: TextInput
Label: (do not edit) format type
Default: cv
Position: left
```

- [ ] **Step 2: Verify**

```bash
ls inst/rstudio/templates/project/
```
Expected: `qkit-beamer.dcf`, `qkit-cv.dcf`, and `skeleton/` directory.

### Task 4.2: Test the create_project flow for CV

**Files:** none

- [ ] **Step 1: Scaffold a fresh CV project programmatically**

```bash
rm -rf /tmp/qkit-cv-project
Rscript -e 'devtools::install(quiet = TRUE); qkit::create_project("/tmp/qkit-cv-project", type = "cv", author = "Test Author")'
```
Expected: directory created with `index.qmd` and `_extensions/qkit-cv/` inside.

- [ ] **Step 2: Verify substitution**

```bash
grep '^author:' /tmp/qkit-cv-project/index.qmd
```
Expected: `author: "Test Author"`.

- [ ] **Step 3: Render the scaffolded project**

```bash
Rscript -e 'qkit::qkit_render("/tmp/qkit-cv-project/index.qmd")'
ls /tmp/qkit-cv-project/index.pdf
```
Expected: PDF exists.

- [ ] **Step 4: Repeat for beamer**

```bash
rm -rf /tmp/qkit-beamer-project
Rscript -e 'qkit::create_project("/tmp/qkit-beamer-project", type = "beamer", title = "Test Talk"); qkit::qkit_render("/tmp/qkit-beamer-project/index.qmd")'
ls /tmp/qkit-beamer-project/index.pdf
```
Expected: PDF exists. Regression check that the beamer scaffold flow still works.

- [ ] **Step 5: Manual RStudio GUI smoke test (optional but recommended)**

Open RStudio with the package installed (`devtools::install()` already done). Use *File > New Project > New Directory* and confirm both **qkit Beamer Presentation** and **qkit CV** appear as options. Create one of each into temporary directories and confirm the `index.qmd` opens with the substituted `title`/`author`. This can't be automated from a Bash script; it's a one-time eyeball check.

### Task 4.3: Commit Phase 4

- [ ] **Step 1: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
Add RStudio project template for qkit-cv

Phase 4 of Spec A. Adds inst/rstudio/templates/project/qkit-cv.dcf
so RStudio's File > New Project wizard exposes a "qkit CV" entry.
The dcf binds to create_project() with type=cv passed via a hidden
parameter; the author parameter is editable in the wizard.

Verified end-to-end: scaffolding via create_project(type="cv",
author=...) produces an index.qmd with the substituted author,
the qkit-cv extension installed alongside, and a successful PDF
render.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Phase 5: Final validation

### Task 5.1: Mechanical gates

**Files:** none

- [ ] **Step 1: Document + check**

```bash
Rscript -e 'devtools::document()'
Rscript -e 'devtools::check(error_on = "never", quiet = FALSE)' 2>&1 | tail -60
```
Expected (spec §7.1):
- 0 errors, 0 warnings. Notes acceptable.
- `NAMESPACE` and `man/` regenerated cleanly. No `qbeamer_*.Rd` files.

- [ ] **Step 2: Run test suite**

```bash
Rscript -e 'devtools::test()'
```
Expected: all tests pass.

- [ ] **Step 3: Final render of both examples**

```bash
rm -rf /tmp/qkit-final && mkdir /tmp/qkit-final
cp inst/examples/beamer-example.qmd inst/examples/cv-example.qmd /tmp/qkit-final/
Rscript -e 'devtools::install(quiet = TRUE); qkit::qkit_render("/tmp/qkit-final/beamer-example.qmd"); qkit::qkit_render("/tmp/qkit-final/cv-example.qmd")'
ls -la /tmp/qkit-final/*.pdf
```
Expected: both PDFs exist with nonzero size.

- [ ] **Step 4: Verify no stray qbeamer references**

```bash
grep -rn --include="*.R" --include="*.Rd" --include="*.qmd" --include="*.tex" --include="*.yml" --include="*.dcf" --include="*.md" "qbeamer" R/ inst/ DESCRIPTION NAMESPACE CLAUDE.md README.md man/ 2>/dev/null
```
Expected: no matches. The `--include` filters skip binary files (e.g., `man/figures/logo.png`) which would otherwise produce noisy "binary file matches" lines.

Also confirm GitHub handle consistency:
```bash
grep -rn --include="*.R" --include="*.Rd" --include="*.qmd" --include="*.tex" --include="*.yml" --include="*.dcf" --include="*.md" "gcabrerag" R/ inst/ DESCRIPTION NAMESPACE CLAUDE.md README.md man/ 2>/dev/null
```
Expected: no matches (the canonical handle is `GabboCg`, never `gcabrerag`).

### Task 5.2: Manual visual review (CV)

Repeat the checklist from Task 3.6 step 4 on the final-built `cv-example.pdf` to confirm no regression introduced by Phases 4-5.

### Task 5.3: Commit final state

- [ ] **Step 1: Stage and commit any cleanup**

```bash
git status
git add -A
git diff --cached --stat
```

If there are any cleanup changes (regenerated docs, minor fixups), commit them:

```bash
git commit -m "$(cat <<'EOF'
Final cleanup for qkit rename and CV format

Regenerates documentation and resolves any straggler edits found
during the final validation pass.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

If `git status` is clean, no commit needed — the work is done at the prior commit.

- [ ] **Step 2: Summarize**

Print the commit log for the rename:
```bash
git log --oneline main^^^^^^..main
```
Expected: roughly 5-6 commits (one per phase plus the spec/plan setup).

---

## Done

When all phase commits are in place and all five mechanical gates pass:

- Package renamed `qbeamer` → `qkit`, hard cut.
- `qkit-beamer` extension migrated, no visual changes.
- `qkit-cv` extension shipped with preamble, partial, skeleton, example.
- `install_extension(type = ...)`, `create_project(type = ...)`, `qkit_render()`, `qkit_preview()` all work for both formats.
- Two RStudio project template entries (beamer, cv).
- Test suite for YAML format detection.
- README, CLAUDE.md, .Rproj all updated.

The next session can pick up Spec B (`qkit-manuscript`) with the multi-format infrastructure already in place — adding a new format becomes just a new extension directory under `inst/extdata/_extensions/qkit-manuscript/`, a new skeleton, a new `.dcf`, and adding `"manuscript"` to the `match.arg` choices in `install_extension()` and `create_project()`.
