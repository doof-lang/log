import { Assert } from "std/assert"
import { remove } from "std/fs"
import { pid } from "std/os"
import { join, tempDirectory } from "std/path"
import { Duration, Instant } from "std/time"

import { ConsoleLogger, LogEntry, LogLevel, Logger, RollingFileLogger, info, setLogger } from "../index"

class CapturingLogger implements Logger {
  let last: LogEntry | none = none
  log(entry: LogEntry): none { last = entry }
}

function callerSource(source: SourceLocation = @caller): SourceLocation => source

function flushFile(path: string): none {
  logger := RollingFileLogger(path)
  logger.flush()
}

export function testLogLevelOrdering(): none {
  Assert.isTrue(LogLevel.Debug < LogLevel.Info)
  Assert.isTrue(LogLevel.Warn > LogLevel.Info)
  Assert.isTrue(LogLevel.Fatal > LogLevel.Error)
}

export function testLogEntryStoresTypedFields(): none {
  entry := LogEntry {
    level: LogLevel.Info,
    message: "Server started",
    context: { "port": 8080, "host": "127.0.0.1", "secure": none },
    source: callerSource(),
    timestamp: Instant.now(),
  }

  Assert.equal(entry.level, LogLevel.Info)
  Assert.equal(entry.message, "Server started")
  Assert.isTrue(entry.context.has("port"))
  Assert.stringContains(entry.source.fileName, "log.test")
  Assert.isTrue(entry.source.line > 0)
}

export function testConsoleLoggerDefaults(): none {
  logger := ConsoleLogger()

  Assert.equal(logger.level, LogLevel.Info)
}

export function testRollingFileLoggerDefaults(): none {
  logger := RollingFileLogger("app.log")

  Assert.equal(logger.path, "app.log")
  Assert.equal(logger.level, LogLevel.Info)
  Assert.isTrue(logger.maxBytes == none)
  Assert.isTrue(logger.maxAge == none)
  Assert.equal(logger.maxFiles, 5)
}

export function testRollingFileLoggerKeepsConfiguredThresholds(): none {
  logger := RollingFileLogger("app.log", LogLevel.Debug, 1024L, Duration.ofMinutes(5L), 3)
  maxBytes := logger.maxBytes as long else {
    Assert.fail("expected maxBytes to be set")
    return
  }
  maxAge := logger.maxAge as Duration else {
    Assert.fail("expected maxAge to be set")
    return
  }

  Assert.equal(logger.level, LogLevel.Debug)
  Assert.equal(maxBytes, 1024L)
  Assert.equal(maxAge.toMinutes(), 5.0)
  Assert.equal(logger.maxFiles, 3)
}

export function testRollingFileLoggerSupportsManualFlush(): none {
  path := join([tempDirectory(), "std-log-manual-flush-${pid()}.log"])

  flushFile(path)
  remove(path)!
}

export function testImportedLoggersSatisfyLoggerInterface(): none {
  let consoleLogger: Logger = ConsoleLogger()
  let rollingLogger: Logger = RollingFileLogger("app.log")

  Assert.isTrue(true)
}

export function testApplicationLoggerStillReceivesDispatchedEntries(): none {
  logger := CapturingLogger {}
  setLogger(logger)
  info("additive observer tap", { "request": 7 })
  entry := logger.last as LogEntry else {
    Assert.fail("expected the application logger to receive the entry")
    return
  }
  Assert.equal(entry.message, "additive observer tap")
  value := entry.context.get("request")!
  case value {
    count: int -> { Assert.equal(count, 7) }
    _ -> { Assert.fail("expected integer log context") }
  }
}
