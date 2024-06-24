#!/bin/bash

# Create the main folders
mkdir -p CRM_CASA_SEGMENT_MODEL_CONVERTED/shell_actions
mkdir -p CRM_CASA_SEGMENT_MODEL_CONVERTED/subworkflow_actions
mkdir -p CRM_CASA_SEGMENT_MODEL_CONVERTED/output

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
for folder in CRM_CASA_SEGMENT_MODEL/*; do
    if [ -d "$folder" ]; then
        subflow_name=$(basename "$folder")

        # Check for the main workflow file
        if [ -f "$folder/workflow.xml" ]; then
            action_type=$(determine_action_type "$folder/workflow.xml")
            
            case $action_type in
                shell)
                    target_folder="CRM_CASA_SEGMENT_MODEL_CONVERTED/shell_actions/$subflow_name"
                    mkdir -p "$target_folder/hdfs"
                    cp "$folder/workflow.xml" "$target_folder/hdfs/"
                    cp "$folder/job.properties" "$target_folder/"
                    cp "CRM_CASA_SEGMENT_MODEL/configuration.properties" "$target_folder/"
                    ;;
                subworkflow)
                    target_folder="CRM_CASA_SEGMENT_MODEL_CONVERTED/subworkflow_actions/$subflow_name"
                    mkdir -p "$target_folder/hdfs"
                    cp "$folder/workflow.xml" "$target_folder/hdfs/"
                    cp "$folder/job.properties" "$target_folder/"
                    cp "CRM_CASA_SEGMENT_MODEL/configuration.properties" "$target_folder/"
                    
                    # Handle nested sub-workflows
                    if [ -d "$folder/subwf" ]; then
                        mkdir -p "$target_folder/subwf/hdfs"
                        cp "$folder/subwf/workflow.xml" "$target_folder/subwf/hdfs/"
                        cp "$folder/subwf/job.properties" "$target_folder/subwf/"
                    fi
                    ;;
                unknown)
                    echo "Unknown action type for $subflow_name, skipping..."
                    ;;
            esac
        fi
    fi
done

# Create a script to run o2a for each action type
cat << EOF > run_o2a_bulk.sh
#!/bin/bash

# Convert shell actions
for subflow in CRM_CASA_SEGMENT_MODEL_CONVERTED/shell_actions/*; do
    if [ -d "\$subflow" ]; then
        subflow_name=\$(basename "\$subflow")
        echo "Converting shell action: \$subflow_name"
        ./bin/o2a -i "\$subflow" -o "CRM_CASA_SEGMENT_MODEL_CONVERTED/output/shell_\$subflow_name"
    fi
done

# Convert subworkflow actions
for subflow in CRM_CASA_SEGMENT_MODEL_CONVERTED/subworkflow_actions/*; do
    if [ -d "\$subflow" ]; then
        subflow_name=\$(basename "\$subflow")
        echo "Converting subworkflow action: \$subflow_name"
        ./bin/o2a -i "\$subflow" -o "CRM_CASA_SEGMENT_MODEL_CONVERTED/output/subwf_\$subflow_name"
    fi
done
EOF

chmod +x run_o2a_bulk.sh