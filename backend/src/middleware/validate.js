import { ValidationError } from '../utils/errors.js';

/** Valide la requête avec un schéma Joi (body, query, params). */
export function validate(schemas) {
  return (req, _res, next) => {
    for (const [part, schema] of Object.entries(schemas || {})) {
      const source = req[part];
      const { error, value } = schema.validate(source, {
        abortEarly: false,
        stripUnknown: true,
        convert: true,
      });
      if (error) {
        const details = error.details.map((d) => ({
          field: d.path.join('.'),
          message: d.message,
        }));
        return next(new ValidationError(details));
      }
      req[part] = value;
    }
    next();
  };
}
