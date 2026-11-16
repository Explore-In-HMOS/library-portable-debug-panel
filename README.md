> **Note:** To access all shared projects, get information about environment setup, and view other guides, please visit [Explore-In-HMOS Index](https://github.com/Explore-In-HMOS/hmos-index).

# Portable Debug Panel

On-device log panel for HarmonyOS apps. Captures console and hilog output natively, 
displays it in a floating overlay you can open from any screen, and stores it as JSONL for later analysis. 
It requires no changes to your code. Every log line your app already writes is picked up as it is, including output from libraries running in the same process.

# Installation

```bash
ohpm install @explore-in-hmos/portable_debug_panel
```

# Usage

## Debug Panel Usage

```ets
import { DebugKit } from '@explore-in-hmos/portable_debug_panel';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    DebugKit.init(this.context, 1);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        return;
      }
      DebugKit.attach(windowStage);
    });
  }

  onWindowStageDestroy(): void {
    DebugKit.detach();
  }
}
```

That is the whole integration. init starts log capture and needs no UI, so calling it early means startup logs are captured too. attach mounts the button onto the window.

The second argument of init controls file output. 0 writes nothing, 1 stores the timestamp, level and message, 2 stores only the message. Any other value counts as 0.

Both calls are safe to repeat and the order does not matter. Calling init late only means the entries before it are missed.

The third argument is an options object, and every field in it is optional:

- enabled (default true) -> when false nothing is installed at all: no capture, no file, no button. Use it to switch the library off in release builds.

- maxEntries (default 2000) -> how many records are kept in memory. Once the limit is passed, the oldest entries are dropped.

- captureAll (default false) -> when true, system framework logs are captured alongside your own. This is noisy, so it is off by default.

To turn everything off in release builds:

```ets
DebugKit.init(this.context, 1, { enabled: BuildProfile.DEBUG });
```

Other options: maxEntries sets how many records are held in memory (default 2000), and captureAll includes system framework logs, which is noisy and off by default.

## Pulling The Logs From PC 

Log files are written to the app sandbox as JSONL, one file per app launch, named after the time it was opened:

./data/storage/el2/base/files/debugpanel/log-20261001-092307.jsonl

The repository includes a [script](https://github.com/Explore-In-HMOS/library-portable-debug-panel/tree/main/script) that pulls them to your desktop. Run debug-logs.bat with the device connected over hdc.

It lists the apps installed on the device, filtering out system packages. Enter the number of your app and it shows the log files it found. Enter a file number to pull that one file, or 0 to pull all of them. Everything lands in a timestamped folder on your desktop.

If you prefer to do it by hand, hdc works directly:

```ets
hdc file recv -b com.your.app "./data/storage/el2/base/files/debugpanel" D:\logs
```


# License

**Portable Debug Panel** is distributed under the terms of the MIT License. See the [LICENSE](LICENSE) for more information.
