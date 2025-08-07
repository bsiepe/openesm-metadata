# bundle metadata JSON files into a single datasets.json file
datasets_dir <- "datasets"
dataset_folders <- list.dirs(datasets_dir, full.names = TRUE, recursive = FALSE)

read_metadata_file <- function(folder_path) {
  folder_name <- basename(folder_path)
  metadata_file <- file.path(folder_path, paste0(folder_name, "_metadata.json"))
  
  if (!file.exists(metadata_file)) {
    warning(paste("Metadata file not found:", metadata_file))
    return(NULL)
  }
  
  tryCatch({
    metadata <- jsonlite::fromJSON(metadata_file, simplifyDataFrame = FALSE)
    cat("Successfully read:", metadata_file, "\n")
    return(metadata)
  }, error = function(e) {
    warning(paste("Error reading", metadata_file, ":", e$message))
    return(NULL)
  })
}

cat("Reading metadata files from dataset folders...\n")
all_metadata <- purrr::map(dataset_folders, read_metadata_file)
all_metadata <- purrr::compact(all_metadata)

if (length(all_metadata) == 0) {
  stop("No valid metadata files found!")
}

cat("Successfully read", length(all_metadata), "metadata files\n")

combined_datasets <- list(
  metadata = list(
    created_at = Sys.time(),
    n_datasets = length(all_metadata),
    description = "Combined metadata from all OpenESM datasets"
  ),
  datasets = all_metadata
)

output_file <- "datasets.json"
cat("Writing combined metadata to", output_file, "...\n")

tryCatch({
  jsonlite::write_json(combined_datasets, output_file, pretty = TRUE, auto_unbox = TRUE)
  cat("Successfully created", output_file, "\n")
}, error = function(e) {
  stop(paste("Error writing output file:", e$message))
})

cat("\n=== SUMMARY ===\n")
cat("Total datasets processed:", length(all_metadata), "\n")
cat("Output file:", output_file, "\n")
cat("File size:", file.size(output_file), "bytes\n")

dataset_ids <- purrr::map_chr(all_metadata, ~ .x$dataset %||% "unknown")
cat("Dataset IDs included:", paste(dataset_ids, collapse = ", "), "\n")
