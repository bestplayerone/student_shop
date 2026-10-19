export function assert(condition: unknown, message = "Assertion failed"): asserts condition {
  if (!condition) throw new Error(message);
}

export function equal(actual: unknown, expected: unknown): void {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(`Expected ${JSON.stringify(expected)}, received ${JSON.stringify(actual)}`);
  }
}

export async function rejects(fn: () => Promise<unknown>, pattern: RegExp): Promise<void> {
  try {
    await fn();
  } catch (error) {
    assert(pattern.test(String(error)), `Unexpected error: ${error}`);
    return;
  }
  throw new Error("Expected rejection");
}
