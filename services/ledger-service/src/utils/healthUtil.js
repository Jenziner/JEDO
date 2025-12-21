// src/utils/healthUtil.js

/**
 * Erzeugt ein Health-Response-Objekt.
 * Reine Funktion ohne externe Abhängigkeiten.
 */
function buildHealthStatus(serviceName) {
  if (!serviceName || typeof serviceName !== 'string') {
    throw new Error('serviceName must be a non-empty string');
  }

  return {
    status: 'healthy',
    service: serviceName,
    // keine echte Zeitabhängigkeit im Test nötig
  };
}

module.exports = {
  buildHealthStatus,
};
