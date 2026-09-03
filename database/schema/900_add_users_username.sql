-- =====================================================================
-- 900 : Connexion par nom d'utilisateur (e-mail OU username)
-- Colonne facultative, unique et insensible à la casse.
-- Migration additive et idempotente : sans effet si déjà appliquée.
-- =====================================================================

ALTER TABLE users ADD COLUMN IF NOT EXISTS username VARCHAR(40);

CREATE UNIQUE INDEX IF NOT EXISTS users_username_lower_uidx
  ON users (lower(username))
  WHERE username IS NOT NULL;

-- Remplissage initial : partie locale de l'e-mail, normalisée et dédupliquée
-- (les doublons éventuels reçoivent un suffixe -2, -3, …).
UPDATE users u
   SET username = CASE WHEN s.rn = 1 THEN s.base ELSE s.base || '-' || s.rn END
  FROM (
    SELECT id,
           regexp_replace(lower(split_part(email, '@', 1)), '[^a-z0-9._-]', '', 'g') AS base,
           row_number() OVER (
             PARTITION BY regexp_replace(lower(split_part(email, '@', 1)), '[^a-z0-9._-]', '', 'g')
             ORDER BY created_at NULLS LAST, id
           ) AS rn
      FROM users
     WHERE username IS NULL
       AND email IS NOT NULL
       AND length(regexp_replace(lower(split_part(email, '@', 1)), '[^a-z0-9._-]', '', 'g')) >= 3
  ) s
 WHERE u.id = s.id;
