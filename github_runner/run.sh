#!/usr/bin/with-contenv bashio

# ---------------------------------------------------------------------------
# GitHub Self-Hosted Runner – Home Assistant add-on entrypoint
# ---------------------------------------------------------------------------
# This script reads the add-on options, downloads the GitHub Actions runner
# if it is not already present, configures it, and starts it in the
# foreground so the Supervisor can track its lifecycle.
# ---------------------------------------------------------------------------

RUNNER_DIR="/home/runner"
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

if bashio::var.is_empty "${RUNNER_TOKEN}"; then
    bashio::log.fatal "Option 'runner_token' must not be empty. Please generate a registration token from GitHub and set it here."
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

# ---------------------------------------------------------------------------
# Start the runner
# ---------------------------------------------------------------------------
bashio::log.info "Starting GitHub Actions runner '${RUNNER_NAME}'…"
exec ./run.sh
