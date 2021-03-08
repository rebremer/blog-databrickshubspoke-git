#params
#general
LOC="westeurope"
NUMBEROFSPOKES=1
SUBARRAY=("513a7987-b0d9-4106-a24d-4b3f49136ea8" "7eaa6d9c-a4fd-45f3-8b5e-d69974580c43")
#hub
HUBRG="blog-storhub-rg"
HUBSUB="513a7987-b0d9-4106-a24d-4b3f49136ea8"
STOR="blogstorhubstor"
HUBVNET="blog-storhub-vnet"
DNS="privatelink.dfs.core.windows.net"
#spoke
SPOKERG="blog-dbrspoke-rg"
SPOKEVNET="blog-dbrspoke-vnet"
AKV="blog-dbrspoke-akv"
DBRWORKSPACE="blog-dbrspoke-dbr"
SPN="blog-dbrspoke-spn"
#
peer_hub_spoke () {
    #hub to spoke peering
    remote_vnet_spoke_id="/subscriptions/$2/resourceGroups/${SPOKERG}$1/providers/Microsoft.Network/virtualNetworks/${SPOKEVNET}$1"
    az network vnet peering create -n "spoke"$1"tohubpeering" --remote-vnet $remote_vnet_spoke_id -g ${HUBRG} --vnet-name ${HUBVNET} --allow-forwarded-traffic --allow-gateway-transit --allow-vnet-access
    #spoke to hub peering
    remote_vnet_hub_id="/subscriptions/$HUBSUB/resourceGroups/$HUBRG/providers/Microsoft.Network/virtualNetworks/$HUBVNET"
    az network vnet peering create -n "hubtospoke"$1"peering" --remote-vnet $remote_vnet_hub_id -g ${SPOKERG}$1 --vnet-name ${SPOKEVNET}$1 --allow-forwarded-traffic --allow-gateway-transit --allow-vnet-access --subscription $2
    #
    az network private-dns link vnet create -g ${HUBRG} -z ${DNS} -n "dbrspoke$1link" --virtual-network $remote_vnet_spoke_id --registration-enabled false
}
#
num=1
while [ $num -le $NUMBEROFSPOKES ]; do
   pointer=$((num%2))
   sub=${SUBARRAY[$pointer]}
	peer_hub_spoke $num $sub
	num=$(($num+1))
done