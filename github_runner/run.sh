#!/usr/bin/with-contenv bashio

# ---------------------------------------------------------------------------
# GitHub Self-Hosted Runner – Home Assistant add-on entrypoint
# ---------------------------------------------------------------------------
# This script reads the add-on options, downloads the GitHub Actions runner
# if it is not already present, configures it, and starts it in the
# foreground so the Supervisor can track its lifecycle.
# ---------------------------------------------------------------------------

PERSISTENT_DATA_DIR="/data"
RUNNER_DIR="${PERSISTENT_DATA_DIR}/runner"
LEGACY_RUNNER_DIR="/home/runner"
RUNNER_VERSION="2.322.0"

# ---------------------------------------------------------------------------
# Read add-on configuration
# ---------------------------------------------------------------------------
REPO_URL=$(bashio::config 'repo_url')
RUNNER_TOKEN=$(bashio::config 'runner_token')
RUNNER_NAME=$(bashio::config 'runner_name')
LABELS=$(bashio::config 'labels')
RUNNER_GROUP=$(bashio::config 'runner_group')
WORK_DIR=$(bashio::config 'work_dir')
REPLACE_EXISTING=$(bashio::config 'replace_existing')

# ---------------------------------------------------------------------------
# Validate required options
# ---------------------------------------------------------------------------
if bashio::var.is_empty "${REPO_URL}"; then
    bashio::log.fatal "Option 'repo_url' must not be empty. Please set it in the add-on configuration."
    exit 1
fi

# ---------------------------------------------------------------------------
# Determine the runner architecture
# ---------------------------------------------------------------------------
MACHINE=$(uname -m)
case "${MACHINE}" in
    x86_64)           RUNNER_ARCH="x64"   ;;
    aarch64)          RUNNER_ARCH="arm64" ;;
    armv7l|armhf)     RUNNER_ARCH="arm"   ;;
    *)
        bashio::log.fatal "Unsupported architecture: ${MACHINE}"
        exit 1
        ;;
esac

bashio::log.info "Detected architecture: ${MACHINE} → runner arch: ${RUNNER_ARCH}"

# ---------------------------------------------------------------------------
# Prepare persistent runner storage
# ---------------------------------------------------------------------------
if ! mkdir -p "${RUNNER_DIR}"; then
    bashio::log.fatal "Cannot create persistent runner directory at ${RUNNER_DIR}."
    exit 1
fi

if [ ! -w "${RUNNER_DIR}" ]; then
    bashio::log.fatal "Persistent runner directory ${RUNNER_DIR} is not writable."
    exit 1
fi

if mountpoint -q "${PERSISTENT_DATA_DIR}" 2>/dev/null; then
    bashio::log.info "Persistent storage is mounted at ${PERSISTENT_DATA_DIR}."
else
    bashio::log.warning "${PERSISTENT_DATA_DIR} is available but not reported as a separate mountpoint."
fi

bashio::log.info "Using persistent runner directory: ${RUNNER_DIR}"

if [ ! -f "${RUNNER_DIR}/config.sh" ] && [ -f "${LEGACY_RUNNER_DIR}/config.sh" ]; then
    bashio::log.info "Migrating existing runner installation from ${LEGACY_RUNNER_DIR} to ${RUNNER_DIR}…"
    cp -a "${LEGACY_RUNNER_DIR}/." "${RUNNER_DIR}/" \
        || { bashio::log.fatal "Failed to migrate runner data to persistent storage."; exit 1; }
fi

if [ -f "${RUNNER_DIR}/.runner" ] && [ -f "${RUNNER_DIR}/.credentials" ]; then
    bashio::log.info "Persisted runner state found in ${RUNNER_DIR}."
else
    bashio::log.info "No persisted runner state found in ${RUNNER_DIR}; initial registration may be required."
fi

# ---------------------------------------------------------------------------
# Install user-defined packages
# ---------------------------------------------------------------------------
if bashio::config.exists 'packages'; then
    PACKAGES_JSON=$(bashio::config 'packages')
    if echo "${PACKAGES_JSON}" | jq -e 'type == "array" and length > 0' >/dev/null 2>&1; then
        if ! command -v apt-get >/dev/null 2>&1; then
            bashio::log.warning "Package installation was requested, but apt-get is not available in this image."
        else
            bashio::log.info "Updating package lists…"
            if ! apt_update_output=$(apt-get update 2>&1); then
                bashio::log.warning "apt-get update failed; skipping runtime package installation: ${apt_update_output}"
            else
                while IFS= read -r package; do
                    [[ -z "${package}" ]] && continue
                    if [[ ! "${package}" =~ ^[a-zA-Z0-9._+\-]+$ ]]; then
                        bashio::log.warning "Package name '${package}' contains invalid characters (skipping)."
                        continue
                    fi
                    bashio::log.info "Installing package '${package}'…"
                    if install_output=$(apt-get install -y --no-install-recommends "${package}" 2>&1); then
                        bashio::log.info "Package '${package}' installed successfully."
                    else
                        bashio::log.warning "Package '${package}' could not be installed due to error (skipping): ${install_output}"
                    fi
                done < <(echo "${PACKAGES_JSON}" | jq -r '.[]')
            fi
        fi
    fi
fi

# ---------------------------------------------------------------------------
# Download and install the runner (only when not already present)
# ---------------------------------------------------------------------------
if [ ! -f "${RUNNER_DIR}/config.sh" ]; then
    RUNNER_PACKAGE="actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz"
    RUNNER_URL="https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${RUNNER_PACKAGE}"

    bashio::log.info "Downloading GitHub Actions runner v${RUNNER_VERSION} (${RUNNER_ARCH})…"
    curl -fsSL -o "/tmp/${RUNNER_PACKAGE}" "${RUNNER_URL}" \
        || { bashio::log.fatal "Failed to download runner package from ${RUNNER_URL}"; exit 1; }

    bashio::log.info "Extracting runner package…"
    tar xzf "/tmp/${RUNNER_PACKAGE}" -C "${RUNNER_DIR}"
    rm -f "/tmp/${RUNNER_PACKAGE}"

    bashio::log.info "Installing runner dependencies…"
    "${RUNNER_DIR}/bin/installdependencies.sh" \
        || bashio::log.warning "installdependencies.sh reported errors – runner may still work."
fi

# ---------------------------------------------------------------------------
# Configure the runner
# ---------------------------------------------------------------------------
cd "${RUNNER_DIR}" || { bashio::log.fatal "Cannot change to runner directory ${RUNNER_DIR}"; exit 1; }

RUNNER_STATE_FILE="${RUNNER_DIR}/.runner"
RUNNER_CREDENTIALS_FILE="${RUNNER_DIR}/.credentials"
RUNNER_ALREADY_CONFIGURED=false

if [ -f "${RUNNER_STATE_FILE}" ] && [ -f "${RUNNER_CREDENTIALS_FILE}" ]; then
    EXISTING_URL=$(jq -r '.gitHubUrl // empty' "${RUNNER_STATE_FILE}" 2>/dev/null || true)
    EXISTING_NAME=$(jq -r '.agentName // empty' "${RUNNER_STATE_FILE}" 2>/dev/null || true)

    if [ "${EXISTING_URL}" = "${REPO_URL}" ] && [ "${EXISTING_NAME}" = "${RUNNER_NAME}" ]; then
        RUNNER_ALREADY_CONFIGURED=true
        bashio::log.info "Existing runner configuration detected for '${RUNNER_NAME}' on ${REPO_URL}; skipping registration."
    else
        bashio::log.warning "Runner state already exists, but it targets '${EXISTING_URL}' with name '${EXISTING_NAME}'."
        bashio::log.fatal "Refusing to re-register over existing runner state automatically. Remove the persisted runner state or align repo_url and runner_name with the existing registration."
        exit 1
    fi
fi

if ! bashio::var.true "${RUNNER_ALREADY_CONFIGURED}"; then
    if bashio::var.is_empty "${RUNNER_TOKEN}"; then
        bashio::log.fatal "Option 'runner_token' must not be empty when the runner is not already configured."
        exit 1
    fi

    CONFIG_ARGS=(
        "--url"        "${REPO_URL}"
        "--token"      "${RUNNER_TOKEN}"
        "--name"       "${RUNNER_NAME}"
        "--labels"     "${LABELS}"
        "--work"       "${WORK_DIR}"
        "--unattended"
    )

    if bashio::var.true "${REPLACE_EXISTING}"; then
        CONFIG_ARGS+=("--replace")
    fi

    if ! bashio::var.is_empty "${RUNNER_GROUP}"; then
        CONFIG_ARGS+=("--runnergroup" "${RUNNER_GROUP}")
    fi

    bashio::log.info "Configuring GitHub Actions runner for ${REPO_URL}…"
    ./config.sh "${CONFIG_ARGS[@]}" \
        || { bashio::log.fatal "Runner configuration failed. Check your repo_url and runner_token."; exit 1; }
fi

# ---------------------------------------------------------------------------
# Start the runner
# ---------------------------------------------------------------------------
bashio::log.info "Starting GitHub Actions runner '${RUNNER_NAME}'…"
exec ./run.sh
