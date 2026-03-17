---
name: Adding dataset
about: Maintainer checklist for adding a new dataset
title: 'New dataset: [DATASET_ID] [FIRST_AUTHOR] [YEAR]'
labels: new-data
assignees: ''
type: Task

---

**Dataset ID:** <!-- e.g. 0062 -->  
**Zenodo DOI:**

## Checklist

- [ ] Cleaning script merged into `openesm-cleaning`
- [ ] Metadata JSON complete and schema-valid
- [ ] Zenodo DOI registered and resolving
- [ ] Independent validation of construct coding
- [ ] Pull latest `openesm-cleaning` and `openesm-metadata`
- [ ] Re-run descriptives pipeline locally
- [ ] Push updated statistics JSON to `openesm`
- [ ] Schema validation CI passes

## Notes

<!-- Scale recoding, missing time index, license constraints, anything else to remember -->
