import { LogEntry, LogLevel } from '../model/LogEntry';

export class LogStore {
  private static instance: LogStore | undefined = undefined;

  private entries: Array<LogEntry> = [];
  private nextId: number = 1;
  private dirty: boolean = false;
  private errorCount: number = 0;
  private maxEntries: number = 2000;
  private trimSlack: number = 200;

  static getInstance(): LogStore {
    if (LogStore.instance === undefined) {
      LogStore.instance = new LogStore();
    }
    return LogStore.instance;
  }

  configure(maxEntries: number): void {
    if (maxEntries > 0) {
      this.maxEntries = maxEntries;
    }
  }

  add(ts: number, level: LogLevel, domain: number, tag: string, message: string): LogEntry {
    const entry: LogEntry = new LogEntry(this.nextId, ts, level, domain, tag, message);
    this.entries.push(entry);
    this.nextId++;
    if (level >= LogLevel.ERROR) {
      this.errorCount++;
    }
    if (this.entries.length > this.maxEntries + this.trimSlack) {
      this.entries.splice(0, this.entries.length - this.maxEntries);
    }
    this.dirty = true;
    return entry;
  }

  query(levels: Set<LogLevel>, keyword: string): Array<LogEntry> {
    const hasLevelFilter: boolean = levels.size > 0;
    const needle: string = keyword.trim().toLowerCase();
    const hasKeyword: boolean = needle.length > 0;
    if (!hasLevelFilter && !hasKeyword) {
      return this.entries.slice();
    }
    const result: Array<LogEntry> = [];
    for (let i = 0; i < this.entries.length; i++) {
      const entry: LogEntry = this.entries[i];
      if (hasLevelFilter && !levels.has(entry.level)) {
        continue;
      }
      if (hasKeyword && !entry.message.toLowerCase().includes(needle)) {
        continue;
      }
      result.push(entry);
    }
    return result;
  }

  size(): number {
    return this.entries.length;
  }

  errors(): number {
    return this.errorCount;
  }

  isDirty(): boolean {
    return this.dirty;
  }

  clearDirty(): void {
    this.dirty = false;
  }

  clear(): void {
    this.entries = [];
    this.errorCount = 0;
    this.dirty = true;
  }
}