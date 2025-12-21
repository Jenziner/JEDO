// src/utils/healthUtil.ts

export interface HealthStatus {
  status: 'healthy';
  service: string;
}

export function buildHealthStatus(serviceName: string): HealthStatus {
  if (
    !serviceName ||
    typeof serviceName !== 'string' ||
    serviceName.trim().length === 0
  ) {
    throw new Error('serviceName must be a non-empty string');
  }

  return {
    status: 'healthy',
    service: serviceName,
  };
}
