#!/bin/bash
./1_deploy_resources_1_hub.sh
./2_deploy_resources_N_spokes.sh
./3_configure_network_N_spokes.sh
./4_mount_storage_N_spokes.sh