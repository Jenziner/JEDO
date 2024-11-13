###############################################################
#!/bin/bash
#
# Temporary script.
#
#
###############################################################



# Search for certificate with serial: 29e3a9...

find /mnt/user/appdata/jedo-dev -type f -name "*.pem" -exec sh -c '
    for file do
        if openssl x509 -in "$file" -noout -serial | grep -qi "29e3a9"; then
            echo "Zertifikat gefunden: $file"
        fi
    done
' sh {} +



