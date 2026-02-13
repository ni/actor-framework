#!/bin/bash
set -e

# Parse arguments
TEMPLATE_PATH=""
OUTPUT_PATH=""
TARGET_BRANCH="origin/develop"

while [[ $# -gt 0 ]]; do
  case $1 in
    --template-path)
      TEMPLATE_PATH="$2"
      shift 2
      ;;
    --output-path)
      OUTPUT_PATH="$2"
      shift 2
      ;;
    --target-branch)
      TARGET_BRANCH="$2"
      shift 2
      ;;
    *)
      echo "Unknown parameter: $1"
      exit 1
      ;;
  esac
done

# Validate required parameters
if [ -z "$TEMPLATE_PATH" ] || [ -z "$OUTPUT_PATH" ]; then
  echo "Error: --template-path and --output-path are required"
  exit 1
fi

echo "Generating VI Analyzer config from template: $TEMPLATE_PATH"
echo "Target branch: $TARGET_BRANCH"
echo ""

# Get changed LabVIEW files relative to the target branch
mapfile -t CHANGED_FILES < <(git diff --name-only "$TARGET_BRANCH" --diff-filter=d | grep -E '\.(vi|ctl|llb)$' || true)

if [ ${#CHANGED_FILES[@]} -eq 0 ]; then
  echo "No LabVIEW files changed. Skipping config generation."
  exit 0
fi

echo "Found ${#CHANGED_FILES[@]} changed LabVIEW file(s):"
printf '%s\n' "${CHANGED_FILES[@]}"
echo ""

# Get Git root directory
GIT_ROOT=$(git rev-parse --show-toplevel)

# Read template XML and prepare output
cp "$TEMPLATE_PATH" "$OUTPUT_PATH"

OUTPUT_DIR=$(dirname "$OUTPUT_PATH")
if [ -n "$OUTPUT_DIR" ] && [ ! -d "$OUTPUT_DIR" ]; then
  mkdir -p "$OUTPUT_DIR"
fi

# Get the absolute path of the output config for relative path calculation
OUTPUT_ABS_DIR=$(cd "$OUTPUT_DIR" && pwd)

# Create a temporary file for the items
ITEMS_FILE=$(mktemp)

for file in "${CHANGED_FILES[@]}"; do
  # Construct absolute path
  ABSOLUTE_FILE_PATH="$GIT_ROOT/$file"
  
  # Calculate relative path from output config to the VI
  RELATIVE_PATH=$(realpath --relative-to="$OUTPUT_ABS_DIR" "$ABSOLUTE_FILE_PATH")
  
  FORMATTED_PATH="\"$RELATIVE_PATH\""
  
  # Write XML item to temp file
  cat >> "$ITEMS_FILE" << EOF
    <Item>
      <Path>$FORMATTED_PATH</Path>
      <Removed>FALSE</Removed>
    </Item>
EOF
done

# Use awk to insert the items into the template
awk -v items_file="$ITEMS_FILE" '
  /<\/ItemsToAnalyze>/ {
    while ((getline line < items_file) > 0) {
      print line
    }
    close(items_file)
  }
  /<Item>/,/<\/Item>/ { next }
  { print }
' "$TEMPLATE_PATH" > "$OUTPUT_PATH"

# Clean up temp file
rm -f "$ITEMS_FILE"

echo ""
echo "Generated config at $OUTPUT_PATH with ${#CHANGED_FILES[@]} items."