/**
 * Overlay root node + draggable bug button.
 *
 * The root has to be full screen: with a 48x48 root the overlay wrapper clips
 * any child that position pushes outside it, and the button never shows up.
 * Touch pass-through is handled by hitTestBehavior instead.
 *
 * Screen size comes from onAreaChange rather than display, since the px2vp
 * calculation was returning unreliable values.
 */

import { DebugUiState } from './DebugUiState';

export const FAB_SIZE: number = 48;
const EDGE_MARGIN: number = 8;

export class DebugFabParams {
  readonly onToggle: () => void;

  constructor(onToggle: () => void) {
    this.onToggle = onToggle;
  }
}

@ComponentV2
struct DebugFab {
  @Param params: DebugFabParams = new DebugFabParams(() => {});

  private state: DebugUiState = DebugUiState.get();
  @Local screenW: number = 360;
  @Local screenH: number = 780;
  private startX: number = 0;
  private startY: number = 0;

  private clamp(value: number, max: number): number {
    if (value < EDGE_MARGIN) {
      return EDGE_MARGIN;
    }
    return value > max ? max : value;
  }

  build() {
    if (!this.state.panelOpen) {
      Stack() {
        Text('DBG')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF');

        if (this.state.errorCount > 0) {
          Text(this.state.errorCount > 99 ? '99+' : `${this.state.errorCount}`)
            .fontSize(9)
            .fontColor('#FFFFFF')
            .backgroundColor('#E53935')
            .borderRadius(8)
            .padding({
              left: 4,
              right: 4,
              top: 1,
              bottom: 1
            })
            .offset({ x: 16, y: -16 });
        }
      }
      .width(FAB_SIZE)
      .height(FAB_SIZE)
      .borderRadius(FAB_SIZE / 2)
      .backgroundColor('#2D6A9F')
      .shadow({ radius: 8, color: '#40000000', offsetY: 2 })
      .offset({ x: this.state.fabX, y: this.state.fabY })
      .onClick(() => {
        this.params.onToggle();
      })
      .gesture(
        PanGesture({ fingers: 1, direction: PanDirection.All, distance: 5 })
          .onActionStart(() => {
            this.startX = this.state.fabX;
            this.startY = this.state.fabY;
          })
          .onActionUpdate((event: GestureEvent) => {
            this.state.fabX = this.startX + event.offsetX;
            this.state.fabY = this.startY + event.offsetY;
          })
      );
    }
  }
}

@Builder
export function debugFabBuilder(params: DebugFabParams) {
  DebugFab({ params: params });
}