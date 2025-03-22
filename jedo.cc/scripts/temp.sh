###############################################################
#!/bin/bash
#
# Temporary script.
#
#
###############################################################


###############################################################
# Manual statement collection
###############################################################

# Logs
docker logs ca.alps.ea.jedo.cc
docker logs orderer.alps.ea.jedo.cc
docker logs peer.alps.ea.jedo.cc

# Version
docker exec -i cli.peer.alps.ea.jedo.cc peer version
docker exec -i peer.alps.ea.jedo.cc peer version
docker exec -i orderer.alps.ea.jedo.cc orderer version

# Channel
docker exec -i cli.peer.alps.ea.jedo.cc peer channel join -b /var/hyperledger/configuration/genesisblock
docker exec -i cli.peer.alps.ea.jedo.cc peer channel list


