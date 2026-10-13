-- Mission 12/10 : verrouillage d'ecran cote serveur (Phase F).
-- Ajoute user_sessions.locked_at pour que /auth/lock invalide reellement
-- l'usage du jeton sur un poste partagé (le verrou n'etait qu'un flag local).
-- Colonnes NULL pour TOUTES les sessions existantes => aucun effet de bord
-- sur les sessions en cours avant le prochain /auth/lock. 100 % additif.
ALTER TABLE user_sessions ADD COLUMN IF NOT EXISTS locked_at timestamptz;
CREATE INDEX IF NOT EXISTS idx_sessions_locked ON user_sessions(user_id)
  WHERE locked_at IS NOT NULL;
COMMENT ON COLUMN user_sessions.locked_at IS
  'Verrou ecran : non NULL = session verrouillee, tous les appels sauf pin/verify/lock/logout sont rejetes (423).';
