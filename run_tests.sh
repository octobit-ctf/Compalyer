#!/bin/bash
#===============================================================================
#                         LANG_F COMPILER - TEST RUNNER
#===============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

COMPILER="./langf"
TEST_DIR="./tests"

echo ""
echo "╔════════════════════════════════════════════════════════════════════════╗"
echo "║                    LANG_F COMPILER - TEST SUITE                        ║"
echo "╚════════════════════════════════════════════════════════════════════════╝"
echo ""

# Check if compiler exists
if [ ! -f "$COMPILER" ]; then
    echo -e "${RED}ERROR: Compiler '$COMPILER' not found!${NC}"
    echo "Please compile with: make"
    exit 1
fi

# Counters
total=0
passed=0
failed=0

# Expected results (1 = should pass, 0 = should have errors)
declare -A expected=(
    ["01_programme_vide.txt"]=1
    ["02_declaration_variable.txt"]=1
    ["03_declaration_constante.txt"]=1
    ["04_plusieurs_variables_erreur.txt"]=0
    ["05_plusieurs_variables_valide.txt"]=1
    ["06_test_idf_valide.txt"]=1
    ["07_test_idf_erreur.txt"]=0
    ["08_affectation_valide.txt"]=1
    ["09_affectation_erreur.txt"]=0
    ["10_instruction_if.txt"]=1
    ["11_instruction_if_else.txt"]=1
    ["12_if_imbrique.txt"]=1
    ["13_instruction_for.txt"]=1
    ["14_for_imbrique.txt"]=1
    ["15_idf_non_declare.txt"]=0
    ["16_double_declaration.txt"]=0
    ["17_compatibilite_types.txt"]=0
    ["18_modification_constante.txt"]=0
    ["19_initialisation_declaration.txt"]=1
    ["20_expressions_complexes.txt"]=1
    ["21_operateurs_relationnels.txt"]=1
    ["22_division_zero.txt"]=0
    ["00_test_global.txt"]=1
)

echo "Running tests..."
echo "--------------------------------------------------------------------------------"
printf "%-45s %-15s %-15s\n" "TEST FILE" "EXPECTED" "RESULT"
echo "--------------------------------------------------------------------------------"

# Run each test
for testfile in "$TEST_DIR"/*.txt; do
    filename=$(basename "$testfile")
    ((total++))
    
    # Run compiler and capture output
    output=$($COMPILER "$testfile" 2>&1)
    exit_code=$?
    
    # Check for errors in output
    has_error=0
    if echo "$output" | grep -qi "error"; then
        has_error=1
    fi
    
    # Determine expected behavior
    should_pass=${expected[$filename]:-1}
    
    if [ "$should_pass" -eq 1 ]; then
        expected_str="PASS"
        if [ "$has_error" -eq 0 ]; then
            result_str="${GREEN}✓ PASS${NC}"
            ((passed++))
        else
            result_str="${RED}✗ FAIL${NC}"
            ((failed++))
        fi
    else
        expected_str="ERROR"
        if [ "$has_error" -eq 1 ]; then
            result_str="${GREEN}✓ ERROR DETECTED${NC}"
            ((passed++))
        else
            result_str="${RED}✗ MISSED ERROR${NC}"
            ((failed++))
        fi
    fi
    
    printf "%-45s %-15s " "$filename" "$expected_str"
    echo -e "$result_str"
done

echo "--------------------------------------------------------------------------------"
echo ""
echo "╔════════════════════════════════════════════════════════════════════════╗"
printf "║  RESULTS: Total: %-3d  |  Passed: %-3d  |  Failed: %-3d                   ║\n" $total $passed $failed
echo "╚════════════════════════════════════════════════════════════════════════╝"

if [ $failed -eq 0 ]; then
    echo -e "${GREEN}All tests passed! ✓${NC}"
else
    echo -e "${RED}Some tests failed! ✗${NC}"
fi
echo ""
