package main

import (
	"encoding/json"
	"fmt"
	"time"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// validateWalletID validates the format of a wallet ID
func validateWalletID(walletID string) error {
	if walletID == "" {
		return fmt.Errorf("wallet ID cannot be empty")
	}
	if len(walletID) < 3 {
		return fmt.Errorf("wallet ID must be at least 3 characters")
	}
	if len(walletID) > 64 {
		return fmt.Errorf("wallet ID must not exceed 64 characters")
	}
	return nil
}

// validateOwnerID validates the format of an owner ID
func validateOwnerID(ownerID string) error {
	if ownerID == "" {
		return fmt.Errorf("owner ID cannot be empty")
	}
	if len(ownerID) < 3 {
		return fmt.Errorf("owner ID must be at least 3 characters")
	}
	return nil
}

// getCurrentTimestamp returns the current UTC timestamp in RFC3339 format
func getCurrentTimestamp() string {
	return time.Now().UTC().Format(time.RFC3339)
}

// DeleteWallet deletes a wallet (admin function, use with caution)
func (s *SmartContract) DeleteWallet(ctx contractapi.TransactionContextInterface, walletID string) error {
	wallet, err := s.GetWallet(ctx, walletID)
	if err != nil {
		return err
	}

	// Only allow deletion of wallets with zero balance
	if wallet.Balance != 0 {
		return fmt.Errorf("cannot delete wallet with non-zero balance (current: %.2f)", wallet.Balance)
	}

	// Mark as closed instead of deleting
	wallet.Status = "closed"
	wallet.UpdatedAt = getCurrentTimestamp()

	walletJSON, err := json.Marshal(wallet)
	if err != nil {
		return err
	}

	return ctx.GetStub().PutState(walletID, walletJSON)
}
