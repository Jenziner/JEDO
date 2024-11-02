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
    echo "  -h              show help"
    echo "  -d              delete previous installation"
    echo "  -a              run all sections, choose one option"
    echo "  -r              run single section, choose one option"
    echo ""
    echo "Arguments for option -r (in required order)"
    echo "  prereq          checks all prerequisits"
    echo "  net             create docker network"
    echo "  root            run Root-CA"
    echo "  intermediate    run Intermediate-CAs"
    echo "  ca              run CAs"
    echo "  enroll          run enrollment to create certificates"
    echo "  config          run configuration (genesis block & channel configuration)"
    echo "  orderer         run all orderers"
    echo "  peer            run all peers ans clis"
    echo "  channel         run channel"
    echo ""
    echo "Arguments for option -a"
    echo "  go              runs through all sections"
    echo "  pause           pauses after each section"
    echo ""
    echo ""
    echo "********************"
    echo "Hosts:"
    get_hosts
    echo "$hosts_args" | sed 's/ --add-host=/\n--add-host=/g' | sed 's/=/= /g' | sed 's/:/ : /g'

    exit 0
}
