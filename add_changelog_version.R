suppressPackageStartupMessages(library(jsonlite))

files <- Sys.glob("datasets/*/*_metadata.json")
files <- sort(files)

updated <- 0L
skipped <- 0L
missing_git_date <- character(0)

for (f in files) {
  obj <- fromJSON(f, simplifyVector = FALSE)
  nms <- names(obj)

  has_dataset_version <- "dataset_version" %in% nms
  has_changelog <- "changelog" %in% nms

  if (has_dataset_version && has_changelog) {
    skipped <- skipped + 1L
    next
  }

  git_dates <- tryCatch(
    system2("git", c("log", "--follow", "--format=%as", "--", f), stdout = TRUE, stderr = FALSE),
    error = function(e) character(0)
  )
  git_dates <- git_dates[nzchar(git_dates)]
  earliest_date <- if (length(git_dates) > 0) tail(git_dates, 1) else as.character(Sys.Date())
  if (length(git_dates) == 0) {
    missing_git_date <- c(missing_git_date, f)
  }

  changelog_entry <- list(
    date = earliest_date,
    description = "Initial release.",
    type = "data",
    dataset_version = "1.0.0"
  )

  new_obj <- list()
  inserted <- FALSE

  for (nm in nms) {
    new_obj[[nm]] <- obj[[nm]]
    if (identical(nm, "zenodo_doi")) {
      if (!has_dataset_version) new_obj[["dataset_version"]] <- "1.0.0"
      if (!has_changelog) new_obj[["changelog"]] <- list(changelog_entry)
      inserted <- TRUE
    }
  }

  if (!inserted) {
    if (!has_dataset_version) new_obj[["dataset_version"]] <- "1.0.0"
    if (!has_changelog) new_obj[["changelog"]] <- list(changelog_entry)
  }

  compact <- toJSON(new_obj, auto_unbox = TRUE, pretty = FALSE, null = "null")
  pretty <- prettify(compact, indent = 2)
  writeLines(pretty, f, useBytes = TRUE)
  updated <- updated + 1L
}

cat(sprintf("TOTAL_FILES=%d\n", length(files)))
cat(sprintf("UPDATED=%d\n", updated))
cat(sprintf("SKIPPED=%d\n", skipped))
if (length(missing_git_date) == 0) {
  cat("MISSING_GIT_DATE=NONE\n")
} else {
  cat(sprintf("MISSING_GIT_DATE_COUNT=%d\n", length(missing_git_date)))
  for (p in missing_git_date) cat(sprintf("MISSING_GIT_DATE_FILE=%s\n", p))
}