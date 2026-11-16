/**
 * Shared state for the overlay. Deliberately imports nothing, so no circular
 * dependency can form between the capture and ui layers.
 */

@ObservedV2
export class DebugUiState {
  private static instance: DebugUiState | undefined = undefined;

  @Trace panelOpen: boolean = false;
  @Trace fabX: number = 0;
  @Trace fabY: number = 80;
  @Trace errorCount: number = 0;
  @Trace logCount: number = 0;
  /** Set once, after the screen width becomes known. */
  @Trace positioned: boolean = false;

  static get(): DebugUiState {
    if (DebugUiState.instance === undefined) {
      DebugUiState.instance = new DebugUiState();
    }
    return DebugUiState.instance;
  }
}