#!/bin/bash
#
# Register and enroll all identities needed for the JEDO-Token-Test network.

set -Exeuo pipefail

# enroll admin
fabric-ca-client enroll -u http://admin:Test1@ca.jenziner.jedo.test:7054

# Fabric Smart Client node identities (identity of the node, used when talking to other nodes)
for node in aud iss worb biglen
do
  fabric-ca-client register -u http://ca.jenziner.jedo.test:7054 --id.name fsc${node} --id.secret Test1 --id.type client
  fabric-ca-client enroll -u http://fsc${node}:password@ca.jenziner.jedo.test:7054 -M "$(pwd)/keys/${node}/fsc/msp"

  # make private key name predictable
  mv "$(pwd)/keys/${node}/fsc/msp/keystore/"* "$(pwd)/keys/${node}/fsc/msp/keystore/priv_sk"
done

# Issuer and Auditor wallet users (non-anonymous)
#fabric-ca-client register -u http://localhost:27054 --id.name auditor --id.secret password --id.type client
#fabric-ca-client enroll -u http://auditor:password@localhost:27054 -M "$(pwd)/keys/auditor/aud/msp"

#fabric-ca-client register -u http://localhost:27054 --id.name issuer --id.secret password --id.type client
#fabric-ca-client enroll -u http://issuer:password@localhost:27054 -M "$(pwd)/keys/issuer/iss/msp"

# Owner wallet users (pseudonymous) on the owner1 node
#fabric-ca-client register -u http://localhost:27054 --id.name alice --id.secret password --id.type client --enrollment.type idemix --idemix.curve gurvy.Bn254
#fabric-ca-client enroll -u http://alice:password@localhost:27054  -M "$(pwd)/keys/owner1/wallet/alice/msp" --enrollment.type idemix --idemix.curve gurvy.Bn254

#fabric-ca-client register -u http://localhost:27054 --id.name bob --id.secret password --id.type client --enrollment.type idemix --idemix.curve gurvy.Bn254
#fabric-ca-client enroll -u http://bob:password@localhost:27054 -M "$(pwd)/keys/owner1/wallet/bob/msp" --enrollment.type idemix --idemix.curve gurvy.Bn254

# Owner wallet users (pseudonymous) on the owner2 node
#fabric-ca-client register -u http://localhost:27054 --id.name carlos --id.secret password --id.type client --enrollment.type idemix --idemix.curve gurvy.Bn254
#fabric-ca-client enroll -u http://carlos:password@localhost:27054  -M "$(pwd)/keys/owner2/wallet/carlos/msp" --enrollment.type idemix --idemix.curve gurvy.Bn254

#fabric-ca-client register -u http://localhost:27054 --id.name dan --id.secret password --id.type client --enrollment.type idemix --idemix.curve gurvy.Bn254
#fabric-ca-client enroll -u http://dan:password@localhost:27054 -M "$(pwd)/keys/owner2/wallet/dan/msp" --enrollment.type idemix --idemix.curve gurvy.Bn254