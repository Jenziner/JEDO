// tests/unit/healthUtil.test.ts

import { buildHealthStatus } from '../../src/utils/healthUtil';

describe('buildHealthStatus', () => {
  it('liefert Status healthy für einen gültigen Service', () => {
    // Arrange
    const serviceName = 'gateway-service';

    // Act
    const result = buildHealthStatus(serviceName);

    // Assert
    expect(result).toEqual<ReturnType<typeof buildHealthStatus>>({
      status: 'healthy',
      service: serviceName,
    });
  });

  it('wirft einen Fehler für einen ungültigen serviceName', () => {
    const errorMessage = 'serviceName must be a non-empty string';

    // kein TS-Cast-Hack nötig, weil ts-jest TS versteht
    expect(() => buildHealthStatus('')).toThrow(errorMessage);
    expect(() => buildHealthStatus(' ' as unknown as string)).toThrow(
      errorMessage
    );
    expect(() => buildHealthStatus(undefined as unknown as string)).toThrow(
      errorMessage
    );
  });
});
