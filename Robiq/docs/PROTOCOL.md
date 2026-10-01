# ROBIQ Protocol

ROBIQ talks to devices with **newline-delimited JSON**. Each message is one JSON object.

| Transport | Framing |
|-----------|---------|
| Bluetooth LE (Nordic UART or HM-10 `FFE0/FFE1`) | Each message ends with `\n`. A message may arrive in several BLE packets. |
| Wi-Fi (WebSocket, default port `81`) | One message per WebSocket text frame. The trailing `\n` is optional. |

Lines that aren't valid JSON are shown in the app's **Device log**. This makes plain `Serial.println` debugging work.

## App → Device (commands)

| Command | Example | Notes |
|---------|---------|-------|
| `drive` | `{"cmd":"drive","x":0.5,"y":-0.2}` | `x` = turn, `y` = throttle, both `-1.0 … 1.0` |
| `joint` | `{"cmd":"joint","id":0,"angle":90}` | Servo joint index, angle `0 … 180` |
| `digital` | `{"cmd":"digital","pin":2,"value":1}` | Set a GPIO high (`1`) or low (`0`) |
| `pwm` | `{"cmd":"pwm","pin":12,"value":128}` | PWM duty `0 … 255` |
| `stop` | `{"cmd":"stop"}` | Emergency stop. Halt all motion. |
| `enable` | `{"cmd":"enable"}` | Operator enabled motion. Firmware should ignore `drive`/`joint` until this arrives. |
| `disable` | `{"cmd":"disable"}` | Halt motion and ignore `drive`/`joint` until the next `enable`. Sent on disable, power off and E-stop. |
| `ping` | `{"cmd":"ping"}` | Device replies with `pong` |
| `info` | `{"cmd":"info"}` | Sent on connect. Device replies with `info` |

Your firmware can accept other commands too. Send them from the app with `RobiqCommand.raw({...})`.

## Device → App (messages)

| Type | Example | Notes |
|------|---------|-------|
| `info` | `{"type":"info","name":"My Arm","kind":"arm","joints":5}` | `kind` is `rover`, `arm` or `generic`. It picks the control screen. |
| `telemetry` | `{"type":"telemetry","data":{"battery":7.4,"temp":31.2}}` | Any numeric keys. Each key is graphed. |
| `log` | `{"type":"log","msg":"Motor driver overheated"}` | Shown in the Device log |
| `pong` | `{"type":"pong"}` | Reply to `ping` |

## Safety recommendations for firmware

- Stop all motors when the connection drops (WebSocket disconnect / BLE disconnect).
- Consider a watchdog: stop when no `drive` command arrives for ~500 ms. The app sends joystick updates every 100 ms while the stick moves.
- Clamp every value you receive.
- Start disabled, and disable again whenever the connection drops. The app requires the operator to re-enable after every reconnect.

## Controller state (app side)

The app's Control tab runs an industrial-style state machine and only sends motion commands while it allows motion:

`POWER OFF → IDLE → (hold ENABLE) → ENABLED → RUNNING ⇄ PAUSED`

E-STOP (from any state) and FAULT (e.g. connection lost while enabled) are latched. The operator must hold RESET, which returns the robot to IDLE.

The app sends `ping` once a second and shows the round-trip time. Devices that don't answer still work. The app just shows no latency.
