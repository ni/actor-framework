#!/bin/bash
set -e
VIA_EXIT_CODE="${1:-0}"

if [ ! -f "vi-analyzer-report.htm" ]; then
    echo "No VI Analyzer report found"
    exit $VIA_EXIT_CODE
fi

echo ""
echo "=================================================="
echo " VI Analyzer Results"
echo "=================================================="
echo ""

# Extract results
VIS_ANALYZED=$(grep -oP 'VIs Analyzed</td><td>\K[0-9]+' vi-analyzer-report.htm || echo "0")
TESTS_RUN=$(grep -oP 'Total Tests Run</td><td>\K[0-9]+' vi-analyzer-report.htm || echo "0")
PASSED=$(grep -oP 'Passed Tests</td><td>\K[0-9]+' vi-analyzer-report.htm || echo "0")
FAILED=$(grep -oP 'Failed Tests</td><td>\K[0-9]+' vi-analyzer-report.htm || echo "0")
SKIPPED=$(grep -oP 'Skipped Tests</td><td>\K[0-9]+' vi-analyzer-report.htm || echo "0")

# Extract error counts
VI_NOT_LOADABLE=$(grep -oP 'VI not loadable</td><td>\K[0-9]+' vi-analyzer-report.htm || echo "0")
TEST_NOT_LOADABLE=$(grep -oP 'Test not loadable</td><td>\K[0-9]+' vi-analyzer-report.htm || echo "0")
TEST_NOT_RUNNABLE=$(grep -oP 'Test not runnable</td><td>\K[0-9]+' vi-analyzer-report.htm || echo "0")
TEST_ERROR_OUT=$(grep -oP 'Test error out</td><td>\K[0-9]+' vi-analyzer-report.htm || echo "0")

echo "VIs Analyzed:   $VIS_ANALYZED"
echo "Total Tests:    $TESTS_RUN"
echo "Passed:         $PASSED"
echo "Failed:         $FAILED"
echo "Skipped:        $SKIPPED"
echo ""

if [ "$FAILED" -gt 0 ]; then
    echo "=================================================="
    echo " Failed Tests Summary"
    echo "=================================================="

    # Extract failed test details
    awk '
        /<a name="fail">Failed Tests/,/<a name="err">Testing Errors/ {
        if (match($0, /<b>([^<]+\.vi)<\/b>/, arr)) {
            if (vi_name) print ""
            vi_name = arr[1]
            printf "\n %s\n", vi_name
            print "---"
        }
        if (match($0, /<tr><td>([^<]+)<\/td><td>([^<]+)<\/td><\/tr>/, arr)) {
            test_name = arr[1]
            failure_msg = arr[2]
            printf " %s\n     → %s\n", test_name, failure_msg
        }
        }
    ' vi-analyzer-report.htm
    echo ""
    HAS_ERRORS=1
fi

if [ "$VI_NOT_LOADABLE" -gt 0 ]; then
    echo "=================================================="
    echo " VI Not Loadable Errors"
    echo "=================================================="

    awk '
        /<h3>VI Not Loadable<\/h3>/,/<\/table>/ {
        if (match($0, /<tr><td>([^<]+)<\/td><td>([^<]+)<\/td><td>([^<]+)<\/td><\/tr>/, arr)) {
            vi_name = arr[1]
            vi_path = arr[2]
            error_msg = arr[3]
            printf "\n %s\n", vi_name
            printf "   Path: %s\n", vi_path
            printf "    %s\n", error_msg
        }
        }
    ' vi-analyzer-report.htm
    echo ""
    HAS_ERRORS=1
fi     

if [ "$TEST_NOT_LOADABLE" -gt 0 ]; then
    echo "=================================================="
    echo " Test Not Loadable Errors"
    echo "=================================================="

    awk '
        /<h3>Test Not Loadable<\/h3>/,/<\/table>/ {
        if (match($0, /<tr><td>([^<]+)<\/td><td>([^<]+)<\/td><\/tr>/, arr)) {
            test_name = arr[1]
            error_msg = arr[2]
            printf "\n %s\n   → %s\n", test_name, error_msg
        }
        }
    ' vi-analyzer-report.htm
    echo ""
    HAS_ERRORS=1
fi

if [ "$TEST_NOT_RUNNABLE" -gt 0 ]; then
    echo "=================================================="
    echo " Test Not Runnable Errors"
    echo "=================================================="

    awk '
        /<h3>Test Not Runnable<\/h3>/,/<\/table>/ {
        if (match($0, /<tr><td>([^<]+)<\/td><td>([^<]+)<\/td><\/tr>/, arr)) {
            test_name = arr[1]
            error_msg = arr[2]
            printf "\n %s\n   → %s\n", test_name, error_msg
        }
        }
    ' vi-analyzer-report.htm
    echo ""
    HAS_ERRORS=1
fi

if [ "$TEST_ERROR_OUT" -gt 0 ]; then
    echo "=================================================="
    echo " Test Error Out Errors"
    echo "=================================================="

    awk '
        /<h3>Test Error Out<\/h3>/,/<\/table>/ {
        if (match($0, /<tr><td>([^<]+)<\/td><td>([^<]+)<\/td><\/tr>/, arr)) {
            test_name = arr[1]
            error_msg = arr[2]
            printf "\n %s\n   → %s\n", test_name, error_msg
        }
        }
    ' vi-analyzer-report.htm
    echo ""
    HAS_ERRORS=1
fi

if [ "$HAS_ERRORS" -eq 1 ]; then
    echo ""
    echo "=================================================="
    echo "See full report in artifacts for complete details."
    echo "=================================================="
else
    echo " All tests passed!"
    echo "=================================================="
fi

exit $VIA_EXIT_CODE