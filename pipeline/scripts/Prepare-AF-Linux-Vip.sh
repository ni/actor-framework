#!/usr/bin/env bash
set -Eeuo pipefail

DISTRIBUTION="$WORKSPACE/.af-distribution"
for relative_path in 'vi.lib/ActorFramework/Actor Framework.lvlib' 'resource/AFDebug/AF Debug.lvlib' menus; do
    [[ -e "$DISTRIBUTION/$relative_path" ]] || { echo "Distribution path missing: $relative_path" >&2; exit 1; }
done

for relative_path in vi.lib/ActorFramework resource/AFDebug; do
    if [[ -e "$LV_ROOT/$relative_path" ]]; then
        mv "$LV_ROOT/$relative_path" "/tmp/af-original-$(basename "$relative_path")"
        printf 'Moved bundled %s out of LabVIEW\n' "$relative_path"
    fi
done

mkdir -p "$SOURCE_DIR" "$LOG_DIR"
cp -a "$DISTRIBUTION/vi.lib/ActorFramework" "$SOURCE_DIR/ActorFramework"
cp -a "$DISTRIBUTION/resource/AFDebug" "$SOURCE_DIR/AFDebug"
cp -a "$DISTRIBUTION/menus" "$SOURCE_DIR/Menus"
cp -a "$WORKSPACE/Core/Install Support" "$SOURCE_DIR/Install Support"
diff -qr "$DISTRIBUTION/vi.lib/ActorFramework" "$SOURCE_DIR/ActorFramework"
diff -qr "$DISTRIBUTION/resource/AFDebug" "$SOURCE_DIR/AFDebug"
diff -qr "$DISTRIBUTION/menus" "$SOURCE_DIR/Menus"

if ! vipm refresh --verbose; then
    echo 'VIPM refresh failed; retrying once after 30 seconds.' >&2
    sleep 30
    vipm refresh --verbose
fi

manifest="$WORKSPACE/Tooling/deployment/runner_dependencies.toml"
linux_manifest="$LOG_DIR/runner_dependencies.linux.toml"
awk '
    /^(jki_lib_vipm_api|sas_workshops_lib_lvbuildspec_for_g_cli|sas_workshops_lib_vipb_builder_for_g_cli|sas_workshops_lib_vipc_applier_for_g_cli|wiresmith_technology_lib_g_cli)[[:space:]]*=/ { next }
    { print }
' "$manifest" > "$linux_manifest"
if ! vipm install "$linux_manifest" --labview-version "$LV_YEAR" --labview-bitness 64 --verbose; then
    echo 'Dependency installation failed; retrying once after 30 seconds.' >&2
    sleep 30
    if ! vipm install "$linux_manifest" --labview-version "$LV_YEAR" --labview-bitness 64 --verbose; then
        echo '::warning::VIPM dependency installation failed after retry; continuing.' >&2
    fi
fi

labview_cli="$(command -v LabVIEWCLI || true)"
if [[ -z "$labview_cli" ]]; then
    labview_cli="$(find /usr/local/natinst -type f -name LabVIEWCLI -perm /111 -print -quit)"
fi
if [[ -z "$labview_cli" ]]; then
    echo 'LabVIEWCLI executable not found; cannot mass compile the staged distribution.' >&2
    exit 1
fi
"$labview_cli" -LabVIEWPath "$LV_ROOT/labview" -OperationName MassCompile -DirectoryToCompile "$SOURCE_DIR" -MassCompileLogFile "$LOG_DIR/mass-compile-labview.log" -Headless

python3 - "$WORKSPACE" "$SOURCE_DIR" "$LOG_DIR/Actor Framework.linux.vipb" <<'PY'
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

workspace, source_dir, output = map(Path, sys.argv[1:])
tree = ET.parse(workspace / "Core/Actor Framework 2024 for 2020.vipb")
advanced = tree.getroot().find("Advanced_Settings")
advanced.find("License_Agreement_Filepath").text = str(workspace / "LICENSE.txt")
for action in advanced.find("Custom_Action_VIs"):
    if action.text:
        action_path = source_dir / action.text.replace("\\", "/")
        if not action_path.is_file():
            raise FileNotFoundError(action_path)
        action.text = str(action_path)
tree.write(output, encoding="utf-8", xml_declaration=True)
print(f"Prepared {output}")
PY
