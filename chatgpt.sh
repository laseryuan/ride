#!/bin/bash

# Define the template file
TEMPLATE_FILE=${1}

# Define the comment prefix (change this to whatever you want, e.g., "# " or "; ")
COMMENT_PREFIX="// "

# Check if template file exists
if [[ ! -f "$TEMPLATE_FILE" ]]; then
    echo "Error: Template file '$TEMPLATE_FILE' not found!"
    exit 1
fi

# Function to read file and filter out lines starting with the COMMENT_PREFIX
read_file_content() {
    local file_path="$1"
    local filtered_content=""

    while IFS= read -r line; do
        if [[ ! "$line" =~ ^$COMMENT_PREFIX ]]; then
            filtered_content+="$line"$'\n'
        fi
    done < "$file_path"

    echo -n "$filtered_content"
}

# Read the template file line by line
while IFS= read -r line; do
    # Replace each placeholder with corresponding file content
    modified_line="$line"
    while [[ "$modified_line" =~ \{\{([^}]+)\}\} ]]; do
        FILE_TO_INSERT="${BASH_REMATCH[1]}"
        
        # Resolve relative paths
        FILE_PATH=$(realpath --relative-to="$(pwd)" "$FILE_TO_INSERT" 2>/dev/null || echo "$FILE_TO_INSERT")
        
        if [[ -f "$FILE_PATH" ]]; then
            FILE_CONTENT=$(read_file_content "$FILE_PATH")
            modified_line=${modified_line//\{\{$FILE_TO_INSERT\}\}/$FILE_CONTENT}
        else
            echo "Warning: File '$FILE_PATH' not found!"
            modified_line=${modified_line//\{\{$FILE_TO_INSERT\}\}/"[MISSING FILE: $FILE_TO_INSERT]"}
        fi
    done
    echo "$modified_line"
done < "$TEMPLATE_FILE"

