#!/usr/bin/env bash

set -euo pipefail

temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT

cp test/fixtures/containers.yml "$temporary_directory/containers.yml"

TRIVY_COMMAND=test/fixtures/failing-scanner.sh \
GRYPE_COMMAND=test/fixtures/failing-scanner.sh \
  scripts/scan-images.sh "$temporary_directory/containers.yml" "$temporary_directory/reports"

grep -q '"scan_error":"Trivy could not scan this image."' \
  "$temporary_directory/reports/image-001.trivy.json"
grep -q '"scan_error":"Grype could not scan this image."' \
  "$temporary_directory/reports/image-001.grype.json"

grep -q $'image-001\texample.test/example/service:1.0' "$temporary_directory/reports/manifest.tsv"
grep -q $'image-002\texample.test/example/worker:2.0' "$temporary_directory/reports/manifest.tsv"
grep -q $'image-003\texample.test/example/frontend:3.0' "$temporary_directory/reports/manifest.tsv"

test -f "$temporary_directory/reports/image-002.trivy.json"
test -f "$temporary_directory/reports/image-002.grype.json"
test -f "$temporary_directory/reports/image-003.trivy.json"
test -f "$temporary_directory/reports/image-003.grype.json"

cp test/fixtures/containers-without-tags.yml "$temporary_directory/containers-without-tags.yml"
scripts/scan-images.sh "$temporary_directory/containers-without-tags.yml" "$temporary_directory/empty-reports"
test ! -s "$temporary_directory/empty-reports/manifest.tsv"
