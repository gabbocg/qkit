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

  # Substitute placeholders only when the caller supplied a usable value.
  # RStudio passes empty wizard fields as NA; gsub() with replacement = NA
  # silently writes the literal string "NA" into the document.
  usable <- function(x) !is.null(x) && length(x) == 1L && !is.na(x) && nzchar(x)
  if (type == "beamer" && usable(title)) {
    content <- gsub("Untitled Presentation", title, content, fixed = TRUE)
  } else if (type == "cv" && usable(author)) {
    content <- gsub("Your Name", author, content, fixed = TRUE)
  }

  writeLines(content, fs::path(path, "index.qmd"), useBytes = TRUE)
  install_extension(path = path)
  invisible(path)
}
