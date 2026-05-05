# std/log

Structured application logging for Doof. The package exposes a small global logging API, a console logger, and a rolling file logger.

Logs are only emitted after you install a logger with `setLogger(...)`. Without a configured logger, `debug(...)`, `info(...)`, `warn(...)`, and `error(...)` are no-ops. `fatal(...)` still panics after attempting to dispatch the log entry.

## Quick Start

```doof
import { ConsoleLogger, setLogger, info, warn, error } from "std/log"

setLogger(ConsoleLogger())

info("Server started", {
  host: "127.0.0.1",
  port: 8080,
})

warn("Slow request", {
  path: "/reports",
  durationMs: 850,
})

error("Database unavailable", {
  retrying: true,
})
```

Each log entry includes a timestamp, log level, message, structured context, and caller source location.

## Logger Setup

### Console output

```doof
import { ConsoleLogger, LogLevel, setLogger } from "std/log"

logger := ConsoleLogger(LogLevel.Debug)
setLogger(logger)
```

`ConsoleLogger` writes one formatted line per entry to `stderr`. When `stderr` is a TTY, warning and error levels are colorized.

### Rolling file output

```doof
import { RollingFileLogger, LogLevel, setLogger } from "std/log"
import { Duration } from "std/time"

logger := RollingFileLogger(
  "build/app.log",
  LogLevel.Info,
  10_000_000L,
  Duration.ofHours(24L),
  7,
)

setLogger(logger)
```

`RollingFileLogger(path, level, maxBytes, maxAge, maxFiles)` rotates the active file when either threshold is exceeded.

Rotation behavior:

- The active file at `path` is renamed to `path.1`.
- Existing rolled files are shifted upward: `path.1` to `path.2`, and so on.
- Files beyond `maxFiles` are removed.
- If `maxFiles` is `0`, the old active file is discarded instead of retained as `path.1`.

## Custom Loggers

Any value with a compatible `log(entry: LogEntry): void` method can be installed via `setLogger(...)`.

```doof
import { LogEntry, Logger, setLogger } from "std/log"

class MemoryLogger implements Logger {
  entries: LogEntry[] = []

  log(entry: LogEntry): void {
    this.entries.push(entry)
  }
}

logger := MemoryLogger {}
setLogger(logger)
```

Installing a new logger replaces the previous global sink.

## Logging Functions

### `debug(message, context = {}, source = @caller): void`

Emit a debug-level log entry.

### `info(message, context = {}, source = @caller): void`

Emit an info-level log entry.

### `warn(message, context = {}, source = @caller): void`

Emit a warning-level log entry.

### `error(message, context = {}, source = @caller): void`

Emit an error-level log entry.

### `fatal(message, context = {}, source = @caller): void`

Emit a fatal-level log entry and then call `panic(message)`.

## Types

### `LogLevel`

The built-in severity enum:

- `Debug`
- `Info`
- `Warn`
- `Error`
- `Fatal`

### `LogValue`

Structured context values may be any of:

- `bool`
- `int`
- `long`
- `float`
- `double`
- `string`
- `null`

### `LogEntry`

Each emitted entry contains:

| Field | Type | Description |
|-------|------|-------------|
| `level` | `LogLevel` | Entry severity |
| `message` | `string` | Human-readable message |
| `context` | `Map<string, LogValue>` | Structured key/value metadata |
| `source` | `SourceLocation` | Call-site file, line, and function |
| `timestamp` | `Instant` | UTC creation time |

## Notes

- The logger methods apply their own level filtering. Messages below the configured logger level are ignored.
- String context values are quoted in the rendered output when needed for readability.
- The rolling file logger keeps its file handle open between writes and rotates in place, so the steady-state write path avoids reopening the file for each entry.