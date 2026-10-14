#!/usr/bin/env bash
set -Eeuo pipefail

WORKSPACE=/workspace
ARTIFACT_ROOT=/artifacts
LOG_DIR="$ARTIFACT_ROOT/logs"
VIPM_DEB_URL="https://traffic.libsyn.com/secure/jkinc/vipm_26.3.1-4025_amd64.deb"
VIPM_DESKTOP_LIVELINESS_TIMEOUT="${VIPM_DESKTOP_LIVELINESS_TIMEOUT:-300}"
XVFB_PID=""

mkdir -p "$LOG_DIR" "$ARTIFACT_ROOT/VI Package" "$ARTIFACT_ROOT/tmp"

redact_secrets() {
    local file="$1"
    [[ -f "$file" ]] || return 0
    perl -0777 -i -pe '
        for my $key (qw(VIPM_SERIAL_NUMBER VIPM_FULL_NAME VIPM_EMAIL)) {
            my $value = $ENV{$key};
            next unless defined($value) && length($value);
            s/\Q$value\E/[REDACTED]/g;
        }
    ' "$file"
}

collect_diagnostics() {
    local status="${1:-unknown}"
    local base
    local index=0
    {
        printf 'timestamp: %s\n' "$(date --iso-8601=seconds 2>/dev/null || date)"
        printf 'exit status: %s\n' "$status"
        printf 'display: %s\n' "${DISPLAY:-unset}"
        printf 'LabVIEW version: %s\n' "${LABVIEW_VERSION:-unset}"
        printf '\n-- OS --\n'
        cat /etc/os-release 2>/dev/null || true
        printf '\n-- memory --\n'
        free -h 2>/dev/null || true
        printf '\n-- disk --\n'
        df -h "$WORKSPACE" "$ARTIFACT_ROOT" /tmp 2>/dev/null || true
        printf '\n-- VIPM/LabVIEW processes --\n'
        ps -eo pid,ppid,stat,etime,comm 2>/dev/null | grep -iE 'vipm|labview|xvfb' || true
        printf '\n-- Xvfb log --\n'
        tail -n 100 "$LOG_DIR/xvfb.log" 2>/dev/null || true
    } > "$LOG_DIR/diagnostics.log"

    mkdir -p "$LOG_DIR/vipm-desktop-logs"
    for base in "$HOME/.config/JKI/VIPM" "$HOME/.local/share/JKI/VIPM" "$HOME/.cache/JKI/VIPM" /var/log/JKI/VIPM; do
        [[ -d "$base" ]] || continue
        while IFS= read -r -d '' file; do
            index=$((index + 1))
            cp "$file" "$LOG_DIR/vipm-desktop-logs/vipm-${index}.log" 2>/dev/null || true
        done < <(find "$base" -type f -iname '*.log' -print0 2>/dev/null)
    done
}

on_exit() {
    local status=$?
    collect_diagnostics "$status" || true
    while IFS= read -r -d '' file; do
        redact_secrets "$file" || true
    done < <(find "$LOG_DIR" -type f -print0 2>/dev/null)
    if [[ -n "$XVFB_PID" ]]; then
        kill "$XVFB_PID" 2>/dev/null || true
    fi
    return "$status"
}
trap on_exit EXIT

run_logged() {
    local name="$1"
    local timeout_seconds="$2"
    local log_file="$LOG_DIR/${name}.log"
    local status
    shift 2
    printf '\n[%s] Running %s (timeout %ss)\n' "$(date --iso-8601=seconds 2>/dev/null || date)" "$name" "$timeout_seconds"
    set +e
    timeout --signal=TERM --kill-after=30s "${timeout_seconds}s" "$@" 2>&1 | tee "$log_file"
    status=${PIPESTATUS[0]}
    set -e
    redact_secrets "$log_file"
    if (( status != 0 )); then
        printf '[%s] failed with exit status %s\n' "$name" "$status" >&2
        return "$status"
    fi
}

if [[ "$(id -u)" -ne 0 ]]; then
    echo 'The NI container helper must run as root to install VIPM.' >&2
    exit 1
fi
for name in LABVIEW_VERSION VIPM_SERIAL_NUMBER VIPM_FULL_NAME VIPM_EMAIL; do
    if [[ -z "${!name:-}" ]]; then
        echo "Required environment variable $name is missing." >&2
        exit 1
    fi
done
if [[ ! "$LABVIEW_VERSION" =~ ^([0-9]{4})q([13])$ ]]; then
    echo "Unsupported LabVIEW version '$LABVIEW_VERSION'; expected YYYYq1 or YYYYq3." >&2
    exit 1
fi
LV_YEAR="${BASH_REMATCH[1]}"
LV_QUARTER="${BASH_REMATCH[2]}"
LV_NUMERIC_VERSION="$((LV_YEAR - 2000)).${LV_QUARTER}"
export LV_YEAR LV_QUARTER LV_NUMERIC_VERSION
export DISPLAY=:99
export VIPM_NONINTERACTIVE=1
export VIPM_DEBUG=1
export VIPM_TIMEOUT=900
export VIPM_DESKTOP_LIVELINESS_TIMEOUT
export VIPM_LABVIEW_LAUNCH_TIMEOUT=300

run_logged apt-update 600 apt-get update
run_logged apt-install 900 apt-get install -y --no-install-recommends ca-certificates curl perl procps python3 x11-utils xvfb

mkdir -p /tmp/natinst
printf '1\n' > /tmp/natinst/LVContainer.txt
Xvfb :99 -screen 0 1280x720x24 -ac +extension GLX +render -noreset > "$LOG_DIR/xvfb.log" 2>&1 &
XVFB_PID=$!
for attempt in $(seq 1 30); do
    if xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then break; fi
    if ! kill -0 "$XVFB_PID" 2>/dev/null; then
        cat "$LOG_DIR/xvfb.log" >&2 || true
        echo 'Xvfb exited before the headless display became ready.' >&2
        exit 1
    fi
    sleep 1
done
if ! xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then
    echo 'Xvfb did not become ready within 30 seconds.' >&2
    exit 1
fi

run_logged vipm-download 900 curl --fail --location --retry 3 --retry-all-errors --output /tmp/vipm.deb "$VIPM_DEB_URL"
if ! run_logged vipm-dpkg-install 900 dpkg -i /tmp/vipm.deb; then
    run_logged apt-repair 900 apt-get -f install -y
    run_logged vipm-dpkg-install-retry 900 dpkg -i /tmp/vipm.deb
fi
if ! command -v vipm >/dev/null 2>&1; then
    echo 'VIPM CLI was not found on PATH after installing its Debian package.' >&2
    exit 1
fi
dpkg-query -W -f='${Package} ${Version}\n' vipm | tee "$LOG_DIR/vipm-version.log"

activation_log="$LOG_DIR/vipm-activation.log"
if timeout --signal=TERM --kill-after=30s 600s vipm activate --serial-number "$VIPM_SERIAL_NUMBER" --name "$VIPM_FULL_NAME" --email "$VIPM_EMAIL" > "$activation_log" 2>&1; then
    activation_status=0
else
    activation_status=$?
fi
redact_secrets "$activation_log"
cat "$activation_log"
if (( activation_status != 0 )); then
    printf 'VIPM Pro activation failed with exit status %s.\n' "$activation_status" >&2
    exit "$activation_status"
fi

if ! run_logged vipm-refresh 900 vipm refresh --verbose; then
    echo 'VIPM refresh failed; retrying once after a short delay.' >&2
    sleep 30
    run_logged vipm-refresh-retry 900 vipm refresh --verbose
fi

manifest="$WORKSPACE/Tooling/deployment/runner_dependencies.toml"
if [[ ! -f "$manifest" ]]; then
    echo "Dependency manifest not found: $manifest" >&2
    exit 1
fi
linux_manifest="$LOG_DIR/runner_dependencies.linux.toml"
optional_log="$LOG_DIR/vipm-optional-dependencies.log"
: > "$optional_log"
# These G-CLI extensions are not needed by the direct VIPM build; no PPL is built here.
for package in jki_lib_vipm_api sas_workshops_lib_lvbuildspec_for_g_cli sas_workshops_lib_vipb_builder_for_g_cli; do
    if grep -Eq "^${package}[[:space:]]*=" "$manifest"; then
        printf 'Skipping non-required build tooling dependency: %s\n' "$package" | tee -a "$optional_log"
    fi
done
awk '
    /^(jki_lib_vipm_api|sas_workshops_lib_lvbuildspec_for_g_cli|sas_workshops_lib_vipb_builder_for_g_cli)[[:space:]]*=/ { next }
    { print }
' "$manifest" > "$linux_manifest"
if ! run_logged vipm-dependencies 1800 vipm install "$linux_manifest" --labview-version "$LV_YEAR" --labview-bitness 64 --verbose; then
    echo 'Dependency installation failed or timed out; capturing diagnostics and retrying once.' >&2
    collect_diagnostics 'dependency-install-first-attempt'
    sleep 30
    run_logged vipm-dependencies-retry 1800 vipm install "$linux_manifest" --labview-version "$LV_YEAR" --labview-bitness 64 --verbose
fi

vipb_source="$WORKSPACE/Core/Actor Framework 2024 for 2020.vipb"
staged_core="$ARTIFACT_ROOT/tmp/Core"
vipb_output="$staged_core/Actor Framework Linux.ci.vipb"
vipb_log="$LOG_DIR/vipb-preparation.log"
if [[ ! -d "$WORKSPACE/Core" ]]; then
    echo 'Core source directory is missing: Core' >&2
    exit 1
fi
if [[ -e "$staged_core" ]]; then
    echo "Temporary Core staging directory already exists: $staged_core" >&2
    exit 1
fi
cp -a "$WORKSPACE/Core" "$ARTIFACT_ROOT/tmp/"
if ! python3 - "$vipb_source" "$vipb_output" "$LV_NUMERIC_VERSION" > "$vipb_log" 2>&1 <<'PY'
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

source, output, labview_version = sys.argv[1:]
source = Path(source)
output = Path(output)
if not source.is_file():
    raise FileNotFoundError(f"Tracked Core VIPB not found: {source}")

tree = ET.parse(source)
root = tree.getroot()

def require_node(parent, path):
    node = parent.find(path)
    if node is None:
        raise ValueError(f"Required VIPB XML node is missing: {path}")
    return node

general = require_node(root, "Library_General_Settings")
require_node(general, "Library_Source_Folder").text = "."
require_node(general, "Library_Output_Folder").text = "/artifacts/VI Package"
require_node(general, "Package_LabVIEW_Version").text = f"{labview_version} (64-bit)"
require_node(root, "Advanced_Settings/Install_Requirements/LV_32-Bit").text = "false"
require_node(root, "Advanced_Settings/Install_Requirements/LV_64-Bit").text = "true"
require_node(root, "Advanced_Settings/VI_Package_Configuration_File").text = ""
require_node(root, "Advanced_Settings/License_Agreement_Filepath").text = "/workspace/LICENSE.txt"

output.parent.mkdir(parents=True, exist_ok=True)
ET.indent(tree, space="  ")
tree.write(output, encoding="utf-8", xml_declaration=True)
print(f"Prepared temporary VIPB: {output}")
print("Staged source root: " + str(source.parent))
print("Preserved Core-relative VIPB source paths.")
print("LabVIEW target: " + labview_version + " (64-bit)")
print("Removed missing VIPC reference from the temporary copy.")
PY
then
    cat "$vipb_log" >&2
    exit 1
fi
cat "$vipb_log"

run_logged vipm-build 1800 vipm build "$vipb_output" --labview-version "$LV_YEAR" --labview-bitness 64 --timeout 900 --verbose
shopt -s nullglob
vip_files=("$ARTIFACT_ROOT/VI Package/"*.vip)
if (( ${#vip_files[@]} == 0 )); then
    echo 'VIPM reported success but produced no .vip under the artifact output directory.' >&2
    exit 1
fi
printf 'Built VIP package(s):\n'
printf '  %s\n' "${vip_files[@]}"