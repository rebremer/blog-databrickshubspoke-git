#params
#general
LOC="westeurope"
NUMBEROFSPOKES=1
SUBARRAY=("513a7987-b0d9-4106-a24d-4b3f49136ea8" "7eaa6d9c-a4fd-45f3-8b5e-d69974580c43")
#hub
HUBRG="blog-storhub-rg"
HUBSUB="513a7987-b0d9-4106-a24d-4b3f49136ea8"
STOR="blogstorhubstor"
#spoke
SPOKERG="blog-dbrspoke-rg"
SPOKEVNET="blog-dbrspoke-vnet"
AKV="blog-dbrspoke-akv"
DBRWORKSPACE="blog-dbrspoke-dbr"
SPN="blog-dbrspoke-spn"
#
create_spoke () {
   # Subscription
   az account set --subscription $2
   # Resource group
   az group create -n ${SPOKERG}$1 -l $LOC
   # Key vault
   az keyvault create -l $LOC -n ${AKV}$1 -g ${SPOKERG}$1 --enable-soft-delete false
   tenantId=$(az account show --query tenantId -o tsv)
   az keyvault secret set -n tenant-id --vault-name ${AKV}$1 --value $tenantId
   # Create SPN
   echo "Assigning Azure AD SPN to Databricks for authentication to storage account"
   spn_response=$(az ad sp create-for-rbac -n ${SPN}$1 --skip-assignment)
   spn_id=$(jq .appId -r <<< "$spn_response")
   spn_key=$(jq .password -r <<< "$spn_response")
   # Add credentials of SPN to key vault
   az keyvault secret set -n spn-id --vault-name ${AKV}$1 --value $spn_id
   az keyvault secret set -n spn-key --vault-name ${AKV}$1 --value $spn_key
   # Add RBAC role to storage account
   spn_response=$(az ad sp show --id $spn_id)
   spn_object_id=$(jq .objectId -r <<< "$spn_response")
   scope="/subscriptions/$HUBSUB/resourceGroups/$HUBRG/providers/Microsoft.Storage/storageAccounts/$STOR"
   az role assignment create --assignee-object-id $spn_object_id --role "Storage Blob Data Contributor" --scope $scope
   #
   # Databricks
   az extension add --name databricks
   dbr_response=$(az databricks workspace show -g ${SPOKERG}$1 -n ${DBRWORKSPACE}$1)
   if ["$dbr_response" = ""]; then
      vnetaddressrange="10.21"$1".0.0"
      subnet1addressrange="10.21"$1".0.0"
      subnet2addressrange="10.21"$1".1.0"
      az network vnet create -g ${SPOKERG}$1 -n ${SPOKEVNET}$1 --address-prefix $vnetaddressrange/16 -l $LOC  
      az network nsg create -g ${SPOKERG}$1 -n "public-subnet-nsg"
      az network nsg create -g ${SPOKERG}$1 -n "private-subnet-nsg"
      az network vnet subnet create -g ${SPOKERG}$1 --vnet-name ${SPOKEVNET}$1 -n "public-subnet" --address-prefixes $subnet1addressrange/24 --network-security-group "public-subnet-nsg"
      az network vnet subnet create -g ${SPOKERG}$1 --vnet-name ${SPOKEVNET}$1 -n "private-subnet" --address-prefixes $subnet2addressrange/24 --network-security-group "private-subnet-nsg"
      az network vnet subnet update --resource-group ${SPOKERG}$1 --name "public-subnet" --vnet-name ${SPOKEVNET}$1 --delegations Microsoft.Databricks/workspaces
      az network vnet subnet update --resource-group ${SPOKERG}$1 --name "private-subnet" --vnet-name ${SPOKEVNET}$1 --delegations Microsoft.Databricks/workspaces
      dbr_response=$(az databricks workspace create -l $LOC -n ${DBRWORKSPACE}$1 -g ${SPOKERG}$1 --sku premium --vnet ${SPOKEVNET}$1 --public-subnet "public-subnet" --private-subnet "private-subnet")
   fi
}
#
num=1
while [ $num -le $NUMBEROFSPOKES ]; do
   pointer=$((num%2))
   sub=${SUBARRAY[$pointer]}
	create_spoke $num $sub
	num=$(($num+1))
done