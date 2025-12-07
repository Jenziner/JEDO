package main

import (
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// Wallet represents a wallet asset on the blockchain
type Wallet struct {
	DocType   string            `json:"docType"`  // docType is used to distinguish the various types of objects in state database
	WalletID  string            `json:"walletId"` // Unique wallet identifier
	OwnerID   string            `json:"ownerId"`  // Owner identifier (e.g., hans.worb.alps.ea.jedo.cc)
	Balance   float64           `json:"balance"`  // Current balance
	Currency  string            `json:"currency"` // Currency type (default: JEDO)
	Status    string            `json:"status"`   // active, frozen, closed
	CreatedAt string            `json:"createdAt"` // ISO 8601 timestamp
	UpdatedAt string            `json:"updatedAt"` // ISO 8601 timestamp
	Metadata  map[string]string `json:"metadata"`  // Additional metadata
}

// Transaction represents a transaction record
type Transaction struct {
	DocType      string  `json:"docType"`
	TxID         string  `json:"txId"`
	WalletID     string  `json:"walletId"`
	Type         string  `json:"type"` // credit, debit, transfer_in, transfer_out
	Amount       float64 `json:"amount"`
	Balance      float64 `json:"balance"` // Balance after transaction
	Counterparty string  `json:"counterparty"` // Other wallet involved (for transfers)
	Description  string  `json:"description"`
	Timestamp    string  `json:"timestamp"`
}

// HistoryQueryResult structure used for returning result of history query
type HistoryQueryResult struct {
	Record    *Wallet `json:"record"`
	TxID      string  `json:"txId"`
	Timestamp string  `json:"timestamp"`
	IsDelete  bool    `json:"isDelete"`
}

// WalletExists checks if a wallet exists in the world state
func (s *SmartContract) WalletExists(ctx contractapi.TransactionContextInterface, walletID string) (bool, error) {
	walletJSON, err := ctx.GetStub().GetState(walletID)
	if err != nil {
		return false, fmt.Errorf("failed to read from world state: %v", err)
	}

	return walletJSON != nil, nil
}

// CreateWallet creates a new wallet (only gens can create wallets for their humans)
func (s *SmartContract) CreateWallet(
    ctx contractapi.TransactionContextInterface,
    walletID string,
    ownerID string,
    initialBalance float64,
    metadataJSON string,
) error {
    // Check caller is Gens
    callerRole, err := getCallerRole(ctx)
    if err != nil {
        return err
    }
    if callerRole != "gens" {
        return fmt.Errorf("only gens can create wallets")
    }

    // Verify gens can only create wallets for their own humans
    callerID, err := ctx.GetClientIdentity().GetID()
    if err != nil {
        return err
    }

    // Extract gens name from caller (e.g., "CN=worb.alps.ea.jedo.cc" -> "worb")
    gensName := ""
    parts := strings.Split(callerID, ",")
    for _, part := range parts {
        if strings.HasPrefix(strings.TrimSpace(part), "CN=") {
            cn := strings.TrimPrefix(strings.TrimSpace(part), "CN=")
            cnParts := strings.Split(cn, ".")
            if len(cnParts) > 0 {
                gensName = cnParts[0]
            }
            break
        }
    }

    // Check if ownerID belongs to this gens (must contain gensName)
    if gensName != "" &&
        !strings.Contains(ownerID, "."+gensName+".") &&
        !strings.HasPrefix(ownerID, gensName+".") {
        return fmt.Errorf("you can only create wallets for your own humans")
    }

    // Validate IDs
    if err := validateWalletID(walletID); err != nil {
        return err
    }
    if err := validateOwnerID(ownerID); err != nil {
        return err
    }

    // Check if wallet already exists
    exists, err := s.WalletExists(ctx, walletID)
    if err != nil {
        return err
    }
    if exists {
        return fmt.Errorf("wallet %s already exists", walletID)
    }

    // Validate inputs
    if initialBalance < 0 {
        return fmt.Errorf("initial balance cannot be negative")
    }

    // Parse metadata (ensure non-nil map)
    metadata := make(map[string]string)
    if strings.TrimSpace(metadataJSON) != "" {
        if err := json.Unmarshal([]byte(metadataJSON), &metadata); err != nil {
            return fmt.Errorf("failed to parse metadata: %v", err)
        }
        if metadata == nil {
            metadata = make(map[string]string)
        }
    }

    // Create wallet
    now := time.Now().UTC().Format(time.RFC3339)
    wallet := Wallet{
        DocType:   "wallet",
        WalletID:  walletID,
        OwnerID:   ownerID,
        Balance:   initialBalance,
        Currency:  "JEDO",
        Status:    "active",
        CreatedAt: now,
        UpdatedAt: now,
        Metadata:  metadata, // niemals nil
    }

    walletJSON, err := json.Marshal(wallet)
    if err != nil {
        return err
    }

    // Save wallet to state
    if err := ctx.GetStub().PutState(walletID, walletJSON); err != nil {
        return fmt.Errorf("failed to put wallet to world state: %v", err)
    }

    // Record initial transaction if balance > 0
    if initialBalance > 0 {
        tx := Transaction{
            DocType:     "transaction",
            TxID:        ctx.GetStub().GetTxID(),
            WalletID:    walletID,
            Type:        "credit",
            Amount:      initialBalance,
            Balance:     initialBalance,
            Description: "Initial balance",
            Timestamp:   now,
        }

        txKey, err := ctx.GetStub().CreateCompositeKey(
            "transaction",
            []string{walletID, ctx.GetStub().GetTxID()},
        )
        if err != nil {
            return fmt.Errorf("failed to create composite key: %v", err)
        }

        txJSON, err := json.Marshal(tx)
        if err != nil {
            return err
        }

        if err := ctx.GetStub().PutState(txKey, txJSON); err != nil {
            return fmt.Errorf("failed to save transaction: %v", err)
        }
    }

    // Emit event
    eventPayload := map[string]interface{}{
        "walletId":       walletID,
        "ownerId":        ownerID,
        "initialBalance": initialBalance,
        "timestamp":      now,
    }
    eventJSON, _ := json.Marshal(eventPayload)
    _ = ctx.GetStub().SetEvent("WalletCreated", eventJSON)

    return nil
}

// GetWallet retrieves a wallet from the world state (internal function, no access control)
func (s *SmartContract) GetWallet(
    ctx contractapi.TransactionContextInterface,
    walletID string,
) (*Wallet, error) {
    // Validate wallet ID
    if err := validateWalletID(walletID); err != nil {
        return nil, err
    }

    // Get wallet from state
    walletJSON, err := ctx.GetStub().GetState(walletID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if walletJSON == nil {
        return nil, fmt.Errorf("wallet %s does not exist", walletID)
    }

    // Unmarshal wallet
    var wallet Wallet
    if err := json.Unmarshal(walletJSON, &wallet); err != nil {
        return nil, fmt.Errorf("failed to unmarshal wallet: %v", err)
    }

    // Ensure Metadata is never nil (fix for schema validation)
    if wallet.Metadata == nil {
        wallet.Metadata = make(map[string]string)
    }

    return &wallet, nil
}

// GetBalance retrieves the balance of a wallet (only human owner can check their own wallet)
func (s *SmartContract) GetBalance(ctx contractapi.TransactionContextInterface, walletID string) (float64, error) {
	// Check caller is Human
	callerRole, err := getCallerRole(ctx)
	if err != nil {
		return 0, err
	}

	if callerRole != "human" {
		return 0, fmt.Errorf("only humans can check balance")
	}

	// Get caller ID
	callerID, err := ctx.GetClientIdentity().GetID()
	if err != nil {
		return 0, err
	}

	// Get wallet
	wallet, err := s.GetWallet(ctx, walletID)
	if err != nil {
		return 0, err
	}

	// Verify caller owns wallet
	if !strings.Contains(callerID, wallet.OwnerID) {
		return 0, fmt.Errorf("you can only check your own balance")
	}

	return wallet.Balance, nil
}

// UpdateWallet updates wallet metadata (only owner can update)
func (s *SmartContract) UpdateWallet(ctx contractapi.TransactionContextInterface, walletID string, metadataJSON string) error {
	// Access control
	callerRole, err := getCallerRole(ctx)
	if err != nil {
		return err
	}

	callerID, err := ctx.GetClientIdentity().GetID()
	if err != nil {
		return err
	}

	wallet, err := s.GetWallet(ctx, walletID)
	if err != nil {
		return err
	}

	// Only wallet owner or admin can update
	if callerRole != "admin" && !strings.Contains(callerID, wallet.OwnerID) {
		return fmt.Errorf("you can only update your own wallet")
	}

	// Parse new metadata
	var newMetadata map[string]string
	err = json.Unmarshal([]byte(metadataJSON), &newMetadata)
	if err != nil {
		return fmt.Errorf("failed to parse metadata: %v", err)
	}

	// Update metadata
	wallet.Metadata = newMetadata
	wallet.UpdatedAt = time.Now().UTC().Format(time.RFC3339)

	walletJSON, err := json.Marshal(wallet)
	if err != nil {
		return err
	}

	return ctx.GetStub().PutState(walletID, walletJSON)
}

// FreezeWallet freezes a wallet (admin only)
func (s *SmartContract) FreezeWallet(ctx contractapi.TransactionContextInterface, walletID string) error {
	// Admin check
	if !isAdmin(ctx) {
		return fmt.Errorf("only admin can freeze wallets")
	}

	wallet, err := s.GetWallet(ctx, walletID)
	if err != nil {
		return err
	}

	wallet.Status = "frozen"
	wallet.UpdatedAt = time.Now().UTC().Format(time.RFC3339)

	walletJSON, err := json.Marshal(wallet)
	if err != nil {
		return err
	}

	return ctx.GetStub().PutState(walletID, walletJSON)
}

// UnfreezeWallet unfreezes a wallet (admin only)
func (s *SmartContract) UnfreezeWallet(ctx contractapi.TransactionContextInterface, walletID string) error {
	// Admin check
	if !isAdmin(ctx) {
		return fmt.Errorf("only admin can unfreeze wallets")
	}

	wallet, err := s.GetWallet(ctx, walletID)
	if err != nil {
		return err
	}

	wallet.Status = "active"
	wallet.UpdatedAt = time.Now().UTC().Format(time.RFC3339)

	walletJSON, err := json.Marshal(wallet)
	if err != nil {
		return err
	}

	return ctx.GetStub().PutState(walletID, walletJSON)
}
