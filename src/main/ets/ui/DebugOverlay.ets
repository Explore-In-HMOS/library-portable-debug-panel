/**
 * Overlay management. Two separate ComponentContent instances are kept:
 *   - fab:   always mounted, hosts the full-screen root and the button itself.
 *   - panel: mounted only while open, removed on close.
 *
 * The fab root spans the screen, so touch pass-through is handled inside it via
 * hitTestBehavior; see DebugFab for why a small root does not work here.
 */

import { ComponentContent, display, OverlayManager, UIContext } from '@kit.ArkUI';
import { NativeLogBridge } from '../capture/NativeLogBridge';
import { LogStore } from '../store/LogStore';
import { DebugUiState } from './DebugUiState';
import { debugFabBuilder, DebugFabParams } from './DebugFab';
import { debugPanelBuilder, DebugPanelParams } from './DebugPanel';
import { hilog } from '@kit.PerformanceAnalysisKit';

export class DebugOverlay {
  private static context: UIContext | undefined = undefined;
  private static manager: OverlayManager | undefined = undefined;
  private static fab: ComponentContent<DebugFabParams> | undefined = undefined;
  private static panel: ComponentContent<DebugPanelParams> | undefined = undefined;

  static isMounted(): boolean {
    return DebugOverlay.fab !== undefined;
  }

  static mount(uiContext: UIContext): boolean {
    if (DebugOverlay.isMounted()) {
      return true;
    }
    try {
      const info: display.Display = display.getDefaultDisplaySync();
      const params: DebugFabParams = new DebugFabParams(() => {
        DebugOverlay.togglePanel();
      });

      const content: ComponentContent<DebugFabParams> = new ComponentContent(
        uiContext,
        wrapBuilder<[DebugFabParams]>(debugFabBuilder),
        params
      );
      const manager: OverlayManager = uiContext.getOverlayManager();
      manager.addComponentContent(content, 1);

      DebugOverlay.context = uiContext;
      DebugOverlay.manager = manager;
      DebugOverlay.fab = content;

      NativeLogBridge.setListener(() => {
        const store: LogStore = LogStore.getInstance();
        const state: DebugUiState = DebugUiState.get();
        state.errorCount = store.errors();
        state.logCount = store.size();
      });
      return true;
    } catch (err) {
      hilog.error(0x0000, 'DEBUGKIT', 'mount: %{public}s', JSON.stringify(err));
      return false;
    }
  }

  static togglePanel(): void {
    if (DebugOverlay.panel === undefined) {
      DebugOverlay.openPanel();
    } else {
      DebugOverlay.closePanel();
    }
  }

  static openPanel(): void {
    const uiContext: UIContext | undefined = DebugOverlay.context;
    const manager: OverlayManager | undefined = DebugOverlay.manager;
    if (uiContext === undefined || manager === undefined || DebugOverlay.panel !== undefined) {
      return;
    }
    try {
      const params: DebugPanelParams = new DebugPanelParams(() => {
        DebugOverlay.closePanel();
      });
      const content: ComponentContent<DebugPanelParams> = new ComponentContent(
        uiContext,
        wrapBuilder<[DebugPanelParams]>(debugPanelBuilder),
        params
      );
      manager.addComponentContent(content, 0);
      DebugOverlay.panel = content;
      DebugUiState.get().panelOpen = true;
    } catch (err) {
      hilog.error(0x0000, 'DEBUGKIT', 'openPanel: %{public}s', JSON.stringify(err));
    }
  }

  static closePanel(): void {
    const manager: OverlayManager | undefined = DebugOverlay.manager;
    const content: ComponentContent<DebugPanelParams> | undefined = DebugOverlay.panel;
    if (manager === undefined || content === undefined) {
      return;
    }
    try {
      manager.removeComponentContent(content);
      content.dispose();
    } catch (err) {
      //
    }
    DebugOverlay.panel = undefined;
    DebugUiState.get().panelOpen = false;
  }

  static unmount(): void {
    DebugOverlay.closePanel();
    const manager: OverlayManager | undefined = DebugOverlay.manager;
    const content: ComponentContent<DebugFabParams> | undefined = DebugOverlay.fab;
    if (manager !== undefined && content !== undefined) {
      try {
        manager.removeComponentContent(content);
        content.dispose();
      } catch (err) {
        // yut
      }
    }
    DebugOverlay.fab = undefined;
    DebugOverlay.manager = undefined;
    DebugOverlay.context = undefined;
  }
}