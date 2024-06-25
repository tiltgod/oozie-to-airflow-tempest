#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status.

# Check if a folder name is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <input_folder_name>"
    exit 1
fi

INPUT_FOLDER="$1"
CONVERTED_FOLDER="${INPUT_FOLDER}_CONVERTED"

# Create the main folders
mkdir -p "$CONVERTED_FOLDER/shell_actions"
mkdir -p "$CONVERTED_FOLDER/subworkflow_actions"
mkdir -p "$CONVERTED_FOLDER/output"

# Function to determine action type
determine_action_type() {
    local workflow_file="$1"
    if grep -q "<shell" "$workflow_file"; then
        echo "shell"
    elif grep -q "<sub-workflow" "$workflow_file"; then
        echo "subworkflow"
    else
        echo "unknown"
    fi
}

# Loop through each subfolder in the original structure
for folder in "$INPUT_FOLDER"/*; do
    if [ -d "$folder" ]; then
        subflow_name=$(basename "$folder")

        # Check for the main workflow file
        if [ -f "$folder/workflow.xml" ]; then
            action_type=$(determine_action_type "$folder/workflow.xml")
            
            case $action_type in
                shell)
                    target_folder="$CONVERTED_FOLDER/shell_actions/$subflow_name"
                    mkdir -p "$target_folder/hdfs"
                    cp "$folder/workflow.xml" "$target_folder/hdfs/"
                    [ -f "$folder/job.properties" ] && cp "$folder/job.properties" "$target_folder/" || echo "Warning: job.properties not found in $folder"
                    [ -f "$INPUT_FOLDER/configuration.properties" ] && cp "$INPUT_FOLDER/configuration.properties" "$target_folder/" || echo "Warning: configuration.properties not found"
                    echo "Processed shell action: $subflow_name"
                    ;;
                subworkflow)
                    target_folder="$CONVERTED_FOLDER/subworkflow_actions/$subflow_name"
                    mkdir -p "$target_folder/hdfs"
                    cp "$folder/workflow.xml" "$target_folder/hdfs/"
                    [ -f "$folder/job.properties" ] && cp "$folder/job.properties" "$target_folder/" || echo "Warning: job.properties not found in $folder"
                    [ -f "$INPUT_FOLDER/configuration.properties" ] && cp "$INPUT_FOLDER/configuration.properties" "$target_folder/" || echo "Warning: configuration.properties not found"
                    
                    # Handle nested sub-workflows
                    if [ -d "$folder/subwf" ]; then
                        mkdir -p "$target_folder/subwf/hdfs"
                        [ -f "$folder/subwf/workflow.xml" ] && cp "$folder/subwf/workflow.xml" "$target_folder/subwf/hdfs/" || echo "Warning: subwf/workflow.xml not found in $folder"
                        [ -f "$folder/subwf/job.properties" ] && cp "$folder/subwf/job.properties" "$target_folder/subwf/" || echo "Warning: subwf/job.properties not found in $folder"
                    fi
                    echo "Processed subworkflow action: $subflow_name"
                    ;;
                unknown)
                    echo "Unknown action type for $subflow_name, skipping..."
                    ;;
            esac
        else
            echo "Warning: workflow.xml not found in $folder"
        fi
    fi
done

# Create a script to run o2a for each action type
cat << EOF > run_o2a_bulk.sh
#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status.

CONVERTED_FOLDER="$CONVERTED_FOLDER"

run_o2a() {
    local input_dir="\$1"
    local output_dir="\$2"
    local action_type="\$3"

    echo "Converting \$action_type action: \$(basename "\$input_dir")"
    echo "Input directory: \$input_dir"
    echo "Output directory: \$output_dir"

    if [ ! -f "\$input_dir/hdfs/workflow.xml" ]; then
        echo "Error: workflow.xml not found in \$input_dir/hdfs/"
        return 1
    fi

    ./bin/o2a -i "\$input_dir" -o "\$output_dir"
    if [ \$? -ne 0 ]; then
        echo "Error: o2a conversion failed for \$input_dir"
        return 1
    fi
    echo "Conversion successful for \$(basename "\$input_dir")"
}

# Convert shell actions
for subflow in "\$CONVERTED_FOLDER"/shell_actions/*; do
    if [ -d "\$subflow" ]; then
        run_o2a "\$subflow" "\$CONVERTED_FOLDER/output/shell_\$(basename "\$subflow")" "shell"
    fi
done

# Convert subworkflow actions
for subflow in "\$CONVERTED_FOLDER"/subworkflow_actions/*; do
    if [ -d "\$subflow" ]; then
        run_o2a "\$subflow" "\$CONVERTED_FOLDER/output/subwf_\$(basename "\$subflow")" "subworkflow"
    fi
done

echo "Bulk conversion completed."
EOF

chmod +x run_o2a_bulk.sh

echo "Setup completed for $INPUT_FOLDER. You can now run ./run_o2a_bulk.sh to perform the conversion."