import { Duration, Instant } from "std/time"

export enum LogLevel {
  Debug = 0,
  Info = 1,
  Warn = 2,
  Error = 3,
  Fatal = 4,
}

export type LogValue = bool | int | long | float | double | string | none

export class LogEntry {
  readonly level: LogLevel
  readonly message: string
  readonly context: Map<string, LogValue>
  readonly source: SourceLocation
  readonly timestamp: Instant
}

export interface Logger {
  log(entry: LogEntry): none
}

import function _setSink(sink: (entry: LogEntry): none): none from "doof_log.hpp" as doof_log::setSink
import function _dispatch(entry: LogEntry): none from "doof_log.hpp" as doof_log::dispatch

export function setLogger(logger: Logger): none {
  _setSink((entry: LogEntry): none => logger.log(entry))
}

export import class ConsoleLogger from "doof_log.hpp" as doof_log::ConsoleLogger {
  isolated static constructor(level: LogLevel = .Info): ConsoleLogger
  level: LogLevel
  isolated log(entry: LogEntry): none
}

export import class RollingFileLogger from "doof_log.hpp" as doof_log::RollingFileLogger {
  isolated static constructor(
    path: string,
    level: LogLevel = .Info,
    maxBytes: long | none = none,
    maxAge: Duration | none = none,
    maxFiles: int = 5,
  ): RollingFileLogger
  path: string
  level: LogLevel
  maxBytes: long | none
  maxAge: Duration | none
  maxFiles: int
  isolated log(entry: LogEntry): none
  isolated flush(): none
}

function _log(level: LogLevel, message: string, context: readonly Map<string, LogValue>, source: SourceLocation): none {
  _dispatch(LogEntry {
    level,
    message,
    context,
    source,
    timestamp: Instant.now(),
  })
}

export function debug(
  message: string,
  context: readonly Map<string, LogValue> = {},
  source: SourceLocation = @caller,
): none {
  _log(.Debug, message, context, source)
}

export function info(
  message: string,
  context: readonly Map<string, LogValue> = {},
  source: SourceLocation = @caller,
): none {
  _log(.Info, message, context, source)
}

export function warn(
  message: string,
  context: readonly Map<string, LogValue> = {},
  source: SourceLocation = @caller,
): none {
  _log(.Warn, message, context, source)
}

export function error(
  message: string,
  context: readonly Map<string, LogValue> = {},
  source: SourceLocation = @caller,
): none {
  _log(.Error, message, context, source)
}

export function fatal(
  message: string,
  context: readonly Map<string, LogValue> = {},
  source: SourceLocation = @caller,
): none {
  _log(.Fatal, message, context, source)
  panic(message)
}
