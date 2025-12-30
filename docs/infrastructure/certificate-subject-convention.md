# Naming Convention for certificat subject
| Identity  | Country | State              | Locality | Organisation | CN                                |
| --------- | ------- | ------------------ | -------- | ------------ | --------------------------------- |
| RootCA    | C = XX  | ST = prod          | L = ""   | O = ""       |               rca.jedo.me         |
| Harbor    | C = XX  | ST = prod          | L = ""   | O = ""       |               harbor.jedo.me      |
| Vault     | C = XX  | ST = prod          | L = ""   | O = ""       |               vault.jedo.me       |
| OrbisMSP  | C = XX  | ST = dev,test,prod | L = ""   | O = ""       |              msp.jedo.dev .cc .me |
| RegnumMSP | C = XX  | ST = dev,test,prod | L = ea   | O = ""       |           msp.ea.jedo.dev .cc .me |
| AgerMSP   | C = XX  | ST = dev,test,prod | L = ea   | O = alps     |      msp.alps.ea.jedo.dev .cc .me |
| Orderer   | C = XX  | ST = dev,test,prod | L = ea   | O = alps     |  orderer.alps.ea.jedo.dev .cc .me |
| Admin     | C = XX  | ST = dev,test,prod | L = ea   | O = alps     |    admin.alps.ea.jedo.dev .cc .me |
| Gens      | C = XX  | ST = dev,test,prod | L = ea   | O = alps     |     worb.alps.ea.jedo.dev .cc .me |
| Human     | C = XX  | ST = dev,test,prod | L = ea   | O = alps     | nik.worb.alps.ea.jedo.dev .cc .me |
