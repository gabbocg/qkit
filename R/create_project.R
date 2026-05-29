#' Create a new qkit project
#'
#' Scaffolds a Quarto project of the requested type:
#'   * `"beamer"` — a single-file Beamer presentation (uses the qkit
#'     extension for styling),
#'   * `"cv"` — a single-file academic CV (uses the qkit extension),
#'   * `"book"` — a multi-file Quarto book project with the Krantz
#'     document class, generic title-page partial, sample chapters,
#'     and a bibliography stub (self-contained — does NOT install the
#'     qkit extension because all book styling lives in the project's
#'     own `_quarto.yml` and template-partials).
#'
#' @param path Path to the new project directory.
#' @param type One of `"beamer"`, `"cv"`, `"book"`. Defaults to `"beamer"`.
#' @param title Presentation/book title (used when `type` is `"beamer"`
#'   or `"book"`).
#' @param author Author name (used when `type` is `"cv"` or `"book"`).
#' @param ... Additional arguments passed by RStudio (ignored).
#'
#' @return Invisibly returns the project path.
#' @export
create_project <- function(path,
                           type = "beamer",
                           title = "Untitled Presentation",
                           author = "Your Name",
                           ...) {
  # Guard against RStudio's wizard passing path as NA / "" / NULL, which
  # would silently coerce downstream fs::path() calls into the literal
  # string "NA" and write skeleton files into the parent directory.
  if (is.null(path) || length(path) != 1L || is.na(path) || !nzchar(path)) {
    stop("create_project() requires a non-empty 'path' argument. Got: ",
         deparse(path), call. = FALSE)
  }
  type <- match.arg(type, choices = c("beamer", "cv", "book"))
  fs::dir_create(path)

  # Substitute placeholders only when the caller supplied a usable value.
  # RStudio passes empty wizard fields as NA; gsub() with replacement = NA
  # silently writes the literal string "NA" into the document.
  usable <- function(x) !is.null(x) && length(x) == 1L && !is.na(x) && nzchar(x)

  if (type == "book") {
    book_src <- system.file("rstudio", "templates", "project", "skeleton",
                            "book", package = "qkit", mustWork = TRUE)
    files <- fs::dir_ls(book_src, recurse = TRUE, type = "file")
    for (f in files) {
      rel <- fs::path_rel(f, book_src)
      target <- fs::path(path, rel)
      fs::dir_create(fs::path_dir(target))
      fs::file_copy(f, target, overwrite = FALSE)
    }
    # Patch _quarto.yml with the user's supplied title/author.
    qy <- fs::path(path, "_quarto.yml")
    if (fs::file_exists(qy)) {
      content <- readLines(qy, encoding = "UTF-8")
      if (usable(title))  content <- gsub("Your Book Title", title, content, fixed = TRUE)
      if (usable(author)) content <- gsub("Your Name", author, content, fixed = TRUE)
      writeLines(content, qy, useBytes = TRUE)
    }
    return(invisible(path))
  }

  # beamer / cv: single-file skeleton + install the qkit extension.
  skeleton_name <- paste0(type, ".qmd")
  skeleton <- system.file("rstudio", "templates", "project", "skeleton",
                          skeleton_name, package = "qkit", mustWork = TRUE)
  content <- readLines(skeleton, encoding = "UTF-8")

  if (type == "beamer" && usable(title)) {
    content <- gsub("Untitled Presentation", title, content, fixed = TRUE)
  } else if (type == "cv" && usable(author)) {
    content <- gsub("Your Name", author, content, fixed = TRUE)
  }

  writeLines(content, fs::path(path, "index.qmd"), useBytes = TRUE)
  install_extension(path = path)
  invisible(path)
}
