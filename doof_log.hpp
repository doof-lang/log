#pragma once

#include "doof_runtime.hpp"

#include <cstdint>
#include <fstream>
#include <functional>
#include <memory>
#include <mutex>
#include <optional>
#include <string>

enum class LogLevel;
struct Duration;
struct LogEntry;

namespace doof_log {

class ConsoleLogger {
public:
	LogLevel level;

	explicit ConsoleLogger(LogLevel level = static_cast<LogLevel>(1))
		: level(level) {}

	static std::shared_ptr<ConsoleLogger> create(LogLevel level = static_cast<LogLevel>(1)) {
		return std::make_shared<ConsoleLogger>(level);
	}

	void log(std::shared_ptr<LogEntry> entry);
};

class RollingFileLogger {
public:
	std::string path;
	LogLevel level;
	std::optional<int64_t> maxBytes;
	std::shared_ptr<Duration> maxAge;
	int32_t maxFiles;

	explicit RollingFileLogger(
		std::string path,
		LogLevel level = static_cast<LogLevel>(1),
		std::optional<int64_t> maxBytes = std::nullopt,
		std::shared_ptr<Duration> maxAge = nullptr,
		int32_t maxFiles = 5
	)
		: path(std::move(path)), level(level), maxBytes(std::move(maxBytes)), maxAge(std::move(maxAge)), maxFiles(maxFiles) {}

	static std::shared_ptr<RollingFileLogger> create(
		std::string path,
		LogLevel level = static_cast<LogLevel>(1),
		std::optional<int64_t> maxBytes = std::nullopt,
		std::shared_ptr<Duration> maxAge = nullptr,
		int32_t maxFiles = 5
	) {
		return std::make_shared<RollingFileLogger>(std::move(path), level, std::move(maxBytes), std::move(maxAge), maxFiles);
	}

	void log(std::shared_ptr<LogEntry> entry);
	void flush();

private:
	void initializeIfNeeded(int64_t now);
	void openStream();
	void resetStream();
	void appendLine(const std::string& line);
	void flushStream();

	std::mutex mutex_;
	int64_t lastRollEpochNanos_ = 0;
	int64_t currentSizeBytes_ = 0;
	bool initialized_ = false;
	std::ofstream stream_;
};

using LogSink = std::function<void(std::shared_ptr<LogEntry>)>;

void setSink(LogSink sink);
void dispatch(std::shared_ptr<LogEntry> entry);

}  // namespace doof_log

using ConsoleLogger = doof_log::ConsoleLogger;
using RollingFileLogger = doof_log::RollingFileLogger;