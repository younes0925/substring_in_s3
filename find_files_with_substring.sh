#!/bin/bash

# Function to search for a substring in a file
search_in_file() {
    local bucket_name=$1
    local file_key=$2
    local substring=$3

    # Debug: Print file being processed
    echo "Processing file: $file_key"

    # Download the file from S3 to a temporary location
    aws --endpoint-url=http://localhost:4566 s3 cp s3://$bucket_name/$file_key /tmp/$file_key

    # Check if the file is a text file
    if file /tmp/$file_key | grep -q "text"; then
        # Check if the file contains the substring
        if grep -q "$substring" /tmp/$file_key; then
            # If the substring is found, add the file key to the results
            MATCHING_FILES+=("$file_key")
        fi
    else
        echo "$file_key is not a text file. Skipping."
    fi

    # Remove the temporary file
    rm /tmp/$file_key
}

# Function to list all files in a bucket including subfolders
list_all_files() {
    local bucket_name=$1
    local prefix=$2 #Assigns the second argument (prefix or folder path) to the prefix variable.
    local continuation_token=$3 #This is used for pagination

    local query='Contents[].Key'
    if [ -n "$continuation_token" ]; then
        FILES=$(aws --endpoint-url=http://localhost:4566 s3api list-objects-v2 --bucket $bucket_name --prefix "$prefix" --continuation-token $continuation_token --query "$query" --output text)
    else
        FILES=$(aws --endpoint-url=http://localhost:4566 s3api list-objects-v2 --bucket $bucket_name --prefix "$prefix" --query "$query" --output text)
    fi

    echo "$FILES"

    # Check for additional pages of results
    local next_token
    next_token=$(aws --endpoint-url=http://localhost:4566 s3api list-objects-v2 --bucket $bucket_name --prefix "$prefix" --query 'NextContinuationToken' --output text)

    if [ "$next_token" != "None" ]; then
        list_all_files $bucket_name "$prefix" "$next_token"
    fi
}

# Main script execution starts here

# Check if the correct number of arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <s3_bucket_name> <substring>"
    exit 1
fi

# Assign arguments to variables for better readability
S3_BUCKET_NAME=$1
SUBSTRING=$2

# Initialize an array to hold the names of matching files
MATCHING_FILES=()

# List all objects (files) in the specified S3 bucket including subfolders
FILES=$(list_all_files $S3_BUCKET_NAME "")

# Iterate through each file in the S3 bucket
for FILE in $FILES; do
    # Call the search_in_file function for each file
    search_in_file $S3_BUCKET_NAME $FILE $SUBSTRING
done

# Print the results at the end
if [ ${#MATCHING_FILES[@]} -eq 0 ]; then
    echo "##########################################################"
    echo "No files containing the substring '$SUBSTRING' were found."
    echo "##########################################################"
else
    echo "##########################################################"
    echo "Files containing the substring '$SUBSTRING':"
    for FILE in "${MATCHING_FILES[@]}"; do
        echo $FILE
    done
    echo "##########################################################"
fi
