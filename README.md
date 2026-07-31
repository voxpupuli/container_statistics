# container statistics

This repository collects statistics for configured container packages and images, builds a searchable HTML report,
and publishes it to GitHub Pages.

The project is intentionally not tied to one metric or registry.
It currently reports registry download totals and Trivy/Grype vulnerability findings.
Statistics modules, registry providers, scanner inputs, and report rendering are kept separate so that new topics and
sources can be added independently.

The Ruby implementation uses only the standard library.
Trivy and Grype remain external tools because they own vulnerability detection and advisory databases.

## Configuration

[`config/containers.yml`](config/containers.yml) is the shared inventory for package-level and tag-specific
statistics:

```yaml
---
containers:
  - name: voxpupuli/voxbox
    registry: ghcr.io
    tags:
      - latest
```

`registry` and `name` form the package reference used for download statistics.
Each entry in `tags` creates an image reference used for vulnerability scans.
An omitted or empty `tags` array enables package statistics without creating a vulnerability scan target.

Print the expanded image references without making network requests:

```console
bin/container-statistics --images
```

## Available statistics

### Downloads

GitHub does not expose download totals for `ghcr.io` packages through its public REST or GraphQL APIs.
The downloads module therefore reads the total count from each public GitHub package page.
Counts are totals since a package or version was created; this version does not store historical snapshots.

Downloads are collected once per package, regardless of how many tags are configured for vulnerability scanning.
Successful download lookups are cached in `.cache/downloads.json` for 24 hours.
Use `--download-cache` to select a different cache file.

### Vulnerabilities

Trivy and Grype scan every configured tag and write JSON results.
The Ruby vulnerabilities module adds both scanner summaries and searchable finding details to the shared report.

Grype findings from the `nvd:cpe` namespace are excluded from normal vulnerability totals because broad CPE matching
can produce unconfirmed matches for distribution packages.
They remain visible and searchable in a separate collapsed section.

An unavailable image or individual scanner failure is shown in the report without discarding other statistics.
Vulnerabilities do not fail the workflow because this project is a reporting dashboard rather than a deployment gate.

## Run locally

Generate the HTML report from the configured containers and the scanner results in
`reports/vulnerabilities`:

```console
bin/container-statistics
```

Create or refresh the scanner results before generating the report:

```console
scripts/scan-images.sh config/containers.yml reports/vulnerabilities
bin/container-statistics
```

The self-contained report is written to `report/index.html`.
Use `--input`, `--output`, and `--vulnerability-reports` to select different paths.

Use `--download-report` to print only package names and total download counts to the terminal:

```console
bin/container-statistics --download-report
```

Use `--cve-report` to print each configured image and its unique confirmed CVE counts by severity.
This reads the local scanner results and does not request download statistics from GitHub:

```console
bin/container-statistics --cve-report
```

Run the automated tests with the RVM-managed Ruby configured for the repository:

```console
ruby -Itest -e 'Dir["test/**/*_test.rb"].sort.each { |file| require_relative file }'
test/scan_images_test.sh
```

## GitHub Pages

In **Settings → Pages → Build and deployment**, select **GitHub Actions** as the source.
The statistics workflow runs daily, on relevant changes to `main`, or manually with optional replacement YAML.

For images in a private registry, create all three optional secrets:

- `REGISTRY`: registry hostname, for example `ghcr.io`
- `REGISTRY_USERNAME`: registry user
- `REGISTRY_PASSWORD`: registry token or password

The GitHub download provider currently supports public package pages.
Raw scanner JSON files are not included in the GitHub Pages artifact.

## Architecture

Statistics and providers have different responsibilities:

- A statistic defines which information is collected and normalizes it for the report.
- A provider retrieves registry-specific source data needed by a statistic.
- The YAML configuration separates package references from tag-specific image references.
- The CLI registers enabled statistics and assembles the package/image hierarchy.
- The report renders normalized statistics without knowing their source API or scanner format.

To add another topic, implement a class under `lib/container_statistics/statistics/` and register it in
`bin/container-statistics`.
[`downloads.rb`](lib/container_statistics/statistics/downloads.rb) and
[`vulnerabilities.rb`](lib/container_statistics/statistics/vulnerabilities.rb) are the current implementations.

To source download data from another registry, add a provider implementing `name`, `supports?(image)`, and
`download_statistics(image)`.
The existing
[`github_container_registry.rb`](lib/container_statistics/providers/github_container_registry.rb) adapter is the
reference implementation for a future Docker Hub provider.

## AI-assisted development

Large parts of this repository were developed with the assistance of a large language model (LLM).
LLM-assisted changes should be reviewed and tested with the same care as any other contribution.

## License

This project is licensed under the GNU Affero General Public License v3.0 or later.
