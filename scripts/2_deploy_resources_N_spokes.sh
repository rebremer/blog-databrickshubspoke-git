#!/bin/bash
source params.sh
create_spoke () {
   # Subscription
   az account set --subscription $2
   # Resource group
   az group create -n ${SPOKERG}$1 -l $LOC
   # Key vault
   az keyvault create -l $LOC -n ${SPOKEAKV}$1 -g ${SPOKERG}$1 --enable-soft-delete false
   tenantId=$(az account show --query tenantId -o tsv)
   az keyvault secret set -n tenant-id --vault-name ${SPOKEAKV}$1 --value $tenantId
   # Create SPN
   echo "Assigning Azure AD SPN to Databricks for authentication to storage account"
   spn_response=$(az ad sp create-for-rbac -n ${SPOKESPN}$1 --skip-assignment)
   spn_id=$(jq .appId -r <<< "$spn_response")
   spn_key=$(jq .password -r <<< "$spn_response")
   # Add credentials of SPN to key vault
   az keyvault secret set -n spn-id --vault-name ${SPOKEAKV}$1 --value $spn_id
   az keyvault secret set -n spn-key --vault-name ${SPOKEAKV}$1 --value $spn_key
   # Add RBAC role to storage account
   az storage container create --account-name $HUBSTOR -n ${SPOKEFILESYSTEM}$1 --subscription ${HUBSUB}
   az storage blob upload -f "../data/AdultCensusIncome.csv" -c ${SPOKEFILESYSTEM}$1 -n "AdultCensusIncome.csv" --account-name ${HUBSTOR} --subscription ${HUBSUB}
   #
   spn_response=$(az ad sp show --id $spn_id)
   spn_object_id=$(jq .objectId -r <<< "$spn_response")
   scope="/subscriptions/$HUBSUB/resourceGroups/$HUBRG/providers/Microsoft.Storage/storageAccounts/$HUBSTOR/blobServices/default/containers/${SPOKEFILESYSTEM}$1"
   az role assignment create --assignee-object-id $spn_object_id --role "Storage Blob Data Contributor" --scope $scope
   #
   # Databricks
   az extension add --name databricks
   dbr_response=$(az databricks workspace show -g ${SPOKERG}$1 -n ${SPOKEDBRWORKSPACE}$1)
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
      dbr_response=$(az databricks workspace create -l $LOC -n ${SPOKEDBRWORKSPACE}$1 -g ${SPOKERG}$1 --sku premium --vnet ${SPOKEVNET}$1 --public-subnet "public-subnet" --private-subnet "private-subnet" --enable-no-public-ip true)
   fi
}
#
num=1
while [ $num -le $NUMBEROFSPOKES ]; do
   pointer=$(((num-1)%NUMBEROFSPOKES))
   sub=${SPOKESUBARRAY[$pointer]}
	create_spoke $num $sub
	num=$(($num+1))
done
# Finally, lock down storage account
az storage account update --resource-group $HUBRG --name $HUBSTOR --default-action Deny --bypass None --subscription $HUBSUB
