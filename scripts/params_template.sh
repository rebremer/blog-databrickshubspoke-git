#!/bin/bash
# Set params
# general
LOC="westeurope"
# hub (1)
HUBSTOR="blogstorhubstor" # unique name
HUBRG="blog-storhub-rg"
HUBSUB="<<your subscripton id>>"
HUBVNET="blog-storhub-vnet"
HUBPE="storhubpe"
HUBDNS="privatelink.dfs.core.windows.net"
# spoke (N)
NUMBEROFSPOKES=2
# minimally 1 subscription
SPOKESUBARRAY=("<<your subscripton id 1>>" "<<id 2, etc>>")
SPOKERG="blog-dbrspoke-rg"
SPOKEVNET="blog-dbrspoke-vnet"
SPOKEAKV="blog-dbrspoke-akv"
SPOKEDBRWORKSPACE="blog-dbrspoke-dbr"
SPOKESPN="blog-dbrspoke-spn"
SPOKEFILESYSTEM="dbrspoke"