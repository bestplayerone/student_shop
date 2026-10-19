function invalidConfiguration(): never {
  throw new Error("invalid Supabase key configuration");
}

export function resolveSupabaseKey(
  keyDictionary: string | undefined,
  legacyKey: string | undefined,
): string {
  if (keyDictionary?.trim()) {
    let parsed: unknown;
    try {
      parsed = JSON.parse(keyDictionary);
    } catch {
      return invalidConfiguration();
    }
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      return invalidConfiguration();
    }
    const values = Object.values(parsed as Record<string, unknown>);
    const defaultKey = (parsed as Record<string, unknown>).default;
    if (
      typeof defaultKey === "string" && defaultKey.length > 0 && defaultKey.trim() === defaultKey
    ) {
      return defaultKey;
    }
    const validValues = values.filter(
      (value): value is string =>
        typeof value === "string" && value.length > 0 && value.trim() === value,
    );
    if (validValues.length === 1 && values.length === 1) return validValues[0];
    return invalidConfiguration();
  }
  if (legacyKey?.trim()) return legacyKey;
  return invalidConfiguration();
}
