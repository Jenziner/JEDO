package main

import (
    "fmt"
    "github.com/hyperledger/fabric-contract-api-go/contractapi"
    "strings"
    "encoding/base64"
)

// getCallerRole extracts the role from client identity
func getCallerRole(ctx contractapi.TransactionContextInterface) (string, error) {
    // 1) Fabric-CA-Attribut "admin=true"
    adminAttr, found, err := ctx.GetClientIdentity().GetAttributeValue("admin")
    if err == nil && found && adminAttr == "true" {
        return "admin", nil
    }

    rawID, err := ctx.GetClientIdentity().GetID()
    if err != nil {
        return "", fmt.Errorf("failed to get client identity: %v", err)
    }

    // Base64-dekodieren
    decoded, err := base64.StdEncoding.DecodeString(rawID)
    if err != nil {
        return "", fmt.Errorf("failed to base64-decode client identity: %v", err)
    }
    clientID := string(decoded)

    // Einfacher Admin-Match über CN
    if strings.Contains(clientID, "CN=admin.alps.ea.jedo.cc") {
        return "admin", nil
    }

    // Beispiel: x509::CN=admin.alps.ea.jedo.cc,OU=...,O=alps,...
    parts := strings.Split(clientID, "::")
    if len(parts) < 2 {
        return "", fmt.Errorf("unexpected clientID format: %s", clientID)
    }
    subject := parts[1]

    for _, p := range strings.Split(subject, ",") {
        p = strings.TrimSpace(p)
        if strings.HasPrefix(p, "CN=") {
            cn := strings.TrimPrefix(p, "CN=")
            cnParts := strings.Split(cn, ".")

            if len(cnParts) > 0 && cnParts[0] == "admin" {
                return "admin", nil
            }
            if len(cnParts) == 4 {
                return "gens", nil
            }
            if len(cnParts) > 4 {
                return "human", nil
            }
        }
    }

    return "", fmt.Errorf("unknown role for identity: %s", clientID)
}


// isAdmin checks if caller is admin
func isAdmin(ctx contractapi.TransactionContextInterface) bool {
    role, err := getCallerRole(ctx)
    if err != nil {
        return false
    }
    return role == "admin"
}

// isGens checks if caller is gens
func isGens(ctx contractapi.TransactionContextInterface) bool {
    role, err := getCallerRole(ctx)
    if err != nil {
        return false
    }
    return role == "gens"
}

// isHuman checks if caller is human
func isHuman(ctx contractapi.TransactionContextInterface) bool {
    role, err := getCallerRole(ctx)
    if err != nil {
        return false
    }
    return role == "human"
}
