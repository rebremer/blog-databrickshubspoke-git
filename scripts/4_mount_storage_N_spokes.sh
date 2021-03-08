# 1a. Get tenantID and resource id
tenantId=$(az account show --query tenantId -o tsv)
wsId=$(az resource show \
  --resource-type Microsoft.Databricks/workspaces \
  -g "$RG" \
  -n "$DBRWORKSPACE" \
  --query id -o tsv)
# 1b. Get two bearer tokens in Azure
token_response=$(az account get-access-token --resource 2ff814a6-3304-4ab8-85cb-cd0e6f879c1d)
token=$(jq .accessToken -r <<< "$token_response")
token_response=$(az account get-access-token --resource https://management.core.windows.net/)
azToken=$(jq .accessToken -r <<< "$token_response")
#
# Databricks
dbr_response=$(az databricks workspace show -g $RG -n $DBRWORKSPACE)
workspaceUrl_no_http=$(jq .workspaceUrl -r <<< "$dbr_response")
workspace_id_url="https://"$workspaceUrl_no_http"/"
#
# 2. Upload notebook to Databricks Workspace
api_response=$(curl -v -X POST ${workspace_id_url}api/2.0/workspace/import \
  -H "Authorization: Bearer $token" \
  -H "X-Databricks-Azure-SP-Management-Token:$azToken" \
  -H "X-Databricks-Azure-Workspace-Resource-Id:$wsId" \
  -F path="/mount_ADLSgen2_rawdata.py" -F format=SOURCE -F language=PYTHON -F overwrite=true -F content=@../notebooks/mount_ADLSgen2_rawdata.py)
api_response=$(curl -v -X POST ${workspace_id_url}api/2.0/workspace/import \
  -H "Authorization: Bearer $token" \
  -H "X-Databricks-Azure-SP-Management-Token:$azToken" \
  -H "X-Databricks-Azure-Workspace-Resource-Id:$wsId" \
  -F path="/insert_data_CosmosDB_Gremlin.py" -F format=SOURCE -F language=PYTHON -F overwrite=true -F content=@../notebooks/insert_data_CosmosDB_Gremlin.py)
#
# 4. Create Databricks cluster
api_response=$(curl -v -X POST ${workspace_id_url}api/2.0/clusters/create \
  -H "Authorization: Bearer $token" \
  -H "X-Databricks-Azure-SP-Management-Token:$azToken" \
  -H "X-Databricks-Azure-Workspace-Resource-Id:$wsId" \
  -d "{\"cluster_name\": \"clusterPAT6\",\"spark_version\": \"6.6.x-scala2.11\",\"node_type_id\": \"Standard_D3_v2\", \"autotermination_minutes\":60, \"num_workers\" : 1}")
cluster_id=$(jq .cluster_id -r <<< "$api_response")
echo "##vso[task.setvariable variable=cluster_id]$cluster_id"
#
# 5. Create job
api_response=$(curl -v -X POST ${workspace_id_url}api/2.0/jobs/create \
  -H "Authorization: Bearer $token" \
  -H "X-Databricks-Azure-SP-Management-Token:$azToken" \
  -H "X-Databricks-Azure-Workspace-Resource-Id:$wsId" \
  -d "{\"name\": \"mount storage\", \"existing_cluster_id\": \"$cluster_id\", \"notebook_task\": {\"notebook_path\": \"/mount_ADLSgen2_rawdata\", \"base_parameters\": [{\"key\":\"stor_name\", \"value\":\"$STOR\"}]}}")
job_id=$(jq .job_id -r <<< "$api_response")
#
# 6. Run job to run notebook to mount storage
api_response=$(curl -v -X POST ${workspace_id_url}api/2.0/jobs/run-now \
  -H "Authorization: Bearer $pat_token" \
  -d "{\"job_id\": $job_id}")
run_id=$(jq .run_id -r <<< "$api_response")
#
# 7. Wait until jobs if finished (mainly dependent on step 6 to create cluster)
i=0
while [ $i -lt 10 ]
do
  echo "Time waited for job to finish: $i minutes"
  ((i++))
  api_response=$(curl -v -X GET ${workspace_id_url}api/2.0/jobs/runs/get\?run_id=$run_id \
    -H "Authorization: Bearer $token" \
    -H "X-Databricks-Azure-SP-Management-Token:$azToken" \
    -H "X-Databricks-Azure-Workspace-Resource-Id:$wsId"
  )
  state=$(jq .state.life_cycle_state -r <<< "$api_response")
  echo "job state: $state"
  if [[ "$state" == 'TERMINATED' || "$state" == 'SKIPPED' || "$state" == 'INTERNAL_ERROR' ]]; then
    break
  fi
  sleep 1m
done