const Joi = require('joi');


/**
 * Username Pattern:
 * - Alphanumeric characters
 * - Hyphens (-)
 * - Underscores (_)
 * - Dots (.)
 * - 3-64 characters
 * 
 * Allows: UUIDs, FQDNs, simple names
 * Examples:
 *   - test-gens-2b35f79c-d9a9-42ea-ba30-de58fdc413cc
 *   - worb.alps.ea.jedo.dev
 *   - alice_123
 *   - user-01
 */
const usernamePattern = /^[a-zA-Z0-9._-]{3,64}$/;


/**
 * Validation Schema: Register User
 */
const registerUserSchema = Joi.object({
  username: Joi.string()
    .pattern(usernamePattern)
    .min(3)
    .max(64)
    .required()
    .messages({
      'string.pattern.base': 'Username must contain only alphanumeric characters, dots, hyphens, and underscores (3-64 chars)',
      'string.min': 'Username must be at least 3 characters',
      'string.max': 'Username must not exceed 64 characters',
      'any.required': 'Username is required'
    })
    .description('Unique user identifier'),
  
  secret: Joi.string()
    .min(8)
    .max(64)
    .optional()
    .messages({
      'string.min': 'Secret must be at least 8 characters',
      'string.max': 'Secret must not exceed 64 characters'
    })
    .description('User password (min 8 characters, auto-generated if not provided)'),
  
  role: Joi.string()
    .valid('regnum', 'ager', 'gens', 'human', 'admin')
    .required()
    .messages({
      'any.only': 'Role must be one of: regnum, ager, gens, human, admin',
      'any.required': 'Role is required'
    })
    .description('User role in hierarchy'),
  
  affiliation: Joi.string()
    .pattern(/^[a-z0-9.]+$/)
    .required()
    .messages({
      'string.pattern.base': 'Affiliation must contain only lowercase alphanumeric characters and dots',
      'any.required': 'Affiliation is required'
    })
    .description('Organizational affiliation (e.g., jedo.ea.alps)'),
  
  attrs: Joi.object()
    .pattern(Joi.string(), Joi.alternatives().try(Joi.string(), Joi.boolean()))
    .optional()
    .description('Additional user attributes'),
});


/**
 * Validation Schema: Enroll User
 */
const enrollUserSchema = Joi.object({
  username: Joi.string()
    .pattern(usernamePattern)
    .min(3)
    .max(64)
    .required()
    .messages({
      'string.pattern.base': 'Username must contain only alphanumeric characters, dots, hyphens, and underscores (3-64 chars)',
      'any.required': 'Username is required'
    }),
  
  secret: Joi.string()
    .min(8)
    .max(64)
    .required()
    .messages({
      'string.min': 'Secret must be at least 8 characters',
      'string.max': 'Secret must not exceed 64 characters',
      'any.required': 'Secret is required'
    }),
  
  role: Joi.string()
    .valid('regnum', 'ager', 'gens', 'human', 'admin')
    .optional()
    .messages({
      'any.only': 'Role must be one of: regnum, ager, gens, human, admin'
    }),
  
  enrollmentType: Joi.string()
    .valid('x509', 'idemix')
    .optional()
    .default('x509')
    .messages({
      'any.only': 'Enrollment type must be either x509 or idemix'
    })
    .description('Certificate type: x509 (default) or idemix (anonymous)'),
  
  idemixCurve: Joi.string()
    .valid('gurvy.Bn254', 'FP256BN_AMCL', 'FP256BN_AMCL_MIRACL')
    .optional()
    .messages({
      'any.only': 'Idemix curve must be one of: gurvy.Bn254, FP256BN_AMCL, FP256BN_AMCL_MIRACL'
    })
    .description('Idemix curve (required for idemix enrollment)'),
  
  csr: Joi.object({
    cn: Joi.string()
      .pattern(/^[a-zA-Z0-9._-]+$/)
      .optional()
      .messages({
        'string.pattern.base': 'Common Name must contain only alphanumeric characters, dots, hyphens, and underscores'
      })
      .description('Certificate Common Name (CN)'),
    
    names: Joi.string()
      .pattern(/^(C=[^,]+)?(,ST=[^,]+)?(,L=[^,]+)?(,O=[^,]+)?$/)
      .optional()
      .messages({
        'string.pattern.base': 'CSR names must be in format: C=XX,ST=XX,L=XX,O=XX'
      })
      .description('CSR subject fields (e.g., "C=jd,ST=dev,L=ea,O=alps")'),
    
    hosts: Joi.array()
      .items(Joi.string())
      .optional()
      .description('Subject Alternative Names (SANs) - DNS names or IPs')
  })
  .optional()
  .description('Certificate Signing Request options'),
  
  // Legacy support (your old format)
  csrOptions: Joi.object({
    cn: Joi.string().optional(),
    hosts: Joi.array().items(Joi.string()).optional(),
    names: Joi.array().items(
      Joi.object({
        C: Joi.string().optional(),
        ST: Joi.string().optional(),
        L: Joi.string().optional(),
        O: Joi.string().optional(),
      })
    ).optional(),
  }).optional(),
});


/**
 * Validation Schema: Revoke User
 */
const revokeUserSchema = Joi.object({
  username: Joi.string()
    .pattern(usernamePattern)
    .min(3)
    .max(64)
    .required()
    .messages({
      'string.pattern.base': 'Username must contain only alphanumeric characters, dots, hyphens, and underscores (3-64 chars)',
      'any.required': 'Username is required'
    }),
  
  reason: Joi.string()
    .valid(
      'unspecified',
      'keycompromise',
      'keyCompromise',  // Alternative spelling
      'cacompromise',
      'affiliationchange',
      'affiliationChanged',  // Alternative spelling
      'superseded',
      'cessationofoperation',
      'cessationOfOperation',  // Alternative spelling
      'certificatehold',
      'removefromcrl',
      'privilegewithdrawn',
      'aacompromise'
    )
    .default('unspecified')
    .messages({
      'any.only': 'Invalid revocation reason'
    })
    .description('Reason for certificate revocation'),
});


/**
 * Validation Schema: Re-enroll User (Certificate Renewal)
 */
const reenrollUserSchema = Joi.object({
  username: Joi.string()
    .pattern(usernamePattern)
    .min(3)
    .max(64)
    .required()
    .messages({
      'string.pattern.base': 'Username must contain only alphanumeric characters, dots, hyphens, and underscores (3-64 chars)',
      'any.required': 'Username is required'
    }),
  
  csr: Joi.object({
    cn: Joi.string()
      .pattern(/^[a-zA-Z0-9._-]+$/)
      .optional(),
    
    names: Joi.string()
      .pattern(/^(C=[^,]+)?(,ST=[^,]+)?(,L=[^,]+)?(,O=[^,]+)?$/)
      .optional(),
    
    hosts: Joi.array()
      .items(Joi.string())
      .optional()
  }).optional(),
});


/**
 * Validation Schema: Get Certificate Info
 */
const getCertificateSchema = Joi.object({
  username: Joi.string()
    .pattern(usernamePattern)
    .min(3)
    .max(64)
    .required()
    .messages({
      'string.pattern.base': 'Username must contain only alphanumeric characters, dots, hyphens, and underscores (3-64 chars)',
      'any.required': 'Username is required'
    }),
});


module.exports = {
  registerUserSchema,
  enrollUserSchema,
  revokeUserSchema,
  reenrollUserSchema,
  getCertificateSchema,
};
