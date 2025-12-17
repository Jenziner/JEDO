package config

import (
	"fmt"
	"github.com/hyperledger-labs/fabric-token-sdk/token/services/ttx"
)

// ConnectToFabricSmartClient connects with Fabric Smart Client
func ConnectToFabricSmartClient() error {
	// Create a new View client

	// ToDo: Überprüfe in der Fabric Smart Client-Dokumentation, wie der View Client korrekt erstellt wird.
	fmt.Println("Fabric Smart Client connection placeholder")
	return nil
}

// CreateTransactionManager creats a Transaction for Token-Operations
func CreateTransactionManager() (*ttx.Transaction, error) {
	txManager, err := ttx.NewAnonymousTransaction(nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create transaction manager: %v", err)
	}
	return txManager, nil
}
