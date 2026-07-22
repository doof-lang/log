import { Assert } from "std/assert"
import { Duration, Instant } from "std/time"

import { ConsoleLogger, LogEntry, LogLevel, Logger, RollingFileLogger } from "../index"

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
    source: SourceLocation("main", 12, "main"),
    timestamp: Instant.now(),
  }

  Assert.equal(entry.level, LogLevel.Info)
  Assert.equal(entry.message, "Server started")
  Assert.isTrue(entry.context.has("port"))
  Assert.equal(entry.source.fileName, "main")
  Assert.equal(entry.source.line, 12)
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
  logger := RollingFileLogger("app.log")

  logger.flush()
  Assert.isTrue(true)
}

export function testImportedLoggersSatisfyLoggerInterface(): none {
  let consoleLogger: Logger = ConsoleLogger()
  let rollingLogger: Logger = RollingFileLogger("app.log")

  Assert.isTrue(true)
}
