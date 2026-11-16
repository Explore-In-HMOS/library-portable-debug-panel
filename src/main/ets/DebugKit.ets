/**
 * The library's only public surface. This is all the consumer sees.
 */

import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { NativeLogBridge } from './capture/NativeLogBridge';
import { DebugOverlay } from './ui/DebugOverlay';
import { LogStore } from './store/LogStore';
import { LogFileWriter } from './store/LogFileWriter';

export interface DebugKitOptions {
  /** When false nothing is installed. Use BuildProfile to switch it off in release. */
  enabled?: boolean;
  /** Maximum number of entries kept in memory. */
  maxEntries?: number;
  /** When true system framework logs are captured as well. */
  captureAll?: boolean;
}

export class DebugKit {
  private static enabled: boolean = true;

  /**
   * Starts log capture. Needs no UI, so calling it from EntryAbility.onCreate
   * also catches the logs emitted during startup.
   *
   * Safe to call more than once and at any point in the lifecycle: every layer
   * below ignores a repeated call. Calling it late only means the entries
   * before it are missed.
   *
   * @param context the ability context; file paths are resolved from it.
   * @param fileMode 0 off, 1 timestamp + level + message, 2 message only.
   *                 Any other value counts as 0.
   */
  static init(context: common.Context, fileMode: number = 0, options?: DebugKitOptions): boolean {
    DebugKit.enabled = options?.enabled ?? true;
    if (!DebugKit.enabled) {
      return false;
    }
    LogStore.getInstance().configure(options?.maxEntries ?? 2000);
    LogFileWriter.start(context.getApplicationContext().filesDir, fileMode);
    return NativeLogBridge.start(options?.captureAll ?? false);
  }

  /** Mounts the button on the window. Call it inside the loadContent callback. */
  static attach(windowStage: window.WindowStage): boolean {
    if (!DebugKit.enabled) {
      return false;
    }
    if (!NativeLogBridge.isRunning()) {
      NativeLogBridge.start(false);
    }
    try {
      return DebugOverlay.mount(windowStage.getMainWindowSync().getUIContext());
    } catch (err) {
      // Debug tooling must never break the host app; the overlay just stays down.
      return false;
    }
  }

  /** Removes the button and the panel; capture keeps running. */
  static detach(): void {
    DebugOverlay.unmount();
  }

  /** Stops everything. */
  static shutdown(): void {
    DebugOverlay.unmount();
    NativeLogBridge.stop();
    LogFileWriter.stop();
  }
}