#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT
export NLTDEPLOY_ROOT="${TMP}/nd"
export NLTDEPLOY_SKIP_PROFILE_HINT=1
export NLTDEPLOY_SKIP_GIT_PULL=1
bash "${ROOT}/install.sh" install
bash "${ROOT}/install.sh" update
for f in \
  nlt-pip-sources nlt-python-env nlt-utils nlt-github-net nlt-services \
  nlt-airflow-install nlt-airflow nlt-service-airflow \
  nlt-celery-install nlt-celery-update nlt-service-celery \
  nlt-paperclip-install nlt-paperclip nlt-service-paperclip \
  nlt-code-server-install nlt-code-server nlt-service-code-server \
  nlt-new-api-install nlt-new-api nlt-service-new-api
do
  [[ -x "${NLTDEPLOY_ROOT}/bin/${f}" ]] || { echo "missing: bin/${f}" >&2; exit 1; }
  bash -n "${NLTDEPLOY_ROOT}/bin/${f}" || exit 1
done
bash -n "${NLTDEPLOY_ROOT}/libexec/nltdeploy/airflow/setup.sh" || exit 1
bash -n "${NLTDEPLOY_ROOT}/libexec/nltdeploy/code-server/setup.sh" || exit 1
bash -n "${NLTDEPLOY_ROOT}/libexec/nltdeploy/new-api/setup.sh" || exit 1
bash -n "${NLTDEPLOY_ROOT}/libexec/nltdeploy/services/nlt-services.sh" || exit 1
"${NLTDEPLOY_ROOT}/bin/nlt-services" status --no-http >/dev/null || exit 1
echo "install_smoke OK"
