#!/bin/bash
set -e

# VI Analyzer script for GitHub Actions

# Accept config path as first argument, default to generated-config.viancfg
CONFIG_PATH="${1:-generated-config.viancfg}"
ABSOLUTE_CONFIG="/workspace/$CONFIG_PATH"
ABSOLUTE_REPORT="/workspace/vi-analyzer-report.htm"
LV_YEAR="${LV_YEAR:-2025}"
LABVIEW_PATH="/usr/local/natinst/LabVIEW-${LV_YEAR}-64/labview"

# Verify that the configuration path exists
if [ ! -d "$ABSOLUTE_CONFIG" ] && [ ! -f "$ABSOLUTE_CONFIG" ]; then
  echo "Error: Configuration path not found at $ABSOLUTE_CONFIG"
  exit 1
fi

echo "Running LabVIEWCLI VIAnalyzer with the following parameters:"
echo "ConfigPath: $ABSOLUTE_CONFIG"
echo "ReportPath: $ABSOLUTE_REPORT"
echo "LabVIEWPath: $LABVIEW_PATH"
echo ""

# Run VI Analyzer
LabVIEWCLI \
  -OperationName RunVIAnalyzer \
  -ConfigPath "$ABSOLUTE_CONFIG" \
  -ReportPath "$ABSOLUTE_REPORT" \
  -ReportSaveType HTML \
  -LabVIEWPath "$LABVIEW_PATH" \
  -Headless