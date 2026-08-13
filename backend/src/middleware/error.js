import { AppError } from '../utils/errors.js';

/** Handler central des erreurs. */
export function errorHandler(err, _req, res, _next) {
  let status = err.status || 500;
  let code = err.code || 'INTERNAL_ERROR';
  let message = err.message || 'Erreur interne du serveur';
  let details = err.details || null;

  // Erreurs PostgreSQL connues
  if (err.code === '23505') {
    status = 409;
    code = 'DUPLICATE';
    message = 'Une donnée identique existe déjà';
  } else if (err.code === '23503') {
    status = 409;
    code = 'FOREIGN_KEY_VIOLATION';
    message = 'Référence introuvable ou utilisée';
  } else if (err.code === '23514') {
    status = 422;
    code = 'CHECK_VIOLATION';
    message = 'Contrainte de données non respectée';
  } else if (err.code === 'P0001') {
    status = 409;
    code = 'BUSINESS_RULE';
    message = err.message;
  }

  if (status >= 500 && !err.isOperational) {
    console.error('[error]', err);
    message = 'Erreur interne du serveur';
  }

  const body = { success: false, error: { code, message } };
  if (details) body.error.details = details;
  return res.status(status).json(body);
}

/** Middleware 404. */
export function notFound(_req, res) {
  return res.status(404).json({
    success: false,
    error: { code: 'NOT_FOUND', message: 'Route introuvable' },
  });
}

/** Vérifie que la route n'a pas d'erreur "opérationnelle". */
export function wrap(fn) {
  return (req, res, next) => Promise.resolve(fn(req, res, next)).catch((err) => {
    if (err instanceof AppError) err.isOperational = true;
    next(err);
  });
}
