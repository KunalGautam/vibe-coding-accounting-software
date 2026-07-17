import test from "node:test";
import assert from "node:assert/strict";

import {
  connectionReadinessChecks,
  extractPasswordResetToken,
  generateTemporaryPassword,
  organizationUserOnboardingChecks,
  passwordChangeChecks,
  passwordStrengthChecks,
  roleDescription,
  safeFilenamePart
} from "../.test-build/accountSecurity.js";

test("passwordStrengthChecks marks strong passwords ready", () => {
  assert.deepEqual(passwordStrengthChecks("Stronger-pass-123").map((check) => check.ok), [true, true, true, true]);
});

test("passwordStrengthChecks reports missing requirements", () => {
  assert.deepEqual(passwordStrengthChecks("short").map((check) => check.ok), [false, false, false, false]);
});

test("passwordChangeChecks prevents empty or unchanged password changes", () => {
  assert.deepEqual(passwordChangeChecks("", "New-password-123").map((check) => check.ok), [false, true, true]);
  assert.deepEqual(passwordChangeChecks("Same-password-123", "Same-password-123").map((check) => check.ok), [true, true, false]);
});

test("connectionReadinessChecks reports missing session pieces", () => {
  const checks = connectionReadinessChecks({
    baseUrl: "http://localhost:8080/api/v1",
    accessToken: "",
    refreshToken: "refresh-token",
    organizationId: ""
  });
  assert.deepEqual(checks.map((check) => check.ok), [true, false, true, false]);
});

test("extractPasswordResetToken reads query, hash, and path reset links", () => {
  assert.equal(extractPasswordResetToken("https://app.example.com/reset-password?token=query-token"), "query-token");
  assert.equal(extractPasswordResetToken("https://app.example.com/#/reset-password?reset_token=hash-token"), "hash-token");
  assert.equal(extractPasswordResetToken("https://app.example.com/#/reset-password/hash-path-token"), "hash-path-token");
  assert.equal(extractPasswordResetToken("https://app.example.com/reset-password/path-token"), "path-token");
  assert.equal(extractPasswordResetToken("not a url"), "");
});

test("organizationUserOnboardingChecks catches incomplete invite details", () => {
  assert.deepEqual(
    organizationUserOnboardingChecks({
      name: "Book Keeper",
      email: "bookkeeper@example.com",
      password: "Temporary-123",
      role: "bookkeeper"
    }).map((check) => check.ok),
    [true, true, true, true, true, true, true, true]
  );
  assert.deepEqual(
    organizationUserOnboardingChecks({
      name: "",
      email: "not-an-email",
      password: "short",
      role: "viewer"
    }).map((check) => check.ok),
    [false, false, false, false, false, false, true, false]
  );
  assert.deepEqual(
    organizationUserOnboardingChecks({
      name: "Weak User",
      email: "weak@example.com",
      password: "longbutnosymbol1",
      role: "viewer"
    }).map((check) => check.ok),
    [true, true, true, false, true, false, true, false]
  );
});

test("roleDescription returns useful role guidance", () => {
  assert.match(roleDescription("admin"), /Full organization administration/);
  assert.match(roleDescription("viewer"), /Read-only/);
});

test("safeFilenamePart normalizes unsafe labels", () => {
  assert.equal(safeFilenamePart(" Owner User@example.com "), "owner-user-example-com");
  assert.equal(safeFilenamePart("!!!", "download"), "download");
});

test("generateTemporaryPassword supports deterministic test values", () => {
  assert.equal(generateTemporaryPassword(new Uint32Array([0, 1, 2, 3])), "Ab4$");
});

test("generateTemporaryPassword creates onboarding-ready passwords", () => {
  const password = generateTemporaryPassword(new Uint32Array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]));
  assert.deepEqual(passwordStrengthChecks(password).map((check) => check.ok), [true, true, true, true]);
});
