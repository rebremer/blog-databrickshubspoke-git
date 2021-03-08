#!/bin/bash
source params.sh
mount_storage (){
  # 1a. Get tenantID and resource id
  tenantId=$(az account show --query tenantId -o tsv)
  wsId=$(az resource show \
    --resource-type Microsoft.Databricks/workspaces \
    -g "${SPOKERG}$1" \
    -n "${SPOKEDBRWORKSPACE}$1" \
    --query id -o tsv)
  # 1b. Get two bearer tokens in Azure
  token_response=$(az account get-access-token --resource 2ff814a6-3304-4ab8-85cb-cd0e6f879c1d)
  token=$(jq .accessToken -r <<< "$token_response")
  token_response=$(az account get-access-token --resource https://management.core.windows.net/)
  azToken=$(jq .accessToken -r <<< "$token_response")
  #
  # Databricks
  dbr_response=$(az databricks workspace show -g ${SPOKERG}$1 -n ${SPOKEDBRWORKSPACE}$1)
  workspaceUrl_no_http=$(jq .workspaceUrl -r <<< "$dbr_response")
  workspace_id_url="https://"$workspaceUrl_no_http"/"
  #
  # 2. Upload notebook to Databricks Workspace
  api_response=$(curl -v -X POST ${workspace_id_url}api/2.0/workspace/import \
    -H "Authorization: Bearer $token" \
    -H "X-Databricks-Azure-SP-Management-Token:$azToken" \
    -H "X-Databricks-Azure-Workspace-Resource-Id:$wsId" \
    -F path="/mount_storage.py" -F format=SOURCE -F language=PYTHON -F overwrite=true -F content=@../notebooks/mount_storage.py)
  #
  # 3.1 Secret scope
  api_response=$(curl -v -X POST ${workspace_id_url}api/2.0/secrets/scopes/create \
    -H "Authorization: Bearer $token" \
    -H "X-Databricks-Azure-SP-Management-Token:$azToken" \
    -H "X-Databricks-Azure-Workspace-Resource-Id:$wsId" \
    -d "{\"scope\": \"dbrkeys\"}")
  # 3.2. Move keys from key vault to Databricks backed secret scope
  keyvault_response=$(az keyvault secret show -n spn-id --vault-name ${SPOKEAKV}$1)
  spn_id=$(jq .value -r <<< "$keyvault_response")
  keyvault_response=$(az keyvault secret show -n spn-key --vault-name ${SPOKEAKV}$1)
  spn_key=$(jq .value -r <<< "$keyvault_response")
  keyvault_response=$(az keyvault secret show -n tenant-id --vault-name ${SPOKEAKV}$1)
  tenant_id=$(jq .value -r <<< "$keyvault_response")
  api_response=$(curl -v -X POST ${workspace_id_url}api/2.0/secrets/put \
    -H "Authorization: Bearer $token" \
    -H "X-Databricks-Azure-SP-Management-Token:$azToken" \
    -H "X-Databricks-Azure-Workspace-Resource-Id:$wsId" \
    -d "{\"scope\": \"dbrkeys\", \"key\": \"spn-id\", \"string_value\": \"$spn_id\"}")
  api_response=$(curl -v -X POST ${workspace_id_url}api/2.0/secrets/put \
    -H "Authorization: Bearer $token" \
    -H "X-Databricks-Azure-SP-Management-Token:$azToken" \
    -H "X-Databricks-Azure-Workspace-Resource-Id:$wsId" \
    -d "{\"scope\": \"dbrkeys\", \"key\": \"spn-key\", \"string_value\": \"$spn_key\"}")
  api_response=$(curl -v -X POST ${workspace_id_url}api/2.0/secrets/put \
    -H "Authorization: Bearer $token" \
    -H "X-Databricks-Azure-SP-Management-Token:$azToken" \
    -H "X-Databricks-Azure-Workspace-Resource-Id:$wsId" \
    -d "{\"scope\": \"dbrkeys\", \"key\": \"tenant-id\", \"string_value\": \"$tenant_id\"}")
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
    -d "{\"name\": \"mount storage\", \"existing_cluster_id\": \"$cluster_id\", \"notebook_task\": {\"notebook_path\": \"/mount_storage.py\", \"base_parameters\": [{\"key\":\"stor_name\", \"value\":\"${HUBSTOR}\"}, {\"key\":\"container_name\", \"value\":\"${FILESYSTEM}$1\"}, {\"key\":\"private_link_dns\", \"value\":\"${HUBDNS}\"}]}}")
  job_id=$(jq .job_id -r <<< "$api_response")
  #
  # 6. Run job to run notebook to mount storage
  api_response=$(curl -v -X POST ${workspace_id_url}api/2.0/jobs/run-now \
    -H "Authorization: Bearer $token" \
    -H "X-Databricks-Azure-SP-Management-Token:$azToken" \
    -H "X-Databricks-Azure-Workspace-Resource-Id:$wsId" \
    -d "{\"job_id\": $job_id}")
  run_id=$(jq .run_id -r <<< "$api_response")

}
#
num=1
while [ $num -le ${NUMBEROFSPOKES} ]; do
   pointer=$(((num-1)%NUMBEROFSPOKES))
   sub=${SPOKESUBARRAY[$pointer-1]}
   mount_storage $num $sub
   num=$(($num+1))
done