#!/bin/bash
# make-fixtures.sh - Generate test fixtures for performance testing
#
# Creates:
#   - tree-10k: 10,000 files in a nested directory structure
#   - tree-100k: 100,000 files in a nested directory structure
#   - unicode: Files with unicode characters in names
#   - sparse-bigfile: A sparse file for size testing
#
# Usage:
#   ./make-fixtures.sh [clean]
#   ./make-fixtures.sh --help
#
# Environment:
#   PC_FIXTURES_DIR: Directory to store fixtures (default: /tmp/pc_fixtures)

set -e

# Configuration
PC_FIXTURES_DIR="${PC_FIXTURES_DIR:-/tmp/pc_fixtures}"
TREE_10K_DIR="$PC_FIXTURES_DIR/tree-10k"
TREE_100K_DIR="$PC_FIXTURES_DIR/tree-100k"
UNICODE_DIR="$PC_FIXTURES_DIR/unicode"
SPARSE_DIR="$PC_FIXTURES_DIR/sparse-bigfile"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}INFO:${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}WARN:${NC} $1"
}

log_error() {
    echo -e "${RED}ERROR:${NC} $1"
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Generate test fixtures for Peach Commander performance testing.

Options:
  clean     Remove existing fixtures before generating new ones
  --help    Show this help message

Environment:
  PC_FIXTURES_DIR  Directory to store fixtures (default: /tmp/pc_fixtures)

Output:
  tree-10k/       - 10,000 files in nested structure (~20MB)
  tree-100k/      - 100,000 files in nested structure (~200MB)
  unicode/        - Files with unicode characters in names
  sparse-bigfile/ - Directory with a large sparse file

Performance targets:
  - tree-10k: Complete listing < 500ms
  - tree-100k: Complete listing < 1500ms
EOF
    exit 0
}

# Parse arguments
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    usage
fi

if [[ "$1" == "clean" ]]; then
    log_info "Cleaning existing fixtures..."
    rm -rf "$PC_FIXTURES_DIR"
    log_info "Clean complete."
fi

# Create base directory
mkdir -p "$PC_FIXTURES_DIR"

# Generate nested directory structure with N files
generate_tree() {
    local base_dir="$1"
    local num_files="$2"
    local subdirs_per_level=10
    local files_per_subdir=$((num_files / subdirs_per_level))

    log_info "Generating $num_files files in $base_dir..."

    rm -rf "$base_dir"
    mkdir -p "$base_dir"

    # Create subdirectories
    for i in $(seq 1 $subdirs_per_level); do
        mkdir -p "$base_dir/subdir$i"
    done

    # Create files in each subdirectory
    for i in $(seq 1 $subdirs_per_level); do
        for j in $(seq 1 $files_per_subdir); do
            echo "File content $j" > "$base_dir/subdir$i/file_$j.txt"
        done
    done

    log_info "Created $num_files files in $base_dir"
}

# Generate tree-10k (10,000 files)
generate_tree "$TREE_10K_DIR" 10000

# Generate tree-100k (100,000 files)
generate_tree "$TREE_100K_DIR" 100000

# Generate unicode filenames
log_info "Generating unicode test files..."
mkdir -p "$UNICODE_DIR"

# Unicode characters for testing
declare -a unicode_names=(
    "文件.txt"           # Chinese
    "αβγδ.txt"          # Greek
    "привет.txt"        # Russian
    "日本語.txt"         # Japanese
    "한국어.txt"         # Korean
    "Übergröße.txt"     # German with umlaut
    "café.txt"          # French with accent
    "naïve.txt"         # French with diaeresis
    "señor.txt"         # Spanish with tilde
    "αβγ123.txt"        # Mixed
    "файл-1.txt"        # Russian with hyphen
    "文件_2.txt"        # Chinese with underscore
    "αβγ_δεζ.txt"       # Greek with underscore
    "日本語_2.txt"      # Japanese with number
    "한국어_3.txt"      # Korean with number
)

for name in "${unicode_names[@]}"; do
    echo "Unicode test content" > "$UNICODE_DIR/$name"
done

log_info "Created ${#unicode_names[@]} unicode test files in $UNICODE_DIR"

# Generate sparse big file
log_info "Generating sparse big file..."
mkdir -p "$SPARSE_DIR"

# Create a 1GB sparse file (takes no actual disk space)
dd if=/dev/zero of="$SPARSE_DIR/sparse_big.dat" bs=1 count=0 seek=1G 2>/dev/null

# Add some actual content at the beginning and end
echo "Sparse file header" > "$SPARSE_DIR/sparse_big.dat"
dd if=/dev/zero of="$SPARSE_DIR/sparse_big.dat" bs=1 count=1024 seek=1048575 2>/dev/null
echo "Sparse file footer" >> "$SPARSE_DIR/sparse_big.dat"

log_info "Created sparse big file at $SPARSE_DIR/sparse_big.dat (1GB virtual, ~2KB actual)"

# Summary
echo ""
log_info "Fixtures generated successfully!"
echo ""
echo "Directory sizes:"
du -sh "$TREE_10K_DIR" 2>/dev/null || echo "tree-10k: not found"
du -sh "$TREE_100K_DIR" 2>/dev/null || echo "tree-100k: not found"
du -sh "$UNICODE_DIR" 2>/dev/null || echo "unicode: not found"
du -sh "$SPARSE_DIR" 2>/dev/null || echo "sparse-bigfile: not found"
echo ""
log_info "To run tests with fixtures, set PC_FIXTURES_DIR environment variable."
