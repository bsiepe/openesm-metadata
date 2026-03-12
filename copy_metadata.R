# copy metadata files from github repository to local dataset folders

github_base_url <- "https://raw.githubusercontent.com/openesm-project/openesm-cleaning/main/data/metadata"
local_datasets_dir <- "datasets"

get_available_metadata_files <- function() {
  # use github api to list files in the metadata directory
  api_url <- "https://api.github.com/repos/openesm-project/openesm-cleaning/contents/data/metadata"
  
  tryCatch({
    response <- jsonlite::fromJSON(api_url)
    metadata_files <- response$name[grepl("_metadata\\.json$", response$name)]
    return(metadata_files)
  }, error = function(e) {
    stop("Failed to fetch file list from GitHub API: ", e$message)
  })
}

download_metadata_file <- function(filename, target_folder) {
  file_url <- file.path(github_base_url, filename)
  target_path <- file.path(target_folder, filename)
  
  tryCatch({
    download.file(file_url, target_path, mode = "wb", quiet = TRUE)
    cat("Downloaded:", filename, "to", target_folder, "\n")
    return(TRUE)
  }, error = function(e) {
    warning("Failed to download ", filename, ": ", e$message)
    return(FALSE)
  })
}

extract_dataset_info <- function(filename) {
  # extract dataset id and name from filename pattern: XXXX_name_metadata.json
  pattern <- "^(\\d{4})_([^_]+)_metadata\\.json$"
  match <- regmatches(filename, regexpr(pattern, filename, perl = TRUE))
  
  if (length(match) == 0) {
    return(NULL)
  }
  
  parts <- strsplit(gsub("_metadata\\.json$", "", filename), "_")[[1]]
  dataset_id <- parts[1]
  dataset_name <- parts[2]
  
  return(list(id = dataset_id, name = dataset_name, folder = paste0(dataset_id, "_", dataset_name)))
}

# main execution
metadata_files <- get_available_metadata_files()
cat("Found", length(metadata_files), "metadata files\n")

successful_downloads <- 0
created_folders <- 0
existing_folders <- 0

for (filename in metadata_files) {
  dataset_info <- extract_dataset_info(filename)
  
  if (is.null(dataset_info)) {
    warning("Could not parse filename: ", filename)
    next
  }
  
  folder_name <- dataset_info$folder
  target_folder <- file.path(local_datasets_dir, folder_name)
  
  # create folder if it doesn't exist
  if (!dir.exists(target_folder)) {
    dir.create(target_folder, recursive = TRUE)
    cat("Created folder:", target_folder, "\n")
    created_folders <- created_folders + 1
  } else {
    existing_folders <- existing_folders + 1
  }
  
  # download the metadata file
  if (download_metadata_file(filename, target_folder)) {
    successful_downloads <- successful_downloads + 1
  }
}

cat("\n=== SUMMARY ===\n")
cat("Total metadata files processed:", length(metadata_files), "\n")
cat("Successful downloads:", successful_downloads, "\n")
cat("New folders created:", created_folders, "\n")
cat("Existing folders used:", existing_folders, "\n")

if (successful_downloads < length(metadata_files)) {
  cat("Some downloads failed. Check warnings above.\n")
} else {
  cat("All metadata files successfully downloaded!\n")
}
