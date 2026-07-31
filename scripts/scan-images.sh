#!/usr/bin/env bash

set -uo pipefail

configuration_file=${1:-config/containers.yml}
output_dir=${2:-reports/vulnerabilities}
trivy_command=${TRIVY_COMMAND:-trivy}
grype_command=${GRYPE_COMMAND:-grype}
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
project_root=$(cd -- "$script_dir/.." && pwd)
ruby_command=${RUBY_COMMAND:-ruby}

if [[ ! -f "$configuration_file" ]]; then
  echo "Container configuration not found: $configuration_file" >&2
  exit 1
fi

image_file=$(mktemp)
trap 'rm -f "$image_file"' EXIT
if ! "$ruby_command" "$project_root/bin/container-statistics" \
  --input "$configuration_file" \
  --images > "$image_file"; then
  echo "Could not expand image references from $configuration_file" >&2
  exit 1
fi

mkdir -p "$output_dir"
manifest="$output_dir/manifest.tsv"
: > "$manifest"

index=0
# Descriptor 3 keeps the image list separate from stdin because a scanner may consume stdin itself.
while IFS= read -r raw_image <&3 || [[ -n "$raw_image" ]]; do
  image=${raw_image#"${raw_image%%[![:space:]]*}"}
  image=${image%"${image##*[![:space:]]}"}
  [[ -z "$image" || "$image" == \#* ]] && continue

  index=$((index + 1))
  printf -v report_id 'image-%03d' "$index"
  printf '%s\t%s\n' "$report_id" "$image" >> "$manifest"

  echo "::group::Trivy: $image"
  if ! "$trivy_command" image \
    --format json \
    --output "$output_dir/$report_id.trivy.json" \
    --scanners vuln \
    --timeout 20m \
    "$image"; then
    printf '{"scan_error":"Trivy could not scan this image."}\n' \
      > "$output_dir/$report_id.trivy.json"
    echo "::warning title=Trivy scan failed::$image"
  fi
  echo "::endgroup::"

  echo "::group::Grype: $image"
  if ! "$grype_command" "$image" \
    --output json \
    --file "$output_dir/$report_id.grype.json"; then
    printf '{"scan_error":"Grype could not scan this image."}\n' \
      > "$output_dir/$report_id.grype.json"
    echo "::warning title=Grype scan failed::$image"
  fi
  echo "::endgroup::"
done 3< "$image_file"

if (( index == 0 )); then
  echo "No tag-specific images are configured."
  exit 0
fi

echo "Scanned $index image(s)."
