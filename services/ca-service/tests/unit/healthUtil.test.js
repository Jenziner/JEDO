// tests/unit/healthUtil.test.js

const { buildHealthStatus } = require('../../src/utils/healthUtil');

describe('buildHealthStatus', () => {
  test('gibt ein Objekt mit Status und Service zurück', () => {
    const result = buildHealthStatus('ca-service');

    expect(result).toEqual(
      expect.objectContaining({
        status: 'healthy',
        service: 'ca-service',
      })
    );
  });

  test('wirft Fehler bei ungültigem serviceName', () => {
    expect(() => buildHealthStatus('')).toThrow('serviceName must be a non-empty string');
    expect(() => buildHealthStatus(null)).toThrow('serviceName must be a non-empty string');
    expect(() => buildHealthStatus(123)).toThrow('serviceName must be a non-empty string');
  });
});
