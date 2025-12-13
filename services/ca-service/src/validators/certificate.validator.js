const Joi = require('joi');

/**
 * Validation Schema: Register User
 */
const registerUserSchema = Joi.object({
  username: Joi.string()
    .alphanum()
    .min(3)
    .max(50)
    .required()
    .description('Unique user identifier'),
  
  secret: Joi.string()
    .min(8)
    .max(64)
    .required()
    .description('User password (min 8 characters)'),
  
  role: Joi.string()
    .valid('gens', 'human')
    .required()
    .description('User role: gens or human'),
  
  affiliation: Joi.string()
    .pattern(/^[a-z0-9.]+$/)
    .required()
    .description('Organizational affiliation (e.g., jedo.alps.worb)'),
  
  attrs: Joi.object()
    .pattern(Joi.string(), Joi.string())
    .optional()
    .description('Additional user attributes'),
});

/**
 * Validation Schema: Enroll User
 */
const enrollUserSchema = Joi.object({
  username: Joi.string()
    .alphanum()
    .min(3)
    .max(50)
    .required(),
  
  secret: Joi.string()
    .min(8)
    .max(64)
    .required(),
  
  role: Joi.string()
    .valid('gens', 'human')
    .required(),
  
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
    .alphanum()
    .min(3)
    .max(50)
    .required(),
  
  reason: Joi.string()
    .valid('unspecified', 'keyCompromise', 'affiliationChanged', 'superseded', 'cessationOfOperation')
    .default('unspecified'),
});

module.exports = {
  registerUserSchema,
  enrollUserSchema,
  revokeUserSchema,
};
