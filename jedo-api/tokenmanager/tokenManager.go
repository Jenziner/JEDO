package tokenmanager

import (
	"fmt"
	"github.com/hyperledger-labs/fabric-token-sdk/token/services/ttx"
	"github.com/hyperledger-labs/fabric-token-sdk/token"
	"github.com/hyperledger-labs/fabric-smart-client/platform/view/view"
)

// MintNFT mints a new NFT
func MintNFT(ctx view.Context, issuerWallet *token.IssuerWallet, owner view.Identity, nftData string) (string, error) {
	// Create a new anonymous transaction using the IssuerWallet
	txManager, err := ttx.NewAnonymousTransaction(ctx)
	if err != nil {
		return "", fmt.Errorf("failed to create transaction manager: %v", err)
	}

	// Issue a new Token (NFT)
	err = txManager.Issue(
		issuerWallet,  // Issuer's wallet
		owner,         // Owner's identity
		"NFT",         // Token Type
		1,             // Quantity (as a single uint64, not a list)
	)
	if err != nil {
		return "", fmt.Errorf("failed to issue NFT: %v", err)
	}

	// Validate the transaction
	err = txManager.IsValid()
	if err != nil {
		return "", fmt.Errorf("transaction is not valid: %v", err)
	}

	// Get the Request object
	request := txManager.Request()

	// At this point, you'd need to submit or finalize the request
	// You would need to find the method or service to submit this request

	return request.ID(), nil // Returning the request ID for now
}

// TransferNFT transfers an NFT to a new owner
func TransferNFT(ctx view.Context, ownerWallet *token.OwnerWallet, tokenID uint64, newOwner view.Identity) (string, error) {
	// Create a new anonymous transaction using the OwnerWallet
	txManager, err := ttx.NewAnonymousTransaction(ctx)
	if err != nil {
		return "", fmt.Errorf("failed to create transaction manager: %v", err)
	}

	// Transfer the NFT
	err = txManager.Transfer(
		ownerWallet,               // Current owner's wallet
		"NFT",                     // Token Type
		[]uint64{tokenID},         // Token ID (as a list)
		[]view.Identity{newOwner}, // New owner's identity (as a list)
	)
	if err != nil {
		return "", fmt.Errorf("failed to transfer NFT: %v", err)
	}

	// Validate the transaction
	err = txManager.IsValid()
	if err != nil {
		return "", fmt.Errorf("transaction is not valid: %v", err)
	}

	// Get the Request object
	request := txManager.Request()

	// At this point, you'd need to submit or finalize the request
	// You would need to find the method or service to submit this request

	return request.ID(), nil // Returning the request ID for now
}
