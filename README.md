# openESM Metadata Repository

This repository contains structured metadata for all datasets in the **openESM project**, hosted at [openesmdata.org](https://openesmdata.org).

## Structure

- `datasets/` - Individual dataset folders with metadata JSON files
- `datasets.json` - Bundled metadata for all datasets (auto-generated)
- `bundle_metadata.R` - Script to combine individual metadata files
- `copy_metadata.R` - Script to sync metadata from source repository

## Usage

The bundled `datasets.json` file provides programmatic access to all dataset metadata. Individual metadata files are organized in folders following the pattern `XXXX_authorname/`.

## Automation

Metadata are automatically synchronized and bundled using GitHub Actions. The workflow can be triggered manually or runs monthly to catch updates.

## License

This metadata are licensed under [CC BY 4.0](LICENSE). Please cite the original dataset authors when using this metadata.