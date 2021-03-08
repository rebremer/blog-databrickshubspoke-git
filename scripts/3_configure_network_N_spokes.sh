#!/bin/bash
source params.sh
peer_hub_spoke () {
    #hub to spoke peering
    remote_vnet_spoke_id="/subscriptions/$2/resourceGroups/${SPOKERG}$1/providers/Microsoft.Network/virtualNetworks/${SPOKEVNET}$1"
    az network vnet peering create -n "spoke"$1"tohubpeering" --remote-vnet $remote_vnet_spoke_id -g ${HUBRG} --vnet-name ${HUBVNET} --allow-forwarded-traffic --allow-gateway-transit --allow-vnet-access --subscription ${HUBSUB}
    #spoke to hub peering
    remote_vnet_hub_id="/subscriptions/$HUBSUB/resourceGroups/$HUBRG/providers/Microsoft.Network/virtualNetworks/$HUBVNET"
    az network vnet peering create -n "hubtospoke"$1"peering" --remote-vnet $remote_vnet_hub_id -g ${SPOKERG}$1 --vnet-name ${SPOKEVNET}$1 --allow-forwarded-traffic --allow-gateway-transit --allow-vnet-access --subscription $2
    #
    az network private-dns link vnet create -g ${HUBRG} -z ${HUBDNS} -n "dbrspoke$1link" --virtual-network $remote_vnet_spoke_id --registration-enabled false --subscription ${HUBSUB}
}
##
num=1
while [ $num -le ${NUMBEROFSPOKES} ]; do
   pointer=$(((num-1)%NUMBEROFSPOKES))
   sub=${SPOKESUBARRAY[$pointer]}
   peer_hub_spoke $num $sub
   num=$(($num+1))
done