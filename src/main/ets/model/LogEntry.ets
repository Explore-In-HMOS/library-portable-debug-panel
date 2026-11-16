export enum LogLevel {
  DEBUG = 3,
  INFO = 4,
  WARN = 5,
  ERROR = 6,
  FATAL = 7
}

export class LogEntry {
  readonly id: number;
  readonly ts: number;
  readonly level: LogLevel;
  readonly domain: number;
  readonly tag: string;
  readonly message: string;

  constructor(id: number, ts: number, level: LogLevel, domain: number, tag: string, message: string) {
    this.id = id;
    this.ts = ts;
    this.level = level;
    this.domain = domain;
    this.tag = tag;
    this.message = message;
  }
}

export class LogLevels {
  static all(): Array<LogLevel> {
    return [LogLevel.DEBUG, LogLevel.INFO, LogLevel.WARN, LogLevel.ERROR, LogLevel.FATAL];
  }

  static fromRaw(raw: number): LogLevel {
    switch (raw) {
      case 3: return LogLevel.DEBUG;
      case 4: return LogLevel.INFO;
      case 5: return LogLevel.WARN;
      case 6: return LogLevel.ERROR;
      case 7: return LogLevel.FATAL;
      default: return LogLevel.INFO;
    }
  }

  static label(level: LogLevel): string {
    switch (level) {
      case LogLevel.DEBUG: return 'DEBUG';
      case LogLevel.INFO: return 'INFO';
      case LogLevel.WARN: return 'WARN';
      case LogLevel.ERROR: return 'ERROR';
      case LogLevel.FATAL: return 'FATAL';
      default: return 'INFO';
    }
  }

  static short(level: LogLevel): string {
    switch (level) {
      case LogLevel.DEBUG: return 'D';
      case LogLevel.INFO: return 'I';
      case LogLevel.WARN: return 'W';
      case LogLevel.ERROR: return 'E';
      case LogLevel.FATAL: return 'F';
      default: return 'I';
    }
  }
}