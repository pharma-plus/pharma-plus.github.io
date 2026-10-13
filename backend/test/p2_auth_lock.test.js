import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const edge = readFileSync(
  new URL("../../supabase/functions/pharma-api/index.ts", import.meta.url),
  "utf8",
);
const store = readFileSync(
  new URL("../../frontend/lib/core/services/auth_store.dart", import.meta.url),
  "utf8",
);
const lockScreen = readFileSync(
  new URL("../../frontend/lib/features/security/lock_screen.dart", import.meta.url),
  "utf8",
);

const routeBlock = (marker, endMarker) => {
  const at = edge.indexOf(marker);
  assert.ok(at >= 0, `marqueur absent: ${marker}`);
  const end = endMarker ? edge.indexOf(endMarker, at + marker.length) : -1;
  return edge.slice(at, end > 0 ? end : at + 3000);
};

test("auth/lock : route presente, POST uniquement, hors PUBLIC_PATHS", () => {
  assert.match(edge, /path === "auth\/lock" \|\| path === "\/auth\/lock"\) && req\.method === "POST"/);
  const publicPaths = edge.slice(edge.indexOf("PUBLIC_PATHS"), edge.indexOf("PUBLIC_PATHS") + 600);
  assert.ok(!publicPaths.includes("auth/lock"), "auth/lock ne doit pas etre publique");
});

test("auth/lock : la session n'est PAS revoquee (le PIN ne mint pas de jetons)", () => {
  const block = routeBlock('path === "auth/lock"', "Sessions de l'utilisateur");
  assert.ok(!/revoked_at/.test(block), "lock ne revoque pas la session (le deverrouillage PIN en aurait besoin)");
  assert.match(block, /user_sessions/, "le bloc touche bien la session courante");
  const pin = routeBlock('path === "auth/pin/verify"', "AUTH — lock");
  assert.ok(
    !/access_token|refresh_token|signInWithPassword|refreshSession/i.test(pin),
    "auth/pin/verify ne doit pas minter de nouveaux jetons",
  );
});

test("auth/lock : echec d'audit visible, pas silencieux", () => {
  const block = routeBlock('path === "auth/lock"', "Sessions de l'utilisateur");
  assert.match(block, /await _logAction/);
  assert.match(block, /audit_failed/);
  assert.match(block, /console\.error\("\[auth\/lock\] audit:"/);
});

test("frontend : verrou inactivite -> /auth/lock, deverrouillage -> /auth/pin/verify", () => {
  assert.match(store, /lockSession\(\)/);
  assert.match(store, /post\('\/auth\/lock'\)/);
  assert.match(store, /difference\(_lastActivity!\)\.inMinutes >= _inactivityMinutes/);
  assert.match(lockScreen, /\/auth\/pin\/verify/);
  assert.match(lockScreen, /S\.t\('verrouillage_verrouille'/);
});

test("frontend : l'etat locked est LOCAL et pose AVANT l'appel reseau", () => {
  // Etat exposé au widget tree.
  assert.match(store, /bool get isLocked/);
  assert.match(store, /bool _locked = false/);
  // lockSession pose l'etat AVANT l'appel API (panne reseau = verrou quand meme).
  const lockAt = store.indexOf("Future<void> lockSession");
  assert.ok(lockAt >= 0, "lockSession absent");
  const lockBody = store.slice(lockAt, lockAt + 900);
  assert.ok(
    lockBody.indexOf("_locked = true") < lockBody.indexOf("ApiClient"),
    "l'etat locked doit etre pose avant tout appel API",
  );
  // L'appel API est best-effort et borne (timeout).
  assert.match(lockBody, /\.timeout\(const Duration\(seconds: 8\)\)/);
  // unlock est appele par LockScreen apres PIN valide.
  assert.match(lockScreen, /\.unlock\(\)/);
  // Verrouillage auto non annulable : Annuler conditionne a isManualLock.
  assert.match(lockScreen, /isManualLock/);
  assert.match(lockScreen, /if \(canDismiss\)/);
  assert.match(lockScreen, /PopScope/);
  // Le shell pose l'ecran PIN quand isLocked bascule.
  const shell = readFileSync(
    new URL("../../frontend/lib/features/shell/home_shell.dart", import.meta.url),
    "utf8",
  );
  assert.match(shell, /isLocked/);
  assert.match(shell, /lockSession\(manual: true\)/);
});
