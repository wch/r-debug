#!/bin/bash

# Directory containing the files
DIRECTORY="$1"

# Output file
OUTPUT_FILE="$(pwd)/recommended_files.txt"

# Check if directory is provided
if [ -z "$DIRECTORY" ]; then
    echo "Usage: $0 <directory>"
    exit 1
fi

# Check if directory exists
if [ ! -d "$DIRECTORY" ]; then
    echo "Directory not found: $DIRECTORY"
    exit 1
fi

# Ensure the provided directory is not the current working directory
if [ "$(pwd)" == "$(realpath "$DIRECTORY")" ]; then
    echo "The specified directory should not be the current working directory."
    exit 1
fi

# Clear the output file
> "$OUTPUT_FILE"

# Iterate over each file in the directory
cd "$DIRECTORY"
for file in *; do
    if [ -f "$file" ]; then
        # Generate hash for the file
        hash=$(nix hash file "$file")

        # Append the filename and hash to the output file
        echo "${file} ${hash}" >> "$OUTPUT_FILE"
    fi
done

echo "Hashes written to $OUTPUT_FILE"
