#!/usr/bin/env bash

set -euo pipefail

if [ "${PULP_DEBUG:-0}" = "1" ]; then
  set -x
fi

require_pulp_credentials() {
  : "${PULP_USERNAME:?PULP_USERNAME variable is required}"
  : "${PULP_PASSWORD:?PULP_PASSWORD secret is required}"
  : "${PULP_BASE_URL:?PULP_BASE_URL variable is required}"
}

run_pulp() {
  require_pulp_credentials

  # Avoid printing credentials when xtrace is enabled.
  local had_xtrace=0
  local rc=0
  case "$-" in
    *x*)
      had_xtrace=1
      set +x
      ;;
  esac

  if pulp \
    --base-url "${PULP_BASE_URL}" \
    --username "${PULP_USERNAME}" \
    --password "${PULP_PASSWORD}" \
    "$@"; then
    rc=0
  else
    rc=$?
  fi

  if [ "${had_xtrace}" -eq 1 ]; then
    set -x
  fi

  return "${rc}"
}

pulp_upload_package() {
  local package_file="${1}"
  local repository="${2}"

  # Some pulp-cli versions require content type selection (-t package),
  # while others expose upload directly under `content upload`.
  echo "DEBUG: probing command support: pulp rpm content -t package upload --help"
  if run_pulp rpm content -t package upload --help >/dev/null 2>&1; then
    echo "DEBUG: running: pulp rpm content -t package upload --file \"${package_file}\" --repository \"${repository}\" --no-publish"
    run_pulp rpm content -t package upload \
      --file "${package_file}" \
      --repository "${repository}" \
      --no-publish
    return 0
  fi

  echo "DEBUG: fallback command selected"
  echo "DEBUG: running: pulp rpm content upload --file \"${package_file}\" --repository \"${repository}\" --no-publish"
  run_pulp rpm content upload \
    --file "${package_file}" \
    --repository "${repository}" \
    --no-publish
}

upload_packages() {
  local search_dir="${1}"
  local file_pattern="${2}"
  local repository="${3}"
  local label="${4}"
  local target_arch="${5:-}"
  local skip_noarch_non_x86="${6:-false}"

  mapfile -t package_files < <(find "${search_dir}" -type f -name "${file_pattern}" | sort)
  if [ "${#package_files[@]}" -eq 0 ]; then
    echo "No ${label} files found under ${search_dir}"
    exit 1
  fi

  local upload_count=0
  for package_file in "${package_files[@]}"; do
    if [ "${skip_noarch_non_x86}" = "true" ] \
      && [ -n "${target_arch}" ] \
      && [ "${target_arch}" != "x86_64" ] \
      && [[ "${package_file}" == *.noarch.rpm ]]; then
      echo "Skipping duplicate noarch upload on ${target_arch}: ${package_file}"
      continue
    fi

    echo "Uploading ${label}: ${package_file}"
    pulp_upload_package "${package_file}" "${repository}"
    upload_count=$((upload_count + 1))
  done

  if [ "${upload_count}" -eq 0 ]; then
    echo "No ${label} files selected for upload under ${search_dir}"
    exit 1
  fi
}

publish_repository() {
  local repository="${1}"
  echo "Publishing repository: ${repository}"

  run_pulp rpm publication create --repository "${repository}"
}
