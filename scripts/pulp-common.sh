#!/usr/bin/env bash

set -euo pipefail

json_get_field() {
  local field="${1}"
  python3 -c 'import json,sys; f=sys.argv[1]; print(json.load(sys.stdin).get(f, ""))' "${field}"
}

get_task_state() {
  local task_id="${1}"
  pulp task show --task "${task_id}" --output json | json_get_field state
}

configure_pulp_cli() {
  : "${PULP_USERNAME:?PULP_USERNAME variable is required}"
  : "${PULP_PASSWORD:?PULP_PASSWORD secret is required}"
  : "${PULP_BASE_URL:?PULP_BASE_URL variable is required}"

  pulp config create \
    --base-url "${PULP_BASE_URL}" \
    --username "${PULP_USERNAME}" \
    --password "${PULP_PASSWORD}"
}

wait_for_task_completion() {
  local task_id="${1}"
  local subject="${2}"

  if [ -z "${task_id}" ]; then
    echo "Failed to parse task id for ${subject}"
    exit 1
  fi

  pulp task wait --task "${task_id}"
  local status
  status="$(get_task_state "${task_id}")"

  if [ "${status}" != "completed" ]; then
    echo "Task failed for ${subject} (task: ${task_id}, status: ${status})"
    exit 1
  fi
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
    local task
    task="$(
      pulp rpm content -t package upload \
        --file "${package_file}" \
        --repository "${repository}" \
        --no-publish \
        --output json | json_get_field task
    )"

    wait_for_task_completion "${task}" "${package_file}"
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

  local task
  task="$(
    pulp rpm publication create \
      --repository "${repository}" \
      --output json | json_get_field task
  )"

  wait_for_task_completion "${task}" "publication ${repository}"
}
