---
name: Metadata update
about: Maintainer checklist for updating variable or dataset metadata
title: "Metadata update: [DATASET_ID] [FIRST_AUTHOR]"
labels: metadata-update
---

**Dataset ID:** <!-- e.g. 0012 -->  
**What changed:** <!-- construct coding / variable type / answer categories / dataset-level metadata / other -->

## Checklist

- [ ] Changes committed to metadata JSON
- [ ] Schema validation passes locally
- [ ] Pull latest `openesm-metadata`
- [ ] Re-run characterization pipeline locally for affected dataset
- [ ] Push updated statistics JSON
- [ ] Schema validation CI passes

## Notes

<!-- Downstream effects, e.g. construct taxonomy changes affecting multiple datasets -->
