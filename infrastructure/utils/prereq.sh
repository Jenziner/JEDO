###############################################################
#!/bin/bash
#
# This script checks prerequisites
# Documentation: https://hyperledger-fabric.readthedocs.io
#
###############################################################
source ./utils/utils.sh
source ./utils/help.sh
check_script

echo_warn "Prerequisites checking..."

###############################################################
# Help with prerequisits
###############################################################
inst_help_yq() {
    echo "installation: sudo wget https://github.com/mikefarah/yq/releases/download/v4.6.3/yq_linux_amd64 -O /usr/local/bin/yq"
    echo "make it executable: chmod +x /usr/local/bin/yq"
}
inst_help_libtool() {
    echo "installation: sudo apt install libtool"
}
inst_help_libltdel-dev() {
    echo "installation: sudo apt install libltdl-dev"
}
inst_help_docker() {
    echo "installation: sudo apt sudo apt install docker.io"
}
inst_help_git() {
    echo "installation: sudo apt install git"
}
inst_help_go() {
    echo "installation:"
    echo "1. wget https://go.dev/dl/$(wget -qO- https://go.dev/VERSION?m=text).linux-amd64.tar.gz"
    echo "2. sudo tar -C /usr/local -xzf go*.linux-amd64.tar.gz"
    echo "3. echo "export PATH=\$PATH:/usr/local/go/bin" >> ~/.bashrc"
    echo "4. source ~/.bashrc"
}
inst_help_orderer() {
    echo "Orderer installation is part of the Hyperledger Fabric binaries. Follow the official documentation to download the binaries: https://hyperledger-fabric.readthedocs.io"
}
inst_help_peer() {
    echo "Peer installation is part of the Hyperledger Fabric binaries. Follow the official documentation to download the binaries: https://hyperledger-fabric.readthedocs.io"
}
inst_help_configtxgen() {
    echo "Configtxgen installation is part of the Hyperledger Fabric binaries. Follow the official documentation to download the binaries: https://hyperledger-fabric.readthedocs.io"
}
inst_help_configtxlator() {
    echo "Configtxlator installation is part of the Hyperledger Fabric binaries. Follow the official documentation to download the binaries: https://hyperledger-fabric.readthedocs.io"
}
inst_help_cryptogen() {
    echo "Cryptogen installation is part of the Hyperledger Fabric binaries. Follow the official documentation to download the binaries: https://hyperledger-fabric.readthedocs.io"
}

###############################################################
# Check prerequisits
###############################################################
check_command() {
    local command="$1"
    if ! command -v "$command" &> /dev/null; then
        echo_error "$command is not installed"
        inst_help_${command//-/_}
        exit 1
    else
        echo ""
        echo_ok "$command is installed:"
        # try to print version
        if "$command" version &> /dev/null; then
            "$command" version
        elif "$command" --version &> /dev/null; then
            "$command" --version
        elif "$command" -v &> /dev/null; then
            "$command" -v
        else
            echo_warn "no version information is not available."
        fi
    fi
}

# checks
check_command yq
#check_command libtool
#check_command libltdl-dev
check_command docker
check_command git
check_command go
check_command orderer
check_command peer
check_command configtxgen
check_command configtxlator
check_command cryptogen

echo_ok "Prerequisites checked."