#!/bin/bash
# ====================================================================
# Simulation + coverage script for cbb_ahb_sramc
# Usage: bash cbb_ahb_sramc_sim.sh [signoff|smoke|clean]
# Prerequisites: VCS environment sourced, license available (27081@ICEDA)
# Coverage strategy: pure combinational DUT (assign ternary); TB ref excluded via -cm_hier.
# ====================================================================
set -euo pipefail

MODULE="cbb_ahb_sramc"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUT="${SCRIPT_DIR}/out"
LOG="${SCRIPT_DIR}/logs"
SUMMARY="${LOG}/sim_summary.log"

mkdir -p "${OUT}" "${LOG}"
: >"${SUMMARY}"

case "${1:-signoff}" in
    smoke)  echo "INFO: smoke simulation" ;;
    signoff) echo "INFO: signoff simulation (full coverage)" ;;
    clean)  rm -rf -- "${OUT}" "${LOG}"; echo "[OK] Clean done"; exit 0 ;;
    *)      echo "Usage: $0 [signoff|smoke|clean]" >&2; exit 2 ;;
esac

export SNPSLMD_LICENSE_FILE="${INT_SNPS_LICENSE:-27081@ICEDA}"
export LM_LICENSE_FILE="${INT_SNPS_LICENSE:-27081@ICEDA}"

echo "============================================"
echo " Simulating ${MODULE} (with coverage)"
echo "============================================"

rundir="${OUT}/run_signoff"
rm -rf -- "${rundir}"
mkdir -p "${rundir}"

(
    cd "${OUT}"
    if vcs -full64 -sverilog -timescale=1ns/1ps -debug_access+all \
        -cm line+cond+tgl+branch \
        -cm_hier "${REPO_ROOT}/scripts/cov/${MODULE}_cov.hier" \
        -f "${REPO_ROOT}/filelist/${MODULE}/rtl_filelist.f" \
        -f "${REPO_ROOT}/filelist/${MODULE}/tb_filelist.f" \
        -Mdir="${rundir}/csrc" -o "${rundir}/simv" \
        -cm_dir "${rundir}/simv.vdb" \
        -l "${LOG}/compile.log" 2>&1 &&
       (cd "${rundir}" && ./simv -cm line+cond+tgl+branch \
            -cm_dir "${rundir}/simv.vdb" \
            -l "${LOG}/sim.log" 2>&1) &&
       grep -q "TEST PASSED" "${LOG}/sim.log"; then
        echo "PASS ${MODULE}" >>"${SUMMARY}"
    else
        echo "FAIL ${MODULE}" >>"${SUMMARY}"
        grep -E "FAIL|Error" "${LOG}/sim.log" 2>/dev/null || true
        exit 1
    fi
)

echo "============================================"
echo " Merging coverage (urg)"
echo "============================================"

if [ -d "${rundir}/simv.vdb" ]; then
    urg -dir "${rundir}/simv.vdb" -format text -report "${LOG}/coverage_rpt"
    echo "Coverage report: ${LOG}/coverage_rpt"
fi

echo ""
pass=$(grep -c '^PASS' "${SUMMARY}" || true)
fail=$(grep -c '^FAIL' "${SUMMARY}" || true)
echo "SIM RESULT: PASS=$pass FAIL=$fail"

echo ""
echo "============================================"
echo " Coverage Summary"
echo "============================================"
grep -A2 "Total Coverage Summary" "${LOG}/coverage_rpt/dashboard.txt" 2>/dev/null || echo "(coverage report not found)"

[ "$fail" -eq 0 ]
