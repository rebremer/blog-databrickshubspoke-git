#params
LOC="westeurope"
HUBRG="blog-storhub-rg"
HUBSUB="513a7987-b0d9-4106-a24d-4b3f49136ea8"
STOR="blogstorhubstor"
HUBVNET="blog-storhub-vnet"
HUBPE="storhubpe"
DNS="privatelink.dfs.core.windows.net"
#
az account set --subscription $HUBSUB
# Resource group
az group create -n $HUBRG -l $LOC
# Storage account
az storage account create -n $STOR -g $HUBRG -l $LOC --sku Standard_LRS --kind StorageV2 --enable-hierarchical-namespace true
az storage container create --account-name $STOR -n "defineddata"
az storage blob upload -f "../data/AdultCensusIncome.csv" -c "defineddata" -n "AdultCensusIncome.csv" --account-name $STOR 
#
az storage account update --resource-group $HUBRG --name $STOR --default-action Deny
# Hub VNET 
vnetaddressrange="10.200.0.0"
subnet1addressrange="10.200.0.0"
az network vnet create -g $HUBRG -n $HUBVNET --address-prefix $vnetaddressrange/16 -l $LOC
az network vnet subnet create -g $HUBRG --vnet-name $HUBVNET -n "default" --address-prefixes $subnet1addressrange/24
az network vnet subnet update -n "default" -g $HUBRG --vnet-name $HUBVNET --disable-private-endpoint-network-policies true
# Create Private link storage
resource_id="/subscriptions/$HUBSUB/resourceGroups/$HUBRG/providers/Microsoft.Storage/storageAccounts/$STOR"
az network private-endpoint create -g $HUBRG --group-id "dfs" --connection-name "cnstorhubpe" -n $HUBPE --vnet-name $HUBVNET --subnet "default" --private-connection-resource-id $resource_id -l $LOC
#
az network private-dns zone create -g ${HUBRG} --name ${DNS}
az network private-dns link vnet create -g ${HUBRG} -z ${DNS} -n "storhublink" --virtual-network ${HUBVNET} --registration-enabled false
az network private-endpoint dns-zone-group create -g ${HUBRG} --endpoint-name ${HUBPE} --name "storhubzone" --private-dns-zone ${DNS} --zone-name ${STOR}