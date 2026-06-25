# std/log Guide

`std/log` is a small global structured logging facade. Install a logger with
`setLogger` before emitting logs. Without a configured logger, `debug`, `info`,
`warn`, and `error` are no-ops; `fatal` still panics after attempting to log.

## Entries And Context

Each `LogEntry` contains severity, message, structured context, source location,
and timestamp. Context values are intentionally scalar:

```doof
bool | int | long | float | double | string | null
```

Use context for fields you want machines to parse, and the message for the human
summary.

## Built-In Loggers

`ConsoleLogger(level)` writes formatted lines to stderr and colorizes warnings
and errors when stderr is a TTY.

`RollingFileLogger(path, level, maxBytes, maxAge, maxFiles)` writes to a file and
rotates when size or age thresholds are exceeded. Call `flush()` before
important process boundaries when buffered output must be durable.

## Custom Loggers

Implement `Logger.log(entry)` to route logs to tests, memory buffers, external
systems, or application-specific sinks. Installing a new logger replaces the
previous global logger.

## API Map

Types:

- `LogLevel`
- `LogValue`
- `LogEntry`
- `Logger`

Logger setup:

- `setLogger`
- `ConsoleLogger`
- `RollingFileLogger`

Emitters:

- `debug`
- `info`
- `warn`
- `error`
- `fatal`

Declarations are defined in [index.do](../index.do).
