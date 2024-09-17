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
