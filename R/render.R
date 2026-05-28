#' Render a qkit Quarto document
#'
#' Wrapper around `quarto::quarto_render()` that automatically installs the
#' required qkit extension if not present, then renders the document.
#'
#' @param input Path to the `.qmd` file to render.
#' @param ... Additional arguments passed to `quarto::quarto_render()`.
#'
#' @return The return value of `quarto::quarto_render()`.
#' @export
qkit_render <- function(input, ...) {
  ensure_extension(input)
  if (!requireNamespace("quarto", quietly = TRUE)) {
    stop("Package 'quarto' is required. Install it with install.packages('quarto').",
         call. = FALSE)
  }
  quarto::quarto_render(input, ...)
}

#' Preview a qkit Quarto document
#'
#' Wrapper around `quarto::quarto_preview()` that automatically installs the
#' required qkit extension if not present, then starts the preview.
#'
#' @param input Path to the `.qmd` file to preview.
#' @param ... Additional arguments passed to `quarto::quarto_preview()`.
#'
#' @return The return value of `quarto::quarto_preview()`.
#' @export
qkit_preview <- function(input, ...) {
  ensure_extension(input)
  if (!requireNamespace("quarto", quietly = TRUE)) {
    stop("Package 'quarto' is required. Install it with install.packages('quarto').",
         call. = FALSE)
  }
  quarto::quarto_preview(input, ...)
}

#' Auto-install extension next to the input file if missing
#'
#' @param input Path to a `.qmd` file.
#' @noRd
ensure_extension <- function(input) {
  project_dir <- fs::path_dir(fs::path_abs(input))
  ext_dir <- fs::path(project_dir, "_extensions", "qkit")
  if (!fs::dir_exists(ext_dir)) {
    install_extension(path = project_dir)
  }
  invisible(TRUE)
}
