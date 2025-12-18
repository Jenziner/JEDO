const crypto = require('crypto');
const { X509 } = require('jsrsasign');
const { logger } = require('../config/logger');


/**
 * Parse PEM Certificate and extract Fabric CA attributes
 */
function parsePemCertificate(pemCert, pemKey = null) {
  // ✅ TEST: Ist jsrsasign verfügbar?
  logger.debug('Testing jsrsasign availability...');
  
  try {
    const { X509: TestX509 } = require('jsrsasign');
    logger.debug('jsrsasign imported successfully', { 
      X509Available: !!TestX509 
    });
  } catch (e) {
    logger.error('❌ jsrsasign import FAILED!', { 
      error: e.message,
      stack: e.stack
    });
    throw new Error('jsrsasign not available');
  }

  try {
    logger.info('Parsing certificate with native crypto', { 
      length: pemCert ? pemCert.length : 0 
    });
    
    // Use jsrsasign for full X.509 parsing (supports extensions)
    const x509 = new X509();
    x509.readCertPEM(pemCert);
    
    logger.info('Certificate loaded successfully');
    
    // Parse subject and issuer
    const subject = parseSubjectString(x509.getSubjectString());
    const issuer = parseSubjectString(x509.getIssuerString());
    
    // ✅ Extract Fabric CA attributes from extension
    const fabricAttrs = extractFabricCAAttributes(x509);
    const role = fabricAttrs?.role || extractRoleFromSubject(subject);
    
    if (!role) {
      logger.warn('Could not determine role from certificate');
    }
    
    const validFrom = parseCertDate(x509.getNotBefore());
    const validTo = parseCertDate(x509.getNotAfter());

    logger.info('Certificate parsed', { 
      cn: subject.CN, 
      role,
      hasFabricAttrs: !!fabricAttrs,
      validFrom: validFrom.toISOString(),
      validTo: validTo.toISOString()
    });
    
    return {
      raw: pemCert,
      subject,
      issuer,
      role,
      affiliation: fabricAttrs?.['hf.Affiliation'],
      enrollmentID: fabricAttrs?.['hf.EnrollmentID'],
      type: fabricAttrs?.['hf.Type'],
      fabricAttributes: fabricAttrs,
      validFrom: validFrom,
      validTo: validTo,
      serialNumber: x509.getSerialNumberHex(),
      hasPrivateKey: !!pemKey,
      fingerprint: x509.getSignatureValueHex().substring(0, 40) // First 40 chars as fingerprint
    };
    
  } catch (error) {
    logger.error('Certificate parse failed', { 
      error: error.message,
      stack: error.stack
    });
    throw new Error(`Invalid certificate: ${error.message}`);
  }
}


/**
 * Extract Fabric CA attributes from certificate extension (OID 1.2.3.4.5.6.7.8.1)
 */
function extractFabricCAAttributes(x509) {
  logger.debug('=== EXTENSION DEBUG START ===');
  
  try {
    // Step 1: Get extensions
    logger.debug('Step 1: Getting extension info...');
    const extInfo = x509.getExtensionInfo();
    logger.debug('Extension info retrieved', { 
      count: extInfo.length,
      extensions: extInfo 
    });
    
    // Step 2: Find Fabric extension
    logger.debug('Step 2: Looking for Fabric CA extension...');
    const fabricExt = extInfo.find(ext => ext.oid === '1.2.3.4.5.6.7.8.1');
    
    if (!fabricExt) {
      logger.warn('Fabric CA extension NOT found', {
        availableOIDs: extInfo.map(e => e.oid)
      });
      logger.debug('=== EXTENSION DEBUG END (NOT FOUND) ===');
      return null;
    }
    
    logger.debug('Fabric extension found!', { 
      oid: fabricExt.oid,
      critical: fabricExt.critical,
      vidx: fabricExt.vidx,
      vlen: fabricExt.vlen
    });
    
    // Step 3: Get certificate hex
    logger.debug('Step 3: Getting certificate hex...');
    const certHex = x509.hex;
    logger.debug('Certificate hex obtained', { length: certHex ? certHex.length : 0 });
    
    if (!certHex) {
      logger.error('Certificate hex is null/undefined!');
      logger.debug('=== EXTENSION DEBUG END (NO HEX) ===');
      return null;
    }
    
    // Step 4: Extract extension hex
    logger.debug('Step 4: Extracting extension hex...');
    
    if (fabricExt.vidx === undefined || fabricExt.vlen === undefined) {
      logger.error('Extension vidx or vlen is undefined!', {
        vidx: fabricExt.vidx,
        vlen: fabricExt.vlen
      });
      logger.debug('=== EXTENSION DEBUG END (NO VIDX/VLEN) ===');
      return null;
    }
    
    const startPos = fabricExt.vidx;
    const length = fabricExt.vlen * 2;
    const endPos = startPos + length;
    
    logger.debug('Extraction positions', { 
      startPos, 
      length, 
      endPos,
      certHexLength: certHex.length
    });
    
    if (endPos > certHex.length) {
      logger.error('Extension position out of bounds!', {
        startPos,
        endPos,
        certHexLength: certHex.length
      });
      logger.debug('=== EXTENSION DEBUG END (OUT OF BOUNDS) ===');
      return null;
    }
    
    const extHex = certHex.substring(startPos, endPos);
    logger.debug('Extension hex extracted', { 
      hex: extHex.substring(0, 200) + '...',
      length: extHex.length 
    });
    
    // Step 5: Decode to UTF-8
    logger.debug('Step 5: Decoding hex to UTF-8...');
    const extString = Buffer.from(extHex, 'hex').toString('utf8');
    logger.debug('Decoded to UTF-8', { 
      string: extString.substring(0, 200),
      length: extString.length
    });
    
    // Step 6: Find JSON
    logger.debug('Step 6: Finding JSON...');
    const jsonStart = extString.indexOf('{');
    const jsonEnd = extString.lastIndexOf('}');
    
    logger.debug('JSON boundaries', { jsonStart, jsonEnd });
    
    if (jsonStart === -1) {
      logger.error('No JSON start found in extension string!', {
        stringPreview: extString.substring(0, 200).replace(/[^\x20-\x7E]/g, '.')
      });
      logger.debug('=== EXTENSION DEBUG END (NO JSON) ===');
      return null;
    }
    
    const jsonString = extString.substring(jsonStart, jsonEnd + 1);
    logger.debug('JSON string extracted', { 
      json: jsonString,
      length: jsonString.length
    });
    
    // Step 7: Parse JSON
    logger.debug('Step 7: Parsing JSON...');
    const parsed = JSON.parse(jsonString);
    logger.debug('JSON parsed successfully', { parsed });
    
    if (!parsed.attrs) {
      logger.error('Parsed JSON does not contain attrs!', { parsed });
      logger.debug('=== EXTENSION DEBUG END (NO ATTRS) ===');
      return null;
    }
    
    logger.info('✅ Fabric CA attributes extracted successfully', { 
      attrs: parsed.attrs 
    });
    logger.debug('=== EXTENSION DEBUG END (SUCCESS) ===');
    
    return parsed.attrs;
    
  } catch (error) {
    logger.error('❌ Extension extraction CRASHED', { 
      error: error.message,
      stack: error.stack,
      name: error.name
    });
    logger.debug('=== EXTENSION DEBUG END (EXCEPTION) ===');
    return null;
  }
}




/**
 * Parse subject/issuer string to object
 */
function parseSubjectString(subjectStr) {
  const subject = {};
  
  // Handle both formats:
  // 1. /C=jd/ST=dev/L=ea/O=alps/OU=ea+OU=alps+OU=jedo+OU=client/CN=muri.alps.ea.jedo.dev
  // 2. Multi-line format from crypto.X509Certificate
  
  if (subjectStr.includes('\n')) {
    // Multi-line format
    const lines = subjectStr.split('\n');
    
    for (const line of lines) {
      const eqIndex = line.indexOf('=');
      if (eqIndex === -1) continue;
      
      const key = line.substring(0, eqIndex).trim();
      const value = line.substring(eqIndex + 1).trim();
      
      if (subject[key]) {
        if (!Array.isArray(subject[key])) {
          subject[key] = [subject[key]];
        }
        subject[key].push(value);
      } else {
        subject[key] = value;
      }
    }
  } else {
    // Single-line format
    const parts = subjectStr.split('/').filter(p => p.length > 0);
    
    for (const part of parts) {
      const [key, ...valueParts] = part.split('=');
      const value = valueParts.join('='); // Handle values with '='
      
      // Handle multiple values (OU+OU+OU)
      if (part.includes('+')) {
        const multiParts = part.split('+');
        for (const multiPart of multiParts) {
          const [multiKey, ...multiValueParts] = multiPart.split('=');
          const multiValue = multiValueParts.join('=');
          
          if (subject[multiKey]) {
            if (!Array.isArray(subject[multiKey])) {
              subject[multiKey] = [subject[multiKey]];
            }
            subject[multiKey].push(multiValue);
          } else {
            subject[multiKey] = multiValue;
          }
        }
      } else {
        if (subject[key]) {
          if (!Array.isArray(subject[key])) {
            subject[key] = [subject[key]];
          }
          subject[key].push(value);
        } else {
          subject[key] = value;
        }
      }
    }
  }
  
  return subject;
}


/**
 * Parse certificate date string to JavaScript Date object
 * jsrsasign returns dates in format: "YYMMDDHHMMSSZ" or "YYYYMMDDHHMMSSZ"
 */
function parseCertDate(dateString) {
  try {
    // Format can be:
    // - "YYMMDDHHMMSSZ" (13 chars) - e.g., "251212123753Z"
    // - "YYYYMMDDHHMMSSZ" (15 chars) - e.g., "20251212123753Z"
    
    if (!dateString || dateString.length < 13) {
      throw new Error(`Invalid date string: ${dateString}`);
    }
    
    let year, month, day, hour, minute, second;
    
    if (dateString.length === 13) {
      // YY format (2-digit year)
      year = parseInt('20' + dateString.substring(0, 2), 10);
      month = parseInt(dateString.substring(2, 4), 10) - 1; // 0-indexed
      day = parseInt(dateString.substring(4, 6), 10);
      hour = parseInt(dateString.substring(6, 8), 10);
      minute = parseInt(dateString.substring(8, 10), 10);
      second = parseInt(dateString.substring(10, 12), 10);
    } else if (dateString.length === 15) {
      // YYYY format (4-digit year)
      year = parseInt(dateString.substring(0, 4), 10);
      month = parseInt(dateString.substring(4, 6), 10) - 1; // 0-indexed
      day = parseInt(dateString.substring(6, 8), 10);
      hour = parseInt(dateString.substring(8, 10), 10);
      minute = parseInt(dateString.substring(10, 12), 10);
      second = parseInt(dateString.substring(12, 14), 10);
    } else {
      throw new Error(`Unexpected date format: ${dateString}`);
    }
    
    // Create UTC date
    const date = new Date(Date.UTC(year, month, day, hour, minute, second));
    
    if (isNaN(date.getTime())) {
      throw new Error(`Invalid date components: ${dateString}`);
    }
    
    return date;
    
  } catch (error) {
    logger.error('Failed to parse certificate date', { 
      dateString, 
      error: error.message 
    });
    // Return a safe fallback (current date)
    return new Date();
  }
}


/**
 * Fallback: Try to extract role from subject (for certificates without Fabric CA extension)
 */
function extractRoleFromSubject(subject) {
  logger.debug('Extracting role from subject (fallback)', { subject });
  
  // Check OU
  if (subject.OU) {
    const ous = Array.isArray(subject.OU) ? subject.OU : [subject.OU];
    const ouStr = ous.join(' ').toLowerCase();
    
    if (ouStr.includes('admin') || ouStr.includes('ager')) {
      logger.info('Role: ager (from OU)');
      return 'ager';
    }
    if (ouStr.includes('gens')) {
      logger.info('Role: gens (from OU)');
      return 'gens';
    }
    if (ouStr.includes('human')) {
      logger.info('Role: human (from OU)');
      return 'human';
    }
  }
  
  // Check CN
  if (subject.CN) {
    const cn = subject.CN.toLowerCase();
    
    // Extract first part of FQDN
    const parts = cn.split('.');
    const username = parts[0];
    
    // Check if it's admin
    if (cn.includes('admin') || username === 'admin') {
      logger.info('Role: ager (from CN containing admin)');
      return 'ager';
    }
    
    // ✅ Check if it's a UUID (Human)
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (uuidRegex.test(username)) {
      logger.info('Role: human (UUID detected in CN:', username + ')');
      return 'human';
    }
    
    // ✅ Check if CN has subdomain structure (username.parent.domain...)
    if (parts.length >= 3) {
      // If first part is NOT a UUID and NOT admin → it's a Gens
      logger.info('Role: gens (detected from FQDN structure:', username + ')');
      return 'gens';
    }
  }
  
  logger.warn('Could not determine role from subject (fallback failed)');
  return null;
}


/**
 * Check if certificate is still valid
 */
function isCertificateValid(cert) {
  const now = new Date();
  return now >= cert.validFrom && now <= cert.validTo;
}


module.exports = {
  parsePemCertificate,
  extractFabricCAAttributes,
  extractRoleFromSubject,
  parseCertDate,
  isCertificateValid
};
