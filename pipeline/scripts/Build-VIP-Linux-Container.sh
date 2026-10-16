#!/usr/bin/env bash
set -Eeuo pipefail

WORKSPACE=/build-inputs
DISTRIBUTION=/distribution
ARTIFACT_ROOT=/artifacts
LOG_DIR="$ARTIFACT_ROOT/logs"
VIPM_DEB_URL="https://traffic.libsyn.com/secure/jkinc/vipm_26.3.1-4025_amd64.deb"
VIPM_DESKTOP_LIVELINESS_TIMEOUT="${VIPM_DESKTOP_LIVELINESS_TIMEOUT:-300}"
XVFB_PID=""

mkdir -p "$LOG_DIR" "$ARTIFACT_ROOT/Builds" "$ARTIFACT_ROOT/tmp"

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

LV_ROOT="/usr/local/natinst/LabVIEW-${LV_YEAR}-64"
install_distribution() {
    local relative_path
    local folder
    [[ -d "$LV_ROOT/vi.lib" ]] || { echo "LabVIEW root not found: $LV_ROOT" >&2; return 1; }
    for relative_path in 'vi.lib/ActorFramework/Actor Framework.lvlib' 'resource/AFDebug/AF Debug.lvlib'; do
        [[ -f "$DISTRIBUTION/$relative_path" ]] || { echo "Distribution file missing: $relative_path" >&2; return 1; }
    done
    for relative_path in vi.lib/ActorFramework resource/AFDebug; do
        if [[ -e "$LV_ROOT/$relative_path" ]]; then
            mv "$LV_ROOT/$relative_path" "/tmp/af-original-$(basename "$relative_path")"
        fi
    done
    for folder in vi.lib resource menus; do
        [[ -d "$DISTRIBUTION/$folder" ]] || { echo "Distribution folder missing: $folder" >&2; return 1; }
        mkdir -p "$LV_ROOT/$folder"
        cp -a "$DISTRIBUTION/$folder/." "$LV_ROOT/$folder/"
    done
    diff -qr "$DISTRIBUTION/vi.lib/ActorFramework" "$LV_ROOT/vi.lib/ActorFramework"
    diff -qr "$DISTRIBUTION/resource/AFDebug" "$LV_ROOT/resource/AFDebug"
    cp -a "$WORKSPACE/Core/Install Support" "$LV_ROOT/"
    printf 'Installed distribution at %s; no source-reference rewriting performed.\n' "$LV_ROOT"
}

replacement_log="$LOG_DIR/distribution-install.log"
install_distribution > "$replacement_log" 2>&1
cat "$replacement_log"

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
# The direct VIPM build does not use the G-CLI VIPB/VIPC plugins or their VIPM API.
for package in jki_lib_vipm_api sas_workshops_lib_lvbuildspec_for_g_cli sas_workshops_lib_vipb_builder_for_g_cli sas_workshops_lib_vipc_applier_for_g_cli wiresmith_technology_lib_g_cli; do
    if grep -Eq "^${package}[[:space:]]*=" "$manifest"; then
        printf 'Skipping G-CLI-only dependency for direct VIPM build: %s\n' "$package" | tee -a "$optional_log"
    fi
done
awk '
    /^(jki_lib_vipm_api|sas_workshops_lib_lvbuildspec_for_g_cli|sas_workshops_lib_vipb_builder_for_g_cli|sas_workshops_lib_vipc_applier_for_g_cli|wiresmith_technology_lib_g_cli)[[:space:]]*=/ { next }
    { print }
' "$manifest" > "$linux_manifest"
if ! run_logged vipm-dependencies 1800 vipm install "$linux_manifest" --labview-version "$LV_YEAR" --labview-bitness 64 --verbose; then
    echo 'Dependency installation failed or timed out; capturing diagnostics and retrying once.' >&2
    collect_diagnostics 'dependency-install-first-attempt'
    sleep 30
    if ! run_logged vipm-dependencies-retry 1800 vipm install "$linux_manifest" --labview-version "$LV_YEAR" --labview-bitness 64 --verbose; then
        echo 'WARNING: VIPM dependency installation failed after retry; continuing to vipm build.' >&2
        collect_diagnostics 'dependency-install-warning-continuing'
    fi
fi

labview_cli="$(command -v LabVIEWCLI || true)"
if [[ -z "$labview_cli" ]]; then
    labview_cli="$(find /usr/local/natinst -type f -name LabVIEWCLI -perm /111 -print -quit)"
fi
if [[ -z "$labview_cli" ]]; then
    echo 'LabVIEWCLI executable not found; cannot mass compile the installed distribution.' >&2
    exit 1
fi
run_logged mass-compile 1800 "$labview_cli" -LabVIEWPath "$LV_ROOT/labviewprofull" -OperationName MassCompile -DirectoryToCompile "$LV_ROOT/vi.lib/ActorFramework" -MassCompileLogFile "$LOG_DIR/actor-framework-masscompile.log" -Headless

vipb_source="$WORKSPACE/Core/Actor Framework 2024 for 2020.vipb"
vipb_output="$LOG_DIR/Actor Framework Distribution.vipb"
python3 - "$vipb_source" "$vipb_output" "$LV_ROOT" "$DISTRIBUTION" > "$LOG_DIR/vipb-preparation.log" 2>&1 <<'PY'
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

source, output, installed, distribution = map(Path, sys.argv[1:])
tree = ET.parse(source)
root = tree.getroot()
general = root.find("Library_General_Settings")
general.find("Library_Source_Folder").text = str(installed)
general.find("Library_Output_Folder").text = "/artifacts/Builds"
advanced = root.find("Advanced_Settings")
advanced.find("License_Agreement_Filepath").text = "/build-inputs/LICENSE.txt"
advanced.find("VI_Package_Configuration_File").text = ""
for action in advanced.find("Custom_Action_VIs"):
    if action.text:
        action.text = str(installed / action.text.replace("\\", "/"))

mapping = {
    "ActorFramework": "vi.lib/ActorFramework",
    "AFDebug": "resource/AFDebug",
    "Menus": "menus",
    "Menus/Categories": "menus/Categories",
    "Menus/Controls": "menus/Controls",
}
sources = advanced.find("Source_Files")
for override in sources.findall("Destination_Overrides"):
    path = override.find("Path")
    path.text = mapping.get(path.text, path.text)
for node in list(sources.findall("Exclusions")) + list(sources.findall("Place_Folder_Contents")):
    sources.remove(node)
for band in ("vi.lib", "resource", "menus"):
    ET.SubElement(ET.SubElement(sources, "Place_Folder_Contents"), "Path").text = band

allowed = set()
for band in ("vi.lib/ActorFramework", "resource/AFDebug", "menus"):
    allowed.update(path.relative_to(distribution).as_posix() for path in (distribution / band).rglob("*") if path.is_file())
allowed.update(path.relative_to(installed).as_posix() for path in (installed / "Install Support").rglob("*") if path.is_file())
ancestors = {parent.as_posix() for path in allowed for parent in Path(path).parents}
excluded = []
def exclude_unselected(directory):
    for child in sorted(directory.iterdir()):
        relative = child.relative_to(installed).as_posix()
        if relative in allowed:
            continue
        if relative in ancestors and child.is_dir() and not child.is_symlink():
            exclude_unselected(child)
        else:
            excluded.append(relative)
exclude_unselected(installed)
for path in excluded:
    ET.SubElement(ET.SubElement(sources, "Exclusions"), "Path").text = path
missing = [path for path in allowed if not (installed / path).is_file()]
if missing:
    raise ValueError(f"Installed distribution files missing: {missing[:20]}")
tree.write(output, encoding="utf-8", xml_declaration=True)
print(f"Prepared {output} from {source}")
print(f"Installed source root: {installed}; selected {len(allowed)} files; excluded {len(excluded)} paths")
print("Core package only: Providers are installed for validation but excluded from the VIP.")
print("Preserved LabVIEW version/bitness metadata; no LVLib/LVClass/VI link rewriting.")
PY
cat "$LOG_DIR/vipb-preparation.log"

run_logged vipm-build 1800 vipm build "$vipb_output" --labview-version "$LV_YEAR" --labview-bitness 64 --timeout 900 --verbose
shopt -s nullglob
vip_files=("$ARTIFACT_ROOT/Builds/"*.vip)
if (( ${#vip_files[@]} == 0 )); then
    echo 'VIPM reported success but produced no .vip under the artifact output directory.' >&2
    exit 1
fi
printf 'Built VIP package(s):\n'
printf '  %s\n' "${vip_files[@]}"