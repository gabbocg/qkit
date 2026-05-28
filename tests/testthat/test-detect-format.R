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
