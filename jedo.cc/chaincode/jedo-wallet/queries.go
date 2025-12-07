package main

import (
	"encoding/json"
	"fmt"
	"strings"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// GetWalletHistory returns the transaction history for a wallet (only owner can view)
func (s *SmartContract) GetWalletHistory(ctx contractapi.TransactionContextInterface, walletID string, limit int) ([]*Transaction, error) {
	// Access control - only owner or admin
	callerRole, err := getCallerRole(ctx)
	if err != nil {
		return nil, err
	}

	callerID, err := ctx.GetClientIdentity().GetID()
	if err != nil {
		return nil, err
	}

	// Check if wallet exists
	wallet, err := s.GetWallet(ctx, walletID)
	if err != nil {
		return nil, err
	}

	// Only wallet owner or admin can view history
	if callerRole != "admin" && !strings.Contains(callerID, wallet.OwnerID) {
		return nil, fmt.Errorf("you can only view your own wallet history")
	}

	// Query transactions using composite key
	resultsIterator, err := ctx.GetStub().GetStateByPartialCompositeKey("transaction", []string{walletID})
	if err != nil {
		return nil, fmt.Errorf("failed to get transaction history: %v", err)
	}
	defer resultsIterator.Close()

	var transactions []*Transaction
	count := 0

	for resultsIterator.HasNext() && (limit == 0 || count < limit) {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return nil, err
		}

		var tx Transaction
		err = json.Unmarshal(queryResponse.Value, &tx)
		if err != nil {
			return nil, err
		}

		transactions = append(transactions, &tx)
		count++
	}

	return transactions, nil
}

// GetWalletsByGens returns all wallets for humans belonging to a specific gens
func (s *SmartContract) GetWalletsByGens(ctx contractapi.TransactionContextInterface, gensID string) ([]*Wallet, error) {
	// Only gens or admin can query
	callerRole, err := getCallerRole(ctx)
	if err != nil {
		return nil, err
	}

	if callerRole == "admin" {
		// Admin OK
	} else if callerRole == "gens" {
		// Verify caller is the requested gens
		callerID, err := ctx.GetClientIdentity().GetID()
		if err != nil {
			return nil, err
		}

		if !strings.Contains(callerID, gensID) {
			return nil, fmt.Errorf("you can only query your own humans' wallets")
		}
	} else {
		return nil, fmt.Errorf("only admin or gens can query wallets by gens")
	}

	// CouchDB rich query - match wallets where ownerId contains gensID
	queryString := fmt.Sprintf(`{
		"selector": {
			"docType": "wallet",
			"ownerId": {
				"$regex": ".*\\.%s\\..*"
			}
		}
	}`, gensID)

	resultsIterator, err := ctx.GetStub().GetQueryResult(queryString)
	if err != nil {
		return nil, fmt.Errorf("failed to query wallets: %v", err)
	}
	defer resultsIterator.Close()

	var wallets []*Wallet
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return nil, err
		}

		var wallet Wallet
		err = json.Unmarshal(queryResponse.Value, &wallet)
		if err != nil {
			return nil, err
		}

		wallets = append(wallets, &wallet)
	}

	return wallets, nil
}

// GetWalletsByHuman returns all wallets belonging to a specific human
func (s *SmartContract) GetWalletsByHuman(ctx contractapi.TransactionContextInterface, humanID string) ([]*Wallet, error) {
	// Only human himself or admin can query
	callerRole, err := getCallerRole(ctx)
	if err != nil {
		return nil, err
	}

	if callerRole == "admin" {
		// Admin OK
	} else if callerRole == "human" {
		// Verify caller is the requested human
		callerID, _ := ctx.GetClientIdentity().GetID()
		if !strings.Contains(callerID, humanID) {
			return nil, fmt.Errorf("you can only query your own wallets")
		}
	} else {
		return nil, fmt.Errorf("only admin or human can query wallets by human")
	}

	queryString := fmt.Sprintf(`{
		"selector": {
			"docType": "wallet",
			"ownerId": "%s"
		}
	}`, humanID)

	resultsIterator, err := ctx.GetStub().GetQueryResult(queryString)
	if err != nil {
		return nil, fmt.Errorf("failed to query wallets: %v", err)
	}
	defer resultsIterator.Close()

	var wallets []*Wallet
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return nil, err
		}

		var wallet Wallet
		err = json.Unmarshal(queryResponse.Value, &wallet)
		if err != nil {
			return nil, err
		}

		wallets = append(wallets, &wallet)
	}

	return wallets, nil
}

// GetAllWallets returns all wallets (admin only)
func (s *SmartContract) GetAllWallets(ctx contractapi.TransactionContextInterface) ([]*Wallet, error) {
	// Admin check
	if !isAdmin(ctx) {
		return nil, fmt.Errorf("only admin can list all wallets")
	}

	queryString := `{
		"selector": {
			"docType": "wallet"
		}
	}`

	resultsIterator, err := ctx.GetStub().GetQueryResult(queryString)
	if err != nil {
		return nil, fmt.Errorf("failed to query all wallets: %v", err)
	}
	defer resultsIterator.Close()

	var wallets []*Wallet
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return nil, err
		}

		var wallet Wallet
		err = json.Unmarshal(queryResponse.Value, &wallet)
		if err != nil {
			return nil, err
		}

		wallets = append(wallets, &wallet)
	}

	return wallets, nil
}

// GetTotalBalance returns the sum of all wallet balances (admin only)
func (s *SmartContract) GetTotalBalance(ctx contractapi.TransactionContextInterface) (float64, error) {
	// Admin check
	if !isAdmin(ctx) {
		return 0, fmt.Errorf("only admin can get total balance")
	}

	wallets, err := s.GetAllWallets(ctx)
	if err != nil {
		return 0, err
	}

	var total float64
	for _, wallet := range wallets {
		total += wallet.Balance
	}

	return total, nil
}

// Gens represents a gens (business) entity
type Gens struct {
	DocType   string `json:"docType"`
	GensID    string `json:"gensId"`
	Name      string `json:"name"`
	CreatedAt string `json:"createdAt"`
	Status    string `json:"status"`
}

// ListGens returns all registered gens (admin only)
func (s *SmartContract) ListGens(ctx contractapi.TransactionContextInterface) ([]*Gens, error) {
	if !isAdmin(ctx) {
		return nil, fmt.Errorf("only admin can list gens")
	}

	queryString := `{
		"selector": {
			"docType": "gens"
		}
	}`

	resultsIterator, err := ctx.GetStub().GetQueryResult(queryString)
	if err != nil {
		return nil, fmt.Errorf("failed to query gens: %v", err)
	}
	defer resultsIterator.Close()

	var gensList []*Gens
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return nil, err
		}

		var gens Gens
		err = json.Unmarshal(queryResponse.Value, &gens)
		if err != nil {
			return nil, err
		}

		gensList = append(gensList, &gens)
	}

	return gensList, nil
}

// RegisterGens creates a new gens entry (admin only)
func (s *SmartContract) RegisterGens(ctx contractapi.TransactionContextInterface, gensID string, name string) error {
	if !isAdmin(ctx) {
		return fmt.Errorf("only admin can register gens")
	}

	gens := Gens{
		DocType:   "gens",
		GensID:    gensID,
		Name:      name,
		CreatedAt: getCurrentTimestamp(),
		Status:    "active",
	}

	gensJSON, err := json.Marshal(gens)
	if err != nil {
		return err
	}

	return ctx.GetStub().PutState(gensID, gensJSON)
}
