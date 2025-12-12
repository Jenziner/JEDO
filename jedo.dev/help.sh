###############################################################
#!/bin/bash
#
# This file is the Help-File for up.sh.
#
#
###############################################################
up_help() {
    echo -e "Use: $(basename S0) [OPTIONS]"
    echo -e "Options:"
    echo -e "  -h              show help"
    echo -e "  -d              delete previous installation"
    echo -e "  -a              run all sections, choose one option"
    echo -e "  -r              run single section, choose one option"
    echo -e ""
    echo -e "Arguments for option -r (in required order)"
    echo -e "  prereq          checks all prerequisits"
    echo -e "  net             create docker network"
    echo -e "  ca              run CAs"
    echo -e "  orderer         run all orderers"
    echo -e "  peer            run all peers ans clis"
    echo -e "  config          run configuration (genesis block & channel configuration)"
    echo -e "  channel         run channel"
    echo -e "  enroll          run enrollment to create certificates"
    echo -e "  wallet          run Chaincode jedo-wallet"
    echo -e "  gateway         run API-Gateway and Services"
    echo -e ""
    echo -e "Arguments for option -a${NC}"
    echo -e "  go              runs through all sections"
    echo -e "  pause           pauses after each section"
    echo -e ""
    echo -e ""
    echo -e "********************"
    echo -e "Hosts:"
    get_hosts
    echo -e "$hosts_args" | sed 's/ --add-host=/\n--add-host=/g' | sed 's/=/= /g' | sed 's/:/ : /g'

    exit 0
}
