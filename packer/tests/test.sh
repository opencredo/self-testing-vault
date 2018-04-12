#!/usr/bin/env bash

# Simple script used to spin up infrastructure used to test the Packer image and then destroy it again.

# Based on a template by BASH3 Boilerplate v2.3.0
# http://bash3boilerplate.sh/#authors

# Exit on error. Append "|| true" if you expect an error.
set -o errexit
# Exit on error inside any functions or subshells.
set -o errtrace
# Do not allow use of undefined vars. Use ${VAR:-} to use an undefined VAR
set -o nounset
# Catch the error in case mysqldump fails (but gzip succeeds) in `mysqldump |gzip`
set -o pipefail
# Turn on traces, useful while debugging but commented out by default
# set -o xtrace

ami=${1}

current_directory=$(dirname "${BASH_SOURCE[0]}")

function terraform_clean {
  exit_status=$?
  terraform destroy -var "artifact_under_test=DELETING" -var "unique_identifier=DELETING" -var "ip_address=1.1.1.1" -force
  popd
  exit ${exit_status}
}

pushd ${current_directory}

trap terraform_clean INT TERM EXIT

terraform apply -auto-approve -var "artifact_under_test=${ami}" -var "unique_identifier=$(whoami)" -var "ip_address=$(curl -f -s icanhazip.com)"
