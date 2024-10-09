###############################################################
#!/bin/bash
#
# This file is the Help-File for up.sh.
#
#
###############################################################
up_help() {
    echo " Use: $(basename S0) [OPTIONS]"
    echo "Options:"
    echo "  -h          show help"
    echo "  -d          delete previous installation"
    echo "  -a          run all sections, choose one option"
    echo "  -r          run single section, choose one option"
    echo ""
    echo "Arguments for option -r (in required order)"
    echo "  prereq    checks all prerequisits"
    echo "  net       create docker network"
    echo "  ca        run CAs"
    echo "  cert      run enrollment to create certificates"
    echo "  cfg       run configuration (genesis block & channel configuration)"
    echo "  node      run all nodes (peer, cli, orderer)"
    echo "  orderer   run all orderers"
    echo "  peer      run all peers ans clis"
    echo "  ch        run channel"
    echo ""
    echo "Arguments for option -a"
    echo "  go        runs through all sections"
    echo "  pause     pauses after each section"

    exit 0
}
