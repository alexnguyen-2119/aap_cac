#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
env_file="${script_dir}/.env"
inventory_file="${script_dir}/inventory/site2.ini"
playbook_file="${script_dir}/configure_aap.yml"

require_var() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required environment variable: ${name}" >&2
    exit 1
  fi
}

load_env_file() {
  local file="$1"
  local line key value trimmed
  local line_no=0

  while IFS= read -r line || [[ -n "$line" ]]; do
    line_no=$((line_no + 1))

    trimmed="${line#"${line%%[![:space:]]*}"}"
    if [[ -z "$trimmed" || "${trimmed:0:1}" == "#" ]]; then
      continue
    fi

    if [[ "$trimmed" == export[[:space:]]* ]]; then
      trimmed="${trimmed#export }"
      trimmed="${trimmed#"${trimmed%%[![:space:]]*}"}"
    fi

    if [[ "$trimmed" != *=* ]]; then
      echo "Invalid line in ${file}:${line_no}. Expected KEY=VALUE format." >&2
      exit 1
    fi

    key="${trimmed%%=*}"
    value="${trimmed#*=}"

    key="${key%"${key##*[![:space:]]}"}"
    key="${key#"${key%%[![:space:]]*}"}"
    value="${value#"${value%%[![:space:]]*}"}"

    if [[ ! "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
      echo "Invalid variable name '${key}' in ${file}:${line_no}." >&2
      exit 1
    fi

    case "$key" in
      ANSIBLE_CONFIG|BASH_ENV|ENV|SHELLOPTS|CDPATH|GLOBIGNORE|LD_*|DYLD_*)
        echo "Refusing to load dangerous variable '${key}' from ${file}:${line_no}." >&2
        exit 1
        ;;
    esac

    if [[ "$value" =~ ^\".*\"$ ]] || [[ "$value" =~ ^\'.*\'$ ]]; then
      value="${value:1:${#value}-2}"
    fi

    export "$key=$value"
  done < "$file"
}

cd "${script_dir}"

if [[ -f "${env_file}" ]]; then
  load_env_file "${env_file}"
else
  echo "${env_file} not found; using existing process environment." >&2
fi

require_var "AAP_USERNAME"
require_var "AAP_PASSWORD"
require_var "LDAP_BIND_PASSWORD"
require_var "AAP_VALIDATE_CERTS"
require_var "AAP_SYSTEM_SITE2_HUB_TOKEN"


ansible-playbook -i $inventory_file $playbook_file "$@"