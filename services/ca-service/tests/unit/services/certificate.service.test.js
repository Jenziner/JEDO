// Mock Fabric CA Service BEFORE requiring certificate.service
jest.mock('../../../src/services/fabric-ca.service');

const certificateService = require('../../../src/services/certificate.service');
const fabricCAService = require('../../../src/services/fabric-ca.service');

describe('CertificateService - Unit Tests', () => {
  
  beforeEach(() => {
    jest.clearAllMocks();
  });
  
  describe('registerUser', () => {
    
    it('should successfully register a new user', async () => {
      // Arrange: Mock CA Client
      const mockCAClient = {
        register: jest.fn().mockResolvedValue('generated-secret-123')
      };
      
      const mockAdminIdentity = {
        type: 'X.509',
        mspId: 'TestMSP'
      };
      
      fabricCAService.getCAClient.mockReturnValue(mockCAClient);
      fabricCAService.getAdminIdentity.mockResolvedValue(mockAdminIdentity);
      
      const requesterCert = {
        attrs: {
          role: 'ager'
        }
      };
      
      // Act: Register gens (ager can register gens)
      const result = await certificateService.registerUser(
        {
          username: 'test-user',
          secret: 'test-pass',
          role: 'gens',
          affiliation: 'alps.worb',
          attrs: { location: 'Switzerland' }
        },
        requesterCert
      );
      
      // Assert
      expect(result.success).toBe(true);
      expect(result.username).toBe('test-user');
      expect(result.secret).toBe('generated-secret-123');
      expect(result.role).toBe('gens');
      
      expect(mockCAClient.register).toHaveBeenCalledWith(
        expect.objectContaining({
          enrollmentID: 'test-user',
          role: 'client',
          affiliation: 'alps.worb'
        }),
        mockAdminIdentity
      );
    });
    
    it('should reject unauthorized registration (role hierarchy)', async () => {
      const requesterCert = {
        attrs: {
          role: 'gens'  // Low role
        }
      };
      
      // Act & Assert: Try to register ager (should fail)
      await expect(
        certificateService.registerUser(
          {
            username: 'hacker',
            secret: 'hack',
            role: 'ager',
            affiliation: 'alps.worb'
          },
          requesterCert
        )
      ).rejects.toThrow(/Unauthorized/);
    });
    
    it('should allow regnum to register ager', async () => {
      const mockCAClient = {
        register: jest.fn().mockResolvedValue('secret-456')
      };
      
      fabricCAService.getCAClient.mockReturnValue(mockCAClient);
      fabricCAService.getAdminIdentity.mockResolvedValue({});
      
      const requesterCert = {
        attrs: {
          role: 'regnum'
        }
      };
      
      const result = await certificateService.registerUser(
        {
          username: 'new-ager',
          secret: 'pass',
          role: 'ager',
          affiliation: 'alps.worb'
        },
        requesterCert
      );
      
      expect(result.success).toBe(true);
      expect(result.role).toBe('ager');
    });
    
    it('should reject registration without authentication', async () => {
      await expect(
        certificateService.registerUser(
          {
            username: 'anon',
            role: 'gens',
            affiliation: 'alps'
          },
          null
        )
      ).rejects.toThrow(/Authentication required/);
    });
    
  });
  
  describe('enrollUser', () => {
    
    it('should successfully enroll a registered user', async () => {
      const mockCAClient = {
        enroll: jest.fn().mockResolvedValue({
          certificate: '-----BEGIN CERTIFICATE-----\nMOCK_CERT\n-----END CERTIFICATE-----',
          key: {
            toBytes: () => '-----BEGIN PRIVATE KEY-----\nMOCK_KEY\n-----END PRIVATE KEY-----'
          }
        })
      };
      
      const mockWallet = {
        get: jest.fn().mockResolvedValue(null),
        put: jest.fn().mockResolvedValue(true)
      };
      
      fabricCAService.getCAClient.mockReturnValue(mockCAClient);
      fabricCAService.getWallet.mockReturnValue(mockWallet);
      
      const result = await certificateService.enrollUser({
        username: 'test-user',
        secret: 'test-pass',
        role: 'gens'
      });
      
      expect(result.success).toBe(true);
      expect(result.username).toBe('test-user');
      expect(result.certificate).toContain('BEGIN CERTIFICATE');
      expect(mockWallet.put).toHaveBeenCalled();
    });
    
    it('should reject enrollment if user already enrolled', async () => {
      const mockWallet = {
        get: jest.fn().mockResolvedValue({
          certificate: 'existing-cert'
        })
      };
      
      fabricCAService.getWallet.mockReturnValue(mockWallet);
      
      await expect(
        certificateService.enrollUser({
          username: 'duplicate-user',
          secret: 'pass'
        })
      ).rejects.toThrow(/already enrolled/);
    });
    
  });
  
  describe('Authorization Rules (Hierarchie)', () => {
    
    const testCases = [
      { requester: 'regnum', target: 'ager', allowed: true },
      { requester: 'ager', target: 'gens', allowed: true },
      { requester: 'gens', target: 'human', allowed: true },
      { requester: 'gens', target: 'ager', allowed: false },
      { requester: 'human', target: 'gens', allowed: false }
    ];
    
    testCases.forEach(({ requester, target, allowed }) => {
      it(`${requester} ${allowed ? 'CAN' : 'CANNOT'} register ${target}`, async () => {
        if (allowed) {
          fabricCAService.getCAClient.mockReturnValue({
            register: jest.fn().mockResolvedValue('secret')
          });
          fabricCAService.getAdminIdentity.mockResolvedValue({});
        }
        
        const requesterCert = {
          attrs: { role: requester }
        };
        
        const promise = certificateService.registerUser(
          { 
            username: 'test', 
            secret: 'pass',
            role: target, 
            affiliation: 'test' 
          },
          requesterCert
        );
        
        if (allowed) {
          await expect(promise).resolves.toHaveProperty('success', true);
        } else {
          await expect(promise).rejects.toThrow();
        }
      });
    });
    
  });
  
  describe('revokeUser', () => {
    
    it('should allow admin to revoke user certificate', async () => {
      const mockCAClient = {
        revoke: jest.fn().mockResolvedValue(true)
      };
      
      const mockWallet = {
        remove: jest.fn().mockResolvedValue(true)
      };
      
      fabricCAService.getCAClient.mockReturnValue(mockCAClient);
      fabricCAService.getAdminIdentity.mockResolvedValue({});
      fabricCAService.getWallet.mockReturnValue(mockWallet);
      
      const requesterCert = {
        attrs: { role: 'admin' }
      };
      
      const result = await certificateService.revokeUser(
        'compromised-user',
        'security_breach',
        requesterCert
      );
      
      expect(result.success).toBe(true);
      expect(result.revoked).toBe(true);
      expect(mockCAClient.revoke).toHaveBeenCalledWith(
        expect.objectContaining({
          enrollmentID: 'compromised-user',
          reason: 'security_breach'
        }),
        expect.anything()
      );
      expect(mockWallet.remove).toHaveBeenCalledWith('compromised-user');
    });
    
    it('should allow ager to revoke certificates', async () => {
      const mockCAClient = {
        revoke: jest.fn().mockResolvedValue(true)
      };
      
      const mockWallet = {
        remove: jest.fn().mockResolvedValue(true)
      };
      
      fabricCAService.getCAClient.mockReturnValue(mockCAClient);
      fabricCAService.getAdminIdentity.mockResolvedValue({});
      fabricCAService.getWallet.mockReturnValue(mockWallet);
      
      // Ager can revoke (important for regional control!)
      const requesterCert = {
        attrs: { role: 'ager' }
      };
      
      const result = await certificateService.revokeUser(
        'bad-user',
        'fraud',
        requesterCert
      );
      
      expect(result.success).toBe(true);
    });
    
    it('should reject revocation by gens', async () => {
      const requesterCert = {
        attrs: { role: 'gens' }
      };
      
      await expect(
        certificateService.revokeUser('user', 'reason', requesterCert)
      ).rejects.toThrow(/Unauthorized/);
    });
    
  });

  describe('reenrollUser', () => {
    
    it('should allow user to renew their certificate', async () => {
      const mockCAClient = {
        reenroll: jest.fn().mockResolvedValue({
          certificate: '-----BEGIN CERTIFICATE-----\nNEW_CERT\n-----END CERTIFICATE-----',
          key: {
            toBytes: () => '-----BEGIN PRIVATE KEY-----\nNEW_KEY\n-----END PRIVATE KEY-----'
          }
        })
      };
      
      const mockWallet = {
        get: jest.fn().mockResolvedValue({
          credentials: {
            certificate: 'old-cert',
            privateKey: 'old-key'
          },
          mspId: 'TestMSP',
          type: 'X.509'
        }),
        put: jest.fn().mockResolvedValue(true)
      };
      
      fabricCAService.getCAClient.mockReturnValue(mockCAClient);
      fabricCAService.getWallet.mockReturnValue(mockWallet);
      
      const result = await certificateService.reenrollUser('test-user');
      
      expect(result.success).toBe(true);
      expect(result.certificate).toContain('NEW_CERT');
      expect(mockWallet.put).toHaveBeenCalled();
    });
    
    it('should reject reenrollment for non-existent user', async () => {
      const mockWallet = {
        get: jest.fn().mockResolvedValue(null)
      };
      
      fabricCAService.getWallet.mockReturnValue(mockWallet);
      
      await expect(
        certificateService.reenrollUser('ghost-user')
      ).rejects.toThrow(/not found/);
    });
    
  });

  describe('getCertificateInfo', () => {
    
    it('should return certificate information', async () => {
      const mockWallet = {
        get: jest.fn().mockResolvedValue({
          credentials: {
            certificate: '-----BEGIN CERTIFICATE-----\nTEST\n-----END CERTIFICATE-----'
          },
          mspId: 'TestMSP',
          type: 'X.509'
        })
      };
      
      fabricCAService.getWallet.mockReturnValue(mockWallet);
      
      const result = await certificateService.getCertificateInfo('test-user');
      
      expect(result.success).toBe(true);
      expect(result.username).toBe('test-user');
      expect(result.mspId).toBe('TestMSP');
      expect(result.certificate).toHaveProperty('valid', true);
    });
    
  });

});
