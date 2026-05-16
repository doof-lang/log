import { Duration, Instant } from "std/time"

export enum LogLevel {
  Debug = 0,
  Info = 1,
  Warn = 2,
  Error = 3,
  Fatal = 4,
}

export type LogValue = bool | int | long | float | double | string | null

export class LogEntry {
  readonly level: LogLevel
  readonly message: string
  readonly context: Map<string, LogValue>
  readonly source: SourceLocation
  readonly timestamp: Instant
}

export interface Logger {
  log(entry: LogEntry): void
}

import function _setSink(sink: (entry: LogEntry): void): void from "doof_log.hpp" as doof_log::setSink
import function _dispatch(entry: LogEntry): void from "doof_log.hpp" as doof_log::dispatch

export function setLogger(logger: Logger): void {
  _setSink((entry: LogEntry): void => logger.log(entry))
}

export import class ConsoleLogger from "doof_log.hpp" as doof_log::ConsoleLogger {
  static create(level: LogLevel = .Info): ConsoleLogger
  level: LogLevel
  log(entry: LogEntry): void
}

export import class RollingFileLogger from "doof_log.hpp" as doof_log::RollingFileLogger {
  static create(
    path: string,
    level: LogLevel = .Info,
    maxBytes: long | null = null,
    maxAge: Duration | null = null,
    maxFiles: int = 5,
  ): RollingFileLogger
  path: string
  level: LogLevel
  maxBytes: long | null
  maxAge: Duration | null
  maxFiles: int
  log(entry: LogEntry): void
  flush(): void
}

function _log(level: LogLevel, message: string, context: readonly Map<string, LogValue>, source: SourceLocation): void {
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
): void {
  _log(.Debug, message, context, source)
}

export function info(
  message: string,
  context: readonly Map<string, LogValue> = {},
  source: SourceLocation = @caller,
): void {
  _log(.Info, message, context, source)
}

export function warn(
  message: string,
  context: readonly Map<string, LogValue> = {},
  source: SourceLocation = @caller,
): void {
  _log(.Warn, message, context, source)
}

export function error(
  message: string,
  context: readonly Map<string, LogValue> = {},
  source: SourceLocation = @caller,
): void {
  _log(.Error, message, context, source)
}

export function fatal(
  message: string,
  context: readonly Map<string, LogValue> = {},
  source: SourceLocation = @caller,
): void {
  _log(.Fatal, message, context, source)
  panic(message)
}