#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT
export NLTDEPLOY_ROOT="${TMP}/nd"
export NLTDEPLOY_SKIP_PROFILE_HINT=1
export NLTDEPLOY_SKIP_GIT_PULL=1
bash "${ROOT}/install.sh"
bash "${ROOT}/install.sh" update
for f in \
  nlt-pip-sources nlt-python-env nlt-utils nlt-github-net \
  nlt-airflow-install nlt-airflow \
  nlt-service-airflow-start nlt-service-airflow-stop \
  nlt-service-airflow-restart nlt-service-airflow-status \
  nlt-service-airflow-update \
  nlt-celery-install nlt-celery-update \
  nlt-service-celery-worker-start nlt-service-celery-beat-start \
  nlt-service-celery-flower-start nlt-service-celery-stop \
  nlt-service-celery-restart nlt-service-celery-status
do
  [[ -x "${NLTDEPLOY_ROOT}/bin/${f}" ]] || { echo "missing: bin/${f}" >&2; exit 1; }
  bash -n "${NLTDEPLOY_ROOT}/bin/${f}" || exit 1
done
bash -n "${NLTDEPLOY_ROOT}/libexec/nltdeploy/airflow/deploy.sh" || exit 1
echo "install_smoke OK"
