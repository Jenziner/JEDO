package main

import (
	"fmt"
	"log"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

func main() {
	walletChaincode, err := contractapi.NewChaincode(&SmartContract{})
	if err != nil {
		log.Panicf("Error creating jedo-wallet chaincode: %v", err)
	}

	if err := walletChaincode.Start(); err != nil {
		log.Panicf("Error starting jedo-wallet chaincode: %v", err)
	}

	fmt.Println("JEDO Wallet Chaincode started successfully")
}
