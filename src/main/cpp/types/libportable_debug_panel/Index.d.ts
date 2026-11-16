/** Registers the hilog callback. Installed once, never removed. */
export const install: () => boolean;

/** Turns buffering on/off. While off, the callback collects nothing. */
export const setEnabled: (enabled: boolean) => boolean;

/** true: includes system logs. false (default): LOG_APP only. */
export const setCaptureAll: (captureAll: boolean) => boolean;

/**
 * Drains the buffer and returns the collected lines.
 * Line format: ts \x1F type \x1F level \x1F domain \x1F tag \x1F message
 */
export const drain: () => Array<string>;

/** [total, dropped, pending] */
export const stats: () => Array<number>;