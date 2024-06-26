#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status.

# Function to display usage information
usage() {
    echo "Usage: $0 -f <input_folder_name>"
    echo "  -f    Specify the input folder name"
    echo "  -h    Display this help message"
    exit 1
}

# Parse command-line options
while getopts "f:h" opt; do
    case ${opt} in
        f )
            INPUT_FOLDER=$OPTARG
            ;;
        h )
            usage
            ;;
        \? )
            usage
            ;;
    esac
done

# Check if INPUT_FOLDER is provided
if [ -z "$INPUT_FOLDER" ]; then
    echo "Error: Input folder is required."
    usage
fi

CONVERTED_FOLDER="${INPUT_FOLDER}_CONVERTED"
LOGS_FOLDER="$CONVERTED_FOLDER/logs"
LOG_FILE="conversion_log_$(date +%Y%m%d_%H%M%S).log"

# Create the main folders
mkdir -p "$CONVERTED_FOLDER/shell_actions"
mkdir -p "$CONVERTED_FOLDER/subworkflow_actions"
mkdir -p "$CONVERTED_FOLDER/output"
mkdir -p "$LOGS_FOLDER"

# Logging function
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [$level] $message" | tee -a "$LOGS_FOLDER/$LOG_FILE"
}

log "INFO" "Starting conversion process for $INPUT_FOLDER"
log "INFO" "Created directory structure in $CONVERTED_FOLDER"

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
                    [ -f "$folder/job.properties" ] && cp "$folder/job.properties" "$target_folder/" || log "WARN" "job.properties not found in $folder"
                    [ -f "$INPUT_FOLDER/configuration.properties" ] && cp "$INPUT_FOLDER/configuration.properties" "$target_folder/" || log "WARN" "configuration.properties not found"
                    log "INFO" "Processed shell action: $subflow_name"
                    ;;
                subworkflow)
                    target_folder="$CONVERTED_FOLDER/subworkflow_actions/$subflow_name"
                    mkdir -p "$target_folder/hdfs"
                    cp "$folder/workflow.xml" "$target_folder/hdfs/"
                    [ -f "$folder/job.properties" ] && cp "$folder/job.properties" "$target_folder/" || log "WARN" "job.properties not found in $folder"
                    [ -f "$INPUT_FOLDER/configuration.properties" ] && cp "$INPUT_FOLDER/configuration.properties" "$target_folder/" || log "WARN" "configuration.properties not found"
                    
                    # Handle nested sub-workflows
                    if [ -d "$folder/subwf" ]; then
                        mkdir -p "$target_folder/subwf/hdfs"
                        [ -f "$folder/subwf/workflow.xml" ] && cp "$folder/subwf/workflow.xml" "$target_folder/subwf/hdfs/" || log "WARN" "subwf/workflow.xml not found in $folder"
                        [ -f "$folder/subwf/job.properties" ] && cp "$folder/subwf/job.properties" "$target_folder/subwf/" || log "WARN" "subwf/job.properties not found in $folder"
                    fi
                    log "INFO" "Processed subworkflow action: $subflow_name"
                    ;;
                unknown)
                    log "WARN" "Unknown action type for $subflow_name, skipping..."
                    ;;
            esac
        else
            log "WARN" "workflow.xml not found in $folder"
        fi
    fi
done

# Create a script to run o2a for each action type
cat << EOF > run_o2a_bulk.sh
#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status.

CONVERTED_FOLDER="$CONVERTED_FOLDER"
LOGS_FOLDER="$LOGS_FOLDER"
LOG_FILE="o2a_conversion_log_\$(date +%Y%m%d_%H%M%S).log"

# Logging function
log() {
    local level="\$1"
    local message="\$2"
    local timestamp=\$(date "+%Y-%m-%d %H:%M:%S")
    echo "[\$timestamp] [\$level] \$message" | tee -a "\$LOGS_FOLDER/\$LOG_FILE"
}

run_o2a() {
    local input_dir="\$1"
    local output_dir="\$2"
    local action_type="\$3"

    log "INFO" "Converting \$action_type action: \$(basename "\$input_dir")"
    log "INFO" "Input directory: \$input_dir"
    log "INFO" "Output directory: \$output_dir"

    if [ ! -f "\$input_dir/hdfs/workflow.xml" ]; then
        log "ERROR" "workflow.xml not found in \$input_dir/hdfs/"
        return 1
    fi

    ./bin/o2a -i "\$input_dir" -o "\$output_dir"
    if [ \$? -ne 0 ]; then
        log "ERROR" "o2a conversion failed for \$input_dir"
        return 1
    fi
    log "INFO" "Conversion successful for \$(basename "\$input_dir")"
}

log "INFO" "Starting bulk conversion process"

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

log "INFO" "Bulk conversion completed"
EOF

chmod +x run_o2a_bulk.sh

log "INFO" "Setup completed for $INPUT_FOLDER. You can now run ./run_o2a_bulk.sh to perform the conversion."
log "INFO" "Log files are stored in: $LOGS_FOLDER"