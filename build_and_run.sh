#!/bin/bash

echo -e "*** BUILDING ***\n"
make clean
make micaz sim
echo -e "\n\n*** CREATING TOPOLOGY FILE ***\n"
java net.tinyos.sim.LinkLayerModel topoConfig.txt
echo -e "\n\n*** STARTING SIMULATION ***\n"
python run.py
