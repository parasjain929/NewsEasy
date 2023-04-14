#!/bin/bash

# Set the GCP project ID and backup location
PROJECT_ID=<your_project_id>
BUCKET_NAME=<your_bucket_name>

# Get the list of all datasets in the project
DATASETS=$(bq --project_id=$PROJECT_ID ls --datasets --max_results=10000 --format=json | jq -r '.[].datasetReference.datasetId' )

# Loop through the list of datasets and tables and create a backup for each table
for dataset in "${DATASETS[@]}"; do
  TABLES=$(bq --project_id=$PROJECT_ID ls --max_results=10000 --format=json $dataset | jq -r '.[].tableReference.tableId' )
  for table in "${TABLES[@]}"; do
    BACKUP_LOCATION="gs://$BUCKET_NAME/$dataset/$table/"
    echo "Creating backup in $BACKUP_LOCATION ..."
    bq --project_id=$PROJECT_ID \
      extract --destination_format AVRO \
      --compression SNAPPY \
      $dataset.$table $BACKUP_LOCATION
  done
done


# Get the list of backup files in the bucket
BACKUP_FILES=$(gsutil ls "gs://$BUCKET_NAME/*/*.avro")

# Loop through the list of backup files and restore them into new datasets and tables
for backup_file in $BACKUP_FILES; do
  # Extract the dataset and table names from the backup file path
  IFS='/' read -ra PATH <<< "$backup_file"
  DATASET_NAME=${PATH[-2]}
  TABLE_NAME=${PATH[-1]%.avro}

  # Create the new dataset and table
  echo "Creating dataset $DATASET_NAME ..."
  bq --project_id=$PROJECT_ID mk --dataset $DATASET_NAME
  echo "Creating table $TABLE_NAME ..."
  bq --project_id=$PROJECT_ID mk $DATASET_NAME.$TABLE_NAME

  # Restore the backup file into the new table
  echo "Restoring backup file $backup_file ..."
  bq --project_id=$PROJECT_ID load \
    --source_format=AVRO \
    $DATASET_NAME.$TABLE_NAME \
    $backup_file
done
