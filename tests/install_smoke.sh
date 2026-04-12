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
  nlt-pip-sources nlt-python-env nlt-utils nlt-github-net nlt-services \
  nlt-airflow-install nlt-airflow \
  nlt-service-airflow-start nlt-service-airflow-stop \
  nlt-service-airflow-restart nlt-service-airflow-status \
  nlt-service-airflow-update \
  nlt-celery-install nlt-celery-update \
  nlt-service-celery-worker-start nlt-service-celery-beat-start \
  nlt-service-celery-flower-start nlt-service-celery-stop \
  nlt-service-celery-restart nlt-service-celery-status \
  nlt-paperclip-install nlt-paperclip \
  nlt-service-paperclip-start nlt-service-paperclip-stop \
  nlt-service-paperclip-restart nlt-service-paperclip-status \
  nlt-service-paperclip-update \
  nlt-code-server-install nlt-code-server \
  nlt-service-code-server-start nlt-service-code-server-stop \
  nlt-service-code-server-restart nlt-service-code-server-status \
  nlt-service-code-server-update \
  nlt-new-api-install nlt-new-api \
  nlt-service-new-api-start nlt-service-new-api-stop \
  nlt-service-new-api-restart nlt-service-new-api-status \
  nlt-service-new-api-update
do
  [[ -x "${NLTDEPLOY_ROOT}/bin/${f}" ]] || { echo "missing: bin/${f}" >&2; exit 1; }
  bash -n "${NLTDEPLOY_ROOT}/bin/${f}" || exit 1
done
bash -n "${NLTDEPLOY_ROOT}/libexec/nltdeploy/airflow/deploy.sh" || exit 1
bash -n "${NLTDEPLOY_ROOT}/libexec/nltdeploy/code-server/code-server-setup.sh" || exit 1
bash -n "${NLTDEPLOY_ROOT}/libexec/nltdeploy/new-api/new-api-setup.sh" || exit 1
bash -n "${NLTDEPLOY_ROOT}/libexec/nltdeploy/services/services.sh" || exit 1
"${NLTDEPLOY_ROOT}/bin/nlt-services" status --no-http >/dev/null || exit 1
echo "install_smoke OK"
