/**
 * Periodically drains the native buffer and writes the entries into LogStore.
 *
 * The callback can fire from arbitrary threads, so we never jump straight into
 * ArkTS from it; instead the lines pile up on the native side and a timer pulls
 * them across.
 *
 * Never use console.* in this file: anything it logs lands back in its own
 * callback and creates a feedback loop.
 */

import nativeLog from 'libportable_debug_panel.so';
import { LogLevel, LogLevels, LogEntry } from '../model/LogEntry';
import { LogStore } from '../store/LogStore';
import { LogFileWriter } from '../store/LogFileWriter';

export class NativeLogBridge {
  private static readonly SEP: string = '\u001F';
  private static readonly FIELD_COUNT: number = 6;
  private static timerId: number = -1;
  private static running: boolean = false;
  private static readonly ACTIVE_MS: number = 100;
  private static readonly IDLE_MS: number = 1000;
  private static intervalMs: number = NativeLogBridge.IDLE_MS;
  private static listener: (() => void) | undefined = undefined;

  /**
   * @param captureAll when true, system logs are captured as well (noisy).
   * @returns whether the native callback was installed.
   */
  static start(captureAll: boolean = false): boolean {
    if (NativeLogBridge.running) {
      return true;
    }
    let installed: boolean = false;
    try {
      installed = nativeLog.install();
      if (!installed) {
        return false;
      }
    } catch (err) {
      return false;
    }

    try {
      nativeLog.setCaptureAll(captureAll);
      nativeLog.setEnabled(true);
    } catch (err) {
      return false;
    }

    NativeLogBridge.running = true;
    NativeLogBridge.timerId = setInterval(() => {
      NativeLogBridge.drain();
    }, NativeLogBridge.intervalMs);
    return true;
  }

  static stop(): void {
    if (NativeLogBridge.timerId >= 0) {
      clearInterval(NativeLogBridge.timerId);
      NativeLogBridge.timerId = -1;
    }
    try {
      nativeLog.setEnabled(false);
    } catch (err) {
      // Native module unavailable; the timer is already stopped, so nothing accumulates.
    }
    NativeLogBridge.running = false;
  }

  static setActive(active: boolean): void {
    const next: number = active ? NativeLogBridge.ACTIVE_MS : NativeLogBridge.IDLE_MS;
    if (next === NativeLogBridge.intervalMs || !NativeLogBridge.running) {
      NativeLogBridge.intervalMs = next;
      return;
    }
    NativeLogBridge.intervalMs = next;
    if (NativeLogBridge.timerId >= 0) {
      clearInterval(NativeLogBridge.timerId);
    }
    NativeLogBridge.timerId = setInterval(() => {
      NativeLogBridge.drain();
    }, NativeLogBridge.intervalMs);
  }

  static setListener(listener: () => void): void {
    NativeLogBridge.listener = listener;
  }

  static isRunning(): boolean {
    return NativeLogBridge.running;
  }

  static setCaptureAll(captureAll: boolean): void {
    try {
      nativeLog.setCaptureAll(captureAll);
    } catch (err) {
      // Native module unavailable; capture settings stay as they are.
    }
  }

  static drain(): number {
    let lines: Array<string> = [];
    try {
      lines = nativeLog.drain();
    } catch (err) {
      return 0;
    }
    const store: LogStore = LogStore.getInstance();
    const batch: Array<LogEntry> = [];
    for (let i = 0; i < lines.length; i++) {
      const entry: LogEntry | undefined = NativeLogBridge.parseInto(store, lines[i]);
      if (entry !== undefined) {
        batch.push(entry);
      }
    }
    if (batch.length > 0) {
      LogFileWriter.append(batch);
      if (NativeLogBridge.listener !== undefined) {
        NativeLogBridge.listener();
      }
    }
    return batch.length;
  }

  private static parseInto(store: LogStore, line: string): LogEntry | undefined {
    const parts: Array<string> = line.split(NativeLogBridge.SEP);
    if (parts.length < NativeLogBridge.FIELD_COUNT) {
      return undefined;
    }
    const ts: number = Number.parseInt(parts[0], 10);
    const level: LogLevel = LogLevels.fromRaw(Number.parseInt(parts[2], 10));
    const domain: number = Number.parseInt(parts[3], 10);
    const tag: string = parts[4];
    const message: string = parts.length === NativeLogBridge.FIELD_COUNT
      ? parts[5]
      : parts.slice(5).join(NativeLogBridge.SEP);

    return store.add(Number.isNaN(ts) ? Date.now() : ts, level, Number.isNaN(domain) ? 0 : domain, tag, message);
  }
}