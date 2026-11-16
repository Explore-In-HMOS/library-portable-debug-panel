import { fileIo } from '@kit.CoreFileKit';
import { LogEntry, LogLevels } from '../model/LogEntry';

export const FILE_MODE_OFF: number = 0;

export const FILE_MODE_FULL: number = 1;

export const FILE_MODE_MESSAGE_ONLY: number = 2;

class FullRecord {
  t: string;
  l: string;
  m: string;

  constructor(t: string, l: string, m: string) {
    this.t = t;
    this.l = l;
    this.m = m;
  }
}

export class LogFileWriter {
  private static file: fileIo.File | undefined = undefined;
  private static mode: number = FILE_MODE_OFF;
  private static filePath: string = '';
  private static written: number = 0;
  private static error: string = '';
  private static maxBytes: number = 5 * 1024 * 1024;
  private static baseDir: string = '';

  static isActive(): boolean {
    return LogFileWriter.file !== undefined;
  }

  static lastError(): string {
    return LogFileWriter.error;
  }

  static start(filesDir: string, mode: number): boolean {
    if (LogFileWriter.isActive()) {
      return true;
    }
    if (mode !== FILE_MODE_FULL && mode !== FILE_MODE_MESSAGE_ONLY) {
      LogFileWriter.mode = FILE_MODE_OFF;
      return false;
    }
    LogFileWriter.mode = mode;
    LogFileWriter.baseDir = `${filesDir}/debugkit`;
    return LogFileWriter.openNew();
  }

  private static openNew(): boolean {
    try {
      if (!fileIo.accessSync(LogFileWriter.baseDir)) {
        fileIo.mkdirSync(LogFileWriter.baseDir, true);
      }
      const path: string = `${LogFileWriter.baseDir}/log-${LogFileWriter.stamp()}.jsonl`;
      LogFileWriter.file = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY);
      LogFileWriter.filePath = path;
      LogFileWriter.written = 0;
      return true;
    } catch (err) {
      LogFileWriter.error = `open: ${err}`;
      LogFileWriter.file = undefined;
      return false;
    }
  }

  static append(entries: Array<LogEntry>): void {
    const file: fileIo.File | undefined = LogFileWriter.file;
    if (file === undefined || entries.length === 0) {
      return;
    }
    let chunk: string = '';
    for (let i = 0; i < entries.length; i++) {
      chunk += LogFileWriter.toLine(entries[i]);
    }
    try {
      LogFileWriter.written += fileIo.writeSync(file.fd, chunk);
    } catch (err) {
      LogFileWriter.error = `write: ${err}`;
      return;
    }
    if (LogFileWriter.maxBytes > 0 && LogFileWriter.written >= LogFileWriter.maxBytes) {
      LogFileWriter.rotate();
    }
  }

  private static toLine(entry: LogEntry): string {
    if (LogFileWriter.mode === FILE_MODE_MESSAGE_ONLY) {
      return `${JSON.stringify(entry.message)}\n`;
    }
    const record: FullRecord = new FullRecord(
      LogFileWriter.dateTime(entry.ts),
      LogLevels.label(entry.level),
      entry.message
    );
    return `${JSON.stringify(record)}\n`;
  }

  private static rotate(): void {
    LogFileWriter.close();
    LogFileWriter.openNew();
  }

  static stop(): void {
    LogFileWriter.close();
    LogFileWriter.mode = FILE_MODE_OFF;
  }

  private static close(): void {
    const file: fileIo.File | undefined = LogFileWriter.file;
    if (file === undefined) {
      return;
    }
    try {
      fileIo.fsyncSync(file.fd);
      fileIo.closeSync(file);
    } catch (err) {
      LogFileWriter.error = `close: ${err}`;
    }
    LogFileWriter.file = undefined;
  }

  private static pad2(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }

  private static pad3(value: number): string {
    if (value < 10) {
      return `00${value}`;
    }
    return value < 100 ? `0${value}` : `${value}`;
  }

  private static stamp(): string {
    const d: Date = new Date();
    const date: string = `${d.getFullYear()}${LogFileWriter.pad2(d.getMonth() + 1)}${LogFileWriter.pad2(d.getDate())}`;
    const time: string =
      `${LogFileWriter.pad2(d.getHours())}${LogFileWriter.pad2(d.getMinutes())}${LogFileWriter.pad2(d.getSeconds())}`;
    return `${date}-${time}`;
  }

  private static dateTime(ts: number): string {
    const d: Date = new Date(ts);
    const date: string =
      `${d.getFullYear()}-${LogFileWriter.pad2(d.getMonth() + 1)}-${LogFileWriter.pad2(d.getDate())}`;
    const time: string =
      `${LogFileWriter.pad2(d.getHours())}:${LogFileWriter.pad2(d.getMinutes())}:${LogFileWriter.pad2(
        d.getSeconds())}.${LogFileWriter.pad3(d.getMilliseconds())}`;
    return `${date} ${time}`;
  }
}