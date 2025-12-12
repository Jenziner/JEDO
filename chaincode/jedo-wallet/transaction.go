package main

import (
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// Transfer transfers funds from one wallet to another
func (s *SmartContract) Transfer(ctx contractapi.TransactionContextInterface, fromWalletID string, toWalletID string, amount float64, description string) error {
	// Check caller is Human
	callerRole, err := getCallerRole(ctx)
	if err != nil {
		return err
	}

	if callerRole != "human" {
		return fmt.Errorf("only humans can transfer tokens")
	}

	// Validate amount
	if amount <= 0 {
		return fmt.Errorf("transfer amount must be positive")
	}

	// Get caller ID for ownership verification
	callerID, err := ctx.GetClientIdentity().GetID()
	if err != nil {
		return err
	}

	// Get source wallet
	fromWallet, err := s.GetWallet(ctx, fromWalletID)
	if err != nil {
		return fmt.Errorf("source wallet error: %v", err)
	}

	// Verify caller owns fromWallet (check if callerID contains ownerID)
	if !strings.Contains(callerID, fromWallet.OwnerID) {
		return fmt.Errorf("you can only transfer from your own wallet")
	}

	// Get destination wallet
	toWallet, err := s.GetWallet(ctx, toWalletID)
	if err != nil {
		return fmt.Errorf("destination wallet error: %v", err)
	}

	// Check if wallets are active
	if fromWallet.Status != "active" {
		return fmt.Errorf("source wallet %s is not active (status: %s)", fromWalletID, fromWallet.Status)
	}

	if toWallet.Status != "active" {
		return fmt.Errorf("destination wallet %s is not active (status: %s)", toWalletID, toWallet.Status)
	}

	// Check sufficient balance
	if fromWallet.Balance < amount {
		return fmt.Errorf("insufficient balance: wallet %s has %.2f but transfer requires %.2f", fromWalletID, fromWallet.Balance, amount)
	}

	// Perform transfer
	now := time.Now().UTC().Format(time.RFC3339)
	txID := ctx.GetStub().GetTxID()

	// Debit from source
	fromWallet.Balance -= amount
	fromWallet.UpdatedAt = now

	// Credit to destination
	toWallet.Balance += amount
	toWallet.UpdatedAt = now

	// Save updated wallets
	fromWalletJSON, err := json.Marshal(fromWallet)
	if err != nil {
		return err
	}

	toWalletJSON, err := json.Marshal(toWallet)
	if err != nil {
		return err
	}

	err = ctx.GetStub().PutState(fromWalletID, fromWalletJSON)
	if err != nil {
		return fmt.Errorf("failed to update source wallet: %v", err)
	}

	err = ctx.GetStub().PutState(toWalletID, toWalletJSON)
	if err != nil {
		return fmt.Errorf("failed to update destination wallet: %v", err)
	}

	// Record debit transaction
	debitTx := Transaction{
		DocType:      "transaction",
		TxID:         txID,
		WalletID:     fromWalletID,
		Type:         "transfer_out",
		Amount:       -amount,
		Balance:      fromWallet.Balance,
		Counterparty: toWalletID,
		Description:  description,
		Timestamp:    now,
	}

	debitKey, err := ctx.GetStub().CreateCompositeKey("transaction", []string{fromWalletID, txID})
	if err != nil {
		return err
	}

	debitJSON, err := json.Marshal(debitTx)
	if err != nil {
		return err
	}

	err = ctx.GetStub().PutState(debitKey, debitJSON)
	if err != nil {
		return err
	}

	// Record credit transaction
	creditTx := Transaction{
		DocType:      "transaction",
		TxID:         txID,
		WalletID:     toWalletID,
		Type:         "transfer_in",
		Amount:       amount,
		Balance:      toWallet.Balance,
		Counterparty: fromWalletID,
		Description:  description,
		Timestamp:    now,
	}

	creditKey, err := ctx.GetStub().CreateCompositeKey("transaction", []string{toWalletID, txID})
	if err != nil {
		return err
	}

	creditJSON, err := json.Marshal(creditTx)
	if err != nil {
		return err
	}

	err = ctx.GetStub().PutState(creditKey, creditJSON)
	if err != nil {
		return err
	}

	// Emit event
	eventPayload := map[string]interface{}{
		"txId":         txID,
		"fromWalletId": fromWalletID,
		"toWalletId":   toWalletID,
		"amount":       amount,
		"fromBalance":  fromWallet.Balance,
		"toBalance":    toWallet.Balance,
		"timestamp":    now,
	}

	eventJSON, _ := json.Marshal(eventPayload)
	ctx.GetStub().SetEvent("TransferCompleted", eventJSON)
	return nil
}

// Credit adds funds to a wallet (admin only - for minting)
func (s *SmartContract) Credit(ctx contractapi.TransactionContextInterface, walletID string, amount float64, description string) error {
	// Admin check
	if !isAdmin(ctx) {
		return fmt.Errorf("only admin can credit wallets")
	}

	if amount <= 0 {
		return fmt.Errorf("credit amount must be positive")
	}

	wallet, err := s.GetWallet(ctx, walletID)
	if err != nil {
		return err
	}

	if wallet.Status != "active" {
		return fmt.Errorf("wallet %s is not active", walletID)
	}

	now := time.Now().UTC().Format(time.RFC3339)
	wallet.Balance += amount
	wallet.UpdatedAt = now

	walletJSON, err := json.Marshal(wallet)
	if err != nil {
		return err
	}

	err = ctx.GetStub().PutState(walletID, walletJSON)
	if err != nil {
		return err
	}

	// Record transaction
	tx := Transaction{
		DocType:     "transaction",
		TxID:        ctx.GetStub().GetTxID(),
		WalletID:    walletID,
		Type:        "credit",
		Amount:      amount,
		Balance:     wallet.Balance,
		Description: description,
		Timestamp:   now,
	}

	txKey, err := ctx.GetStub().CreateCompositeKey("transaction", []string{walletID, ctx.GetStub().GetTxID()})
	if err != nil {
		return err
	}

	txJSON, err := json.Marshal(tx)
	if err != nil {
		return err
	}

	return ctx.GetStub().PutState(txKey, txJSON)
}

// Debit removes funds from a wallet (admin only - for burning)
func (s *SmartContract) Debit(ctx contractapi.TransactionContextInterface, walletID string, amount float64, description string) error {
	// Admin check
	if !isAdmin(ctx) {
		return fmt.Errorf("only admin can debit wallets")
	}

	if amount <= 0 {
		return fmt.Errorf("debit amount must be positive")
	}

	wallet, err := s.GetWallet(ctx, walletID)
	if err != nil {
		return err
	}

	if wallet.Status != "active" {
		return fmt.Errorf("wallet %s is not active", walletID)
	}

	if wallet.Balance < amount {
		return fmt.Errorf("insufficient balance")
	}

	now := time.Now().UTC().Format(time.RFC3339)
	wallet.Balance -= amount
	wallet.UpdatedAt = now

	walletJSON, err := json.Marshal(wallet)
	if err != nil {
		return err
	}

	err = ctx.GetStub().PutState(walletID, walletJSON)
	if err != nil {
		return err
	}

	// Record transaction
	tx := Transaction{
		DocType:     "transaction",
		TxID:        ctx.GetStub().GetTxID(),
		WalletID:    walletID,
		Type:        "debit",
		Amount:      -amount,
		Balance:     wallet.Balance,
		Description: description,
		Timestamp:   now,
	}

	txKey, err := ctx.GetStub().CreateCompositeKey("transaction", []string{walletID, ctx.GetStub().GetTxID()})
	if err != nil {
		return err
	}

	txJSON, err := json.Marshal(tx)
	if err != nil {
		return err
	}

	return ctx.GetStub().PutState(txKey, txJSON)
}
