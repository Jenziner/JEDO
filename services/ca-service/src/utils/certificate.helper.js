const crypto = require('crypto');
const { logger } = require('../config/logger');

/**
 * Parse PEM Certificate with native Node.js crypto
 */
function parsePemCertificate(pemCert, pemKey = null) {
  try {
    logger.info('Parsing certificate with native crypto', { 
      length: pemCert ? pemCert.length : 0 
    });
    
    const cert = new crypto.X509Certificate(pemCert);
    
    logger.info('Certificate loaded successfully');
    
    const subject = parseSubjectString(cert.subject);
    const role = extractRoleFromSubject(subject);
    
    logger.info('Certificate parsed', { cn: subject.CN, role });
    
    return {
      raw: pemCert,
      subject,
      issuer: parseSubjectString(cert.issuer),
      role,
      validFrom: new Date(cert.validFrom),
      validTo: new Date(cert.validTo),
      serialNumber: cert.serialNumber,
      hasPrivateKey: !!pemKey,
      fingerprint: cert.fingerprint
    };
    
  } catch (error) {
    logger.error('Certificate parse failed', { 
      error: error.message,
      stack: error.stack
    });
    throw new Error(`Invalid certificate: ${error.message}`);
  }
}

function parseSubjectString(subjectStr) {
  const subject = {};
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
  
  return subject;
}

function extractRoleFromSubject(subject) {
  logger.debug('Extracting role', { subject });
  
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
  
  if (subject.CN) {
    const cn = subject.CN.toLowerCase();
    if (cn.includes('admin')) return 'ager';
    if (cn.includes('gens')) return 'gens';
    if (cn.includes('human')) return 'human';
  }
  
  if (subject.O) {
    const o = subject.O.toLowerCase();
    if (o === 'ager' || o === 'admin') return 'ager';
    if (o === 'gens') return 'gens';
    if (o === 'human') return 'human';
  }
  
  logger.warn('Could not determine role', { subject });
  return null;
}

function isCertificateValid(cert) {
  const now = new Date();
  return now >= cert.validFrom && now <= cert.validTo;
}

module.exports = {
  parsePemCertificate,
  extractRoleFromSubject,
  isCertificateValid
};