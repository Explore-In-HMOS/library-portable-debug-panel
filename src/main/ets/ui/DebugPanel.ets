/**
 * Log panel. Added to the overlay only while open, removed on close.
 * Blocking whatever is underneath while open is the intended behaviour.
 *
 * Never use console.* in this file: anything it logs ends up in its own list.
 */

import { LogEntry, LogLevel, LogLevels } from '../model/LogEntry';
import { LogStore } from '../store/LogStore';
import { LogDataSource } from '../store/LogDataSource';
import { NativeLogBridge } from '../capture/NativeLogBridge';
import { Format } from '../util/Format';

const REFRESH_MS: number = 100;

export class DebugPanelParams {
  readonly onClose: () => void;

  constructor(onClose: () => void) {
    this.onClose = onClose;
  }
}

@ComponentV2
struct DebugPanel {
  @Param params: DebugPanelParams = new DebugPanelParams(() => {});

  @Local total: number = 0;
  @Local errors: number = 0;
  @Local levelFilter: number = 0;
  @Local keyword: string = '';
  @Local autoScroll: boolean = true;
  @Local searchOpen: boolean = false;
  @Local confirmClear: boolean = false;
  private confirmTimer: number = -1;

  private source: LogDataSource = new LogDataSource();
  private scroller: Scroller = new Scroller();
  private timerId: number = -1;
  private initialScrollDone: boolean = false;

  aboutToAppear(): void {
    NativeLogBridge.setActive(true);
    NativeLogBridge.drain();
    this.reload();
    setTimeout(() => {
      this.scroller.scrollEdge(Edge.Bottom);
      this.initialScrollDone = true;
    }, 50);
    this.timerId = setInterval(() => {
      const store: LogStore = LogStore.getInstance();
      if (store.isDirty()) {
        store.clearDirty();
        this.reload();
      }
    }, REFRESH_MS);
  }

  aboutToDisappear(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
    if (this.confirmTimer >= 0) {
      clearTimeout(this.confirmTimer);
      this.confirmTimer = -1;
    }
    NativeLogBridge.setActive(false);
  }

  private onClearTap(): void {
    if (this.confirmClear) {
      if (this.confirmTimer >= 0) {
        clearTimeout(this.confirmTimer);
        this.confirmTimer = -1;
      }
      this.confirmClear = false;
      LogStore.getInstance().clear();
      this.reload();
      return;
    }
    this.confirmClear = true;
    this.confirmTimer = setTimeout(() => {
      this.confirmClear = false;
      this.confirmTimer = -1;
    }, 3000);
  }

  private levelSet(): Set<LogLevel> {
    const set: Set<LogLevel> = new Set();
    if (this.levelFilter > 0) {
      set.add(LogLevels.fromRaw(this.levelFilter));
    }
    return set;
  }

  private reload(): void {
    const store: LogStore = LogStore.getInstance();
    this.source.setItems(store.query(this.levelSet(), this.keyword));
    this.total = store.size();
    this.errors = store.errors();
    if (this.autoScroll && this.source.totalCount() > 0) {
      this.scroller.scrollEdge(Edge.Bottom);
    }
  }

  private colorOf(level: LogLevel): string {
    if (level >= LogLevel.ERROR) {
      return '#FF6B6B';
    }
    if (level === LogLevel.WARN) {
      return '#FFC46B';
    }
    return '#DDDDDD';
  }

  @Builder
  searchIcon(color: string) {
    Stack() {
      Circle()
        .width(9)
        .height(9)
        .fill(Color.Transparent)
        .stroke(color)
        .strokeWidth(1.5)
        .offset({ x: -1.5, y: -1.5 })
      Column()
        .width(1.5)
        .height(5)
        .borderRadius(1)
        .backgroundColor(color)
        .rotate({ angle: -45 })
        .offset({ x: 4, y: 4 })
    }
    .width(16)
    .height(16)
  }

  @Builder
  bottomBar() {
    Row({ space: 8 }) {
      Text(this.confirmClear ? `\u{2713}` : `\u{1F5D1}`)
        .fontSize(this.confirmClear ? 13 : 11)
        .fontColor('#FFFFFF')
        .textAlign(TextAlign.Center)
        .width(24)
        .height(24)
        .borderRadius(12)
        .backgroundColor(this.confirmClear ? '#E53935' : '#2E2E2E')
        .onClick(() => {
          this.onClearTap();
        })

      Text(this.filterLabel())
        .fontSize(11)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.filterFg())
        .textAlign(TextAlign.Center)
        .width(24)
        .height(24)
        .borderRadius(12)
        .backgroundColor(this.filterBg())
        .onClick(() => {
          this.nextFilter();
        })

      Stack() {
        this.searchIcon(this.searchOpen || this.keyword.length > 0 ? '#1B1B1B' : '#BBBBBB')
      }
      .width(24)
      .height(24)
      .borderRadius(12)
      .backgroundColor(this.searchOpen || this.keyword.length > 0 ? '#E0A200' : '#2E2E2E')
      .onClick(() => {
        this.searchOpen = !this.searchOpen;
      })

      if (this.searchOpen) {
        Row() {
          TextInput({ placeholder: 'ara', text: this.keyword })
            .fontSize(11)
            .fontColor('#EEEEEE')
            .placeholderColor('#777777')
            .placeholderFont({ size: 11 })
            .backgroundColor(Color.Transparent)
            .height(24)
            .padding({ left: 8, right: 4, top: 0, bottom: 0 })
            .layoutWeight(1)
            .defaultFocus(true)
            .onChange((value: string) => {
              this.keyword = value;
              this.reload();
            })

          if (this.keyword.length > 0) {
            Text('X')
              .fontSize(12)
              .fontColor('#AAAAAA')
              .width(24)
              .height(24)
              .textAlign(TextAlign.Center)
              .onClick(() => {
                this.keyword = '';
                this.reload();
              })
          }
        }
        .width('70%')
        .height(26)
        .backgroundColor('#2E2E2E')
        .borderRadius(6)
        .alignItems(VerticalAlign.Center)
        .position({ x: 20, y: -34 })
      }

      Text('\u{00D7}')
        .fontSize(12)
        .fontColor('#FFFFFF')
        .fontWeight(FontWeight.Bold)
        .textAlign(TextAlign.Center)
        .width(24)
        .height(24)
        .borderRadius(12)
        .backgroundColor('#2E2E2E')
        .onClick(() => {
          this.params.onClose();
        })
    }
    .width('100%')
    .backgroundColor('#3A7CA5')
    .alignItems(VerticalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .padding({ left: 10, right: 10, top: 4, bottom: 4 })
    .border({ width: { top: 1 }, color: '#2A2A2A' })
  }

  private nextFilter(): void {
    if (this.levelFilter === 0) {
      this.levelFilter = LogLevel.WARN;
    } else if (this.levelFilter === LogLevel.WARN) {
      this.levelFilter = LogLevel.ERROR;
    } else {
      this.levelFilter = 0;
    }
    this.reload();
  }

  private filterLabel(): string {
    if (this.levelFilter === LogLevel.WARN) {
      return 'W';
    }
    return this.levelFilter === LogLevel.ERROR ? 'E' : 'A';
  }

  private filterBg(): string {
    if (this.levelFilter === LogLevel.WARN) {
      return '#E0A200';
    }
    return this.levelFilter === LogLevel.ERROR ? '#E53935' : '#2E9E5B';
  }

  private filterFg(): string {
    return this.levelFilter === LogLevel.WARN ? '#1B1B1B' : '#FFFFFF';
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        List({ scroller: this.scroller }) {
          LazyForEach(this.source, (item: LogEntry) => {
            ListItem() {
              Row() {
                Text(Format.time(item.ts))
                  .fontSize(10)
                  .fontColor('#777777')
                  .width(72)
                Text(LogLevels.short(item.level))
                  .fontSize(10)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.colorOf(item.level))
                  .width(14)
                Text(item.message)
                  .fontSize(11)
                  .fontColor(this.colorOf(item.level))
                  .layoutWeight(1)
                  .maxLines(6)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .alignItems(VerticalAlign.Top)
              .width('100%')
              .padding({ left: 12, right: 12, top: 3, bottom: 3 })
            }
          }, (item: LogEntry) => `${item.id}`)
        }
        .layoutWeight(1)
        .width('100%')
        .onScrollIndex((first: number, last: number) => {
          if (!this.initialScrollDone) {
            return;
          }
          this.autoScroll = last >= this.source.totalCount() - 2;
        })
        this.bottomBar()
      }
      .width('100%')
      .height('95%')
      .backgroundColor('#F21B1B1B')
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Default)
  }
}

@Builder
export function debugPanelBuilder(params: DebugPanelParams) {
  DebugPanel({ params: params })
}