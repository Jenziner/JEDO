# Docker image for jedo-api
1. sudo docker build -t jedo-api .
2. 
```
    docker run -d \
    --name jedo-api \
    -p 3000:3000 \
    -v /mnt/user/appdata/jedo-api/wallet:/usr/src/app/wallet \
    -v /mnt/user/appdata/jedo-api/config:/usr/src/app/config \
    -e FABRIC_CONFIG_PATH="/usr/src/app/config/fabric-connection.go" \
    jedo-api
```


# DEBUG
## GO
- clean go `go mod tidy`





# Installation Token SDK Sample local
Do prerequisites according https://github.com/hyperledger/fabric-samples/tree/main/token-sdk
Install fabric 
``` curl -sSLO https://raw.githubusercontent.com/hyperledger/fabric/main/scripts/install-fabric.sh && chmod +x install-fabric.sh 
    ./install-fabric.sh docker binary
```
Install Tokengen `go install github.com/hyperledger-labs/fabric-token-sdk/cmd/tokengen@v0.3.0`
Set path `export PATH=/home/jenziner/Entwicklung/fabric/fabric-samples/bin:$PATH`
Check Version `fabric-ca-client version`
Go to Token SDK `/home/jenziner/Entwicklung/fabric/fabric-samples/token-sdk`
Quick start `./scripts/up.sh`
Open GUI `http://localhost:8080`

Quick del `./scripts/down.sh`


# tokengen
echo $GOPATH
ls ~/go/bin
export PATH=$PATH:~/go/bin
source ~/.bashrc
tokengen -h
cd /home/jenziner/Entwicklung/tokengen-output
tokengen gen fabtoken -s /home/jenziner/Entwicklung/tokengen-output/nik --cc -o /home/jenziner/Entwicklung/tokengen-output
cd /home/jenziner/Entwicklung/tokengen-output/fabric-smart-client
export FAB_BINS=/home/jenziner/Entwicklung/tokengen-output/fabric-samples/bin
tokengen artifacts -o /home/jenziner/Entwicklung/tokengen-output/testdata -t ./../fungible.yaml