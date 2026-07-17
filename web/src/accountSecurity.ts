import type { ApiConfig, Role } from "./api/client";

export type ReadinessCheck = {
  label: string;
  ok: boolean;
};

export function passwordStrengthChecks(password: string): ReadinessCheck[] {
  return [
    { label: "At least 12 characters", ok: password.length >= 12 },
    { label: "Contains uppercase and lowercase letters", ok: /[A-Z]/.test(password) && /[a-z]/.test(password) },
    { label: "Contains a number", ok: /\d/.test(password) },
    { label: "Contains a symbol", ok: /[^A-Za-z0-9]/.test(password) }
  ];
}

export function passwordChangeChecks(currentPassword: string, newPassword: string): ReadinessCheck[] {
  return [
    { label: "Current password entered", ok: Boolean(currentPassword) },
    { label: "New password has 12+ characters", ok: newPassword.length >= 12 },
    { label: "New password differs from current", ok: Boolean(newPassword && newPassword !== currentPassword) }
  ];
}

export function connectionReadinessChecks(config: Pick<ApiConfig, "baseUrl" | "accessToken" | "refreshToken" | "organizationId">): ReadinessCheck[] {
  return [
    { label: "API URL saved", ok: Boolean(config.baseUrl.trim()) },
    { label: "Access token present", ok: Boolean(config.accessToken.trim()) },
    { label: "Refresh token present", ok: Boolean(config.refreshToken?.trim()) },
    { label: "Organization selected", ok: Boolean(config.organizationId.trim()) }
  ];
}

export function extractPasswordResetToken(rawUrl: string) {
  let url: URL;
  try {
    url = new URL(rawUrl);
  } catch {
    return "";
  }

  const queryToken = url.searchParams.get("reset_token") ?? url.searchParams.get("token");
  if (queryToken) {
    return queryToken.trim();
  }

  const hashText = url.hash.replace(/^#/, "");
  if (hashText) {
    const hashQuery = hashText.includes("?") ? hashText.slice(hashText.indexOf("?") + 1) : hashText;
    const hashParams = new URLSearchParams(hashQuery);
    const hashToken = hashParams.get("reset_token") ?? hashParams.get("token");
    if (hashToken) {
      return hashToken.trim();
    }
    const hashPathParts = hashText.split("?")[0].split("/").map((part) => decodeURIComponent(part)).filter(Boolean);
    const hashResetIndex = hashPathParts.findIndex((part) => part === "reset-password" || part === "password-reset");
    if (hashResetIndex >= 0 && hashPathParts[hashResetIndex + 1]) {
      return hashPathParts[hashResetIndex + 1].trim();
    }
  }

  const pathParts = url.pathname.split("/").map((part) => decodeURIComponent(part)).filter(Boolean);
  const resetIndex = pathParts.findIndex((part) => part === "reset-password" || part === "password-reset");
  if (resetIndex >= 0 && pathParts[resetIndex + 1]) {
    return pathParts[resetIndex + 1].trim();
  }
  return "";
}

export function roleDescription(role: Role) {
  switch (role) {
    case "admin":
      return "Full organization administration, users, settings, and all accounting workflows.";
    case "accountant":
      return "Financial operations, reports, tax, reconciliation, and period-end work without user administration.";
    case "bookkeeper":
      return "Daily accounts, ledger, invoices, expenses, bills, and reconciliation entry workflows.";
    case "payroll_manager":
      return "Payroll employee records, payroll runs, payslips, and payroll reports.";
    case "employee_self_service":
      return "Employee-facing self-service workflows when enabled.";
    case "viewer":
    default:
      return "Read-only review of organization accounting data.";
  }
}

export function safeFilenamePart(value: string, fallback = "employee") {
  return value.trim().toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "") || fallback;
}

export function generateTemporaryPassword(randomValues?: Uint32Array) {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%*-_=+";
  const values = randomValues ?? new Uint32Array(18);
  if (!randomValues) {
    if ("crypto" in globalThis && "getRandomValues" in crypto) {
      crypto.getRandomValues(values);
    } else {
      for (let index = 0; index < values.length; index += 1) {
        values[index] = Math.floor(Math.random() * alphabet.length);
      }
    }
  }
  return Array.from(values, (value) => alphabet[value % alphabet.length]).join("");
}
