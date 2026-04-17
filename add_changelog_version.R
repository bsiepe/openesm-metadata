suppressPackageStartupMessages(library(jsonlite))

set_field <- function(x, name, value) {
  x[name] <- list(value)
  x
}

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
    new_obj[nm] <- obj[nm]
    if (identical(nm, "zenodo_doi")) {
      if (!has_dataset_version) new_obj <- set_field(new_obj, "dataset_version", "1.0.0")
      if (!has_changelog) new_obj <- set_field(new_obj, "changelog", list(changelog_entry))
      inserted <- TRUE
    }
  }

  if (!inserted) {
    if (!has_dataset_version) new_obj <- set_field(new_obj, "dataset_version", "1.0.0")
    if (!has_changelog) new_obj <- set_field(new_obj, "changelog", list(changelog_entry))
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




# Now fix the date based on Zenodo date

# fix_changelog_dates.R
# Run once from the root of openesm-metadata to update changelog dates
# from git commit dates to Zenodo deposit dates.
# Requires the openesm R package to be installed.

library(jsonlite)
library(openesm)

get_git_fallback_date <- function(path) {
  git_dates <- tryCatch(
    system2("git", c("log", "--follow", "--format=%as", "--", path), stdout = TRUE, stderr = FALSE),
    error = function(e) character(0)
  )
  git_dates <- git_dates[nzchar(git_dates)]

  if (length(git_dates) > 0) {
    tail(git_dates, 1)
  } else {
    as.character(Sys.Date())
  }
}

needs_zenodo_sync <- function(meta, git_fallback_date) {
  if (length(meta$changelog) == 0) {
    return(FALSE)
  }

  current_date <- meta$changelog[[length(meta$changelog)]]$date
  is.null(current_date) || identical(current_date, git_fallback_date)
}

fetch_zenodo_versions <- function(doi, max_attempts = 6L, base_wait = 5) {
  for (attempt in seq_len(max_attempts)) {
    result <- tryCatch(
      list(data = openesm:::get_zenodo_versions(doi), error = NULL),
      error = function(e) list(data = NULL, error = conditionMessage(e))
    )

    if (is.null(result$error)) {
      return(list(data = result$data, error = NULL, rate_limited = FALSE))
    }

    is_rate_limited <- grepl("429|Too Many Requests", result$error, ignore.case = TRUE)
    if (!is_rate_limited || attempt == max_attempts) {
      return(list(data = NULL, error = result$error, rate_limited = is_rate_limited))
    }

    wait_seconds <- base_wait * (2 ^ (attempt - 1))
    cat(sprintf("  Rate limited. Waiting %d seconds before retry %d/%d...\n", wait_seconds, attempt + 1, max_attempts))
    Sys.sleep(wait_seconds)
  }

  list(data = NULL, error = "Unknown Zenodo request failure", rate_limited = FALSE)
}

write_pretty_json <- function(x, path) {
  compact <- toJSON(x, auto_unbox = TRUE, pretty = FALSE, null = "null")
  pretty <- prettify(compact, indent = 2)
  writeLines(pretty, path, useBytes = TRUE)
}

retry_file <- "zenodo_rate_limited_files.txt"
request_pause_seconds <- 1
rate_limited_files <- character(0)
other_failed_files <- character(0)

json_files <- list.files(
  "datasets",
  pattern = "_metadata\\.json$",
  recursive = TRUE,
  full.names = TRUE
)

if (file.exists(retry_file)) {
  retry_targets <- readLines(retry_file, warn = FALSE)
  retry_targets <- retry_targets[nzchar(retry_targets)]
  if (length(retry_targets) > 0) {
    json_files <- intersect(json_files, retry_targets)
  }
}

for (json_path in json_files) {
  cat("Processing:", basename(json_path), "\n")
  
  meta <- jsonlite::read_json(json_path, simplifyVector = FALSE)
  git_fallback_date <- get_git_fallback_date(json_path)
  
  if (is.null(meta$zenodo_doi) || !nzchar(meta$zenodo_doi)) {
    cat("  Skipping — no zenodo_doi found\n")
    next
  }

  if (!needs_zenodo_sync(meta, git_fallback_date)) {
    cat("  Skipping — changelog date already differs from git fallback date\n")
    next
  }
  
  versions_result <- fetch_zenodo_versions(meta$zenodo_doi)
  if (!is.null(versions_result$error)) {
    cat("  Failed to fetch Zenodo versions:", versions_result$error, "\n")
    if (versions_result$rate_limited) {
      rate_limited_files <- c(rate_limited_files, json_path)
    } else {
      other_failed_files <- c(other_failed_files, json_path)
    }
    next
  }

  versions <- versions_result$data
  
  if (is.null(versions) || nrow(versions) == 0) next
  
  # earliest date = initial deposit
  deposit_date <- min(versions$date)
  
  if (length(meta$changelog) == 0) {
    cat("  Skipping — changelog is empty, run TODO-02 backfill first\n")
    next
  }
  
  # update the last entry (initial release, oldest = last in newest-first order)
  meta$changelog[[length(meta$changelog)]]$date <- deposit_date
  
  write_pretty_json(meta, json_path)
  cat("  Updated date to:", deposit_date, "\n")
  Sys.sleep(request_pause_seconds)
}

if (length(rate_limited_files) > 0) {
  writeLines(unique(rate_limited_files), retry_file, useBytes = TRUE)
  cat(sprintf("Saved %d rate-limited files to %s\n", length(unique(rate_limited_files)), retry_file))
} else if (file.exists(retry_file)) {
  file.remove(retry_file)
  cat(sprintf("Removed %s because no rate-limited files remain\n", retry_file))
}

if (length(other_failed_files) > 0) {
  cat(sprintf("Other request failures: %d\n", length(unique(other_failed_files))))
}
