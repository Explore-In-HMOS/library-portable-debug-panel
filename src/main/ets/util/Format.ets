export class Format {
  private static pad2(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }

  private static pad3(value: number): string {
    if (value < 10) {
      return `00${value}`;
    }
    return value < 100 ? `0${value}` : `${value}`;
  }

  static time(ts: number): string {
    const d: Date = new Date(ts);
    return `${Format.pad2(d.getHours())}:${Format.pad2(d.getMinutes())}:${Format.pad2(d.getSeconds())}.${Format.pad3(
      d.getMilliseconds())}`;
  }
}