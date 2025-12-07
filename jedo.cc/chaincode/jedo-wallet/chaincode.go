package main

import (
	"fmt"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// SmartContract provides functions for managing wallets
type SmartContract struct {
	contractapi.Contract
}

// InitLedger initializes the ledger with sample data (optional, for testing)
func (s *SmartContract) InitLedger(ctx contractapi.TransactionContextInterface) error {
	fmt.Println("Initializing JEDO Wallet Ledger")
	return nil
}

// GetContractVersion returns the version of the chaincode
func (s *SmartContract) GetContractVersion(ctx contractapi.TransactionContextInterface) string {
	return "1.0.0"
}

// Ping function for health checks
func (s *SmartContract) Ping(ctx contractapi.TransactionContextInterface) string {
	return "pong"
}
