# ADR 0001: Private Raw Garmin Data Backup

Date: 2026-08-29

## Status

Accepted for planning. Not implemented in this repository.

## Context

`zlifts` publishes a static GitHub Pages dashboard from committed processed data. Raw Garmin Connect Splits CSV exports stay local-only under `data/raw/workouts/` because they can contain private source data that the public dashboard does not need. The local importer now turns those CSVs into `data/processed/lifting_sets.csv` plus `data/processed/workouts.csv`.

The next storage step should protect raw exports from local disk loss without turning the public repository into a raw-data store.

## Decision

Use a separate private GitHub repository as the v1 raw-data backup, for example `zlifts-raw-data`. Keep the public `zlifts` repository as the processed-data and dashboard repository.

The private repository should store raw CSVs with the existing filename convention:

```text
YYYY-MM-DD-garmin-splits-<garmin-activity-id>.csv
```

The local restore path is:

```text
clone private raw-data repo
copy or sync CSVs into data/raw/workouts/
Rscript scripts/update-workouts.R --check
Rscript scripts/update-workouts.R --write
```

For future cloud automation, prefer running the ingestion workflow from the private raw-data repository. That workflow can check out the public dashboard repository, run the importer against private raw files, and open or update a pull request containing only processed data changes. Raw CSV files should never be uploaded to the public repository, Pages artifacts, workflow logs, or release artifacts.

## Options Considered

### Private GitHub Repository

Best v1 fit. Raw Splits CSVs are small text files, Git gives understandable history and restore behavior, and the workflow stays close to the existing GitHub Actions deployment. GitHub private repositories restrict access to explicitly allowed users. If a workflow needs to check out a separate private repository, `actions/checkout` requires an explicit token such as a repository secret rather than relying on the current repository token.

Tradeoffs: raw health-adjacent files still live in GitHub, Git is awkward for large binary exports, and history removal is difficult if a sensitive file is committed by mistake.

### Google Drive

Good manual backup option, especially with Drive for desktop mirroring. It is easy to understand and restore from Windows Explorer.

Tradeoffs: it is less clean for reproducible CI. Server-to-server Google API access generally needs service-account credentials and can require Workspace domain delegation to act on a user's Drive, which is more operational overhead than this project needs for v1.

### Object Storage

Best later option if raw-data volume grows or fully automated cloud ingestion needs provider-grade storage controls. S3-style storage supports private buckets and versioning, and new S3 buckets have strong default security posture.

Tradeoffs: it adds IAM, bucket policy, lifecycle, CLI credentials, and cost/account management before the local pipeline has enough mileage to justify that complexity.

## Security And Secrets

- Do not commit raw Garmin exports to `wzbillings/zlifts`.
- Keep raw-data credentials out of both repositories.
- Store automation credentials only in GitHub Actions secrets or an equivalent secret manager.
- Use the narrowest practical token: read access to the private raw repo and write access only where processed-data PRs must be created.
- Do not print raw CSV contents, full file paths containing private sync folders, or credential-derived values in workflow logs.
- Keep public Pages builds reading committed processed data only.

## Migration Path

1. Create the private raw-data repository.
2. Move or copy existing local raw Splits CSVs into that private repository and commit them there.
3. Keep `data/raw/workouts/` as the ignored local inbox for active imports.
4. Add a local sync helper that copies changed private-repo CSVs into the inbox and runs `scripts/update-workouts.R --check`.
5. Later, add a private-repo GitHub Actions workflow that runs ingestion and opens a processed-data PR against `wzbillings/zlifts`.
6. Consider object storage only after the private-repo flow becomes too limiting.

## References

- GitHub repository visibility: https://docs.github.com/en/repositories/creating-and-managing-repositories/about-repositories
- GitHub Actions secrets: https://docs.github.com/en/actions/reference/security/secrets
- actions/checkout private secondary repositories: https://github.com/actions/checkout
- Google Drive for desktop mirroring/streaming: https://support.google.com/drive/answer/13401938
- Google service-account OAuth: https://developers.google.com/identity/protocols/oauth2/service-account
- Amazon S3 security: https://docs.aws.amazon.com/AmazonS3/latest/userguide/security.html
- Amazon S3 versioning: https://docs.aws.amazon.com/AmazonS3/latest/userguide/versioning-workflows.html
