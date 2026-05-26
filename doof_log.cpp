#include "index.hpp"

#include <chrono>
#include <cstdio>
#include <filesystem>
#include <fstream>
#include <mutex>
#include <optional>
#include <sstream>
#include <string>
#include <system_error>

#if defined(_WIN32)
#include <io.h>
#else
#include <unistd.h>
#endif

namespace doof_log {

namespace {

namespace fs = std::filesystem;

std::mutex& sink_mutex() {
    static std::mutex mutex;
    return mutex;
}

std::mutex& console_mutex() {
    static std::mutex mutex;
    return mutex;
}

LogSink& active_sink() {
    static LogSink sink;
    return sink;
}

int level_rank(LogLevel level) {
    return static_cast<int>(level);
}

const char* level_label(LogLevel level) {
    switch (level) {
        case LogLevel::Debug: return "DEBUG";
        case LogLevel::Info: return "INFO ";
        case LogLevel::Warn: return "WARN ";
        case LogLevel::Error: return "ERROR";
        case LogLevel::Fatal: return "FATAL";
    }

    return "UNKWN";
}

bool stderr_is_tty() {
#if defined(_WIN32)
    return ::_isatty(::_fileno(stderr)) != 0;
#else
    return ::isatty(STDERR_FILENO) != 0;
#endif
}

std::string maybe_quote_string(const std::string& value) {
    bool needsQuotes = value.empty();
    for (char ch : value) {
        if (ch == ' ' || ch == '\t' || ch == '=' || ch == '"') {
            needsQuotes = true;
            break;
        }
    }

    if (!needsQuotes) {
        return value;
    }

    std::string out;
    out.reserve(value.size() + 2);
    out.push_back('"');
    for (char ch : value) {
        if (ch == '\\' || ch == '"') {
            out.push_back('\\');
        }
        out.push_back(ch);
    }
    out.push_back('"');
    return out;
}

std::string format_log_value(const LogValue& value) {
    return std::visit([](const auto& current) -> std::string {
        using Current = std::decay_t<decltype(current)>;

        if constexpr (std::is_same_v<Current, std::monostate>) {
            return "null";
        } else if constexpr (std::is_same_v<Current, bool>) {
            return current ? "true" : "false";
        } else if constexpr (std::is_same_v<Current, std::string>) {
            return maybe_quote_string(current);
        } else {
            return doof::to_string(current);
        }
    }, value);
}

std::string format_level(LogLevel level, bool colorize) {
    std::string text = std::string("[") + level_label(level) + "]";
    if (!colorize) {
        return text;
    }

    switch (level) {
        case LogLevel::Debug:
            return "\x1b[90m" + text + "\x1b[0m";
        case LogLevel::Info:
            return text;
        case LogLevel::Warn:
            return "\x1b[33m" + text + "\x1b[0m";
        case LogLevel::Error:
            return "\x1b[31m" + text + "\x1b[0m";
        case LogLevel::Fatal:
            return "\x1b[1;31m" + text + "\x1b[0m";
    }

    return text;
}

std::string format_entry_line(std::shared_ptr<LogEntry> entry, bool colorize) {
    std::ostringstream out;
    out << entry->timestamp->toISOString();
    out << ' ' << format_level(entry->level, colorize);
    out << ' ' << entry->message;

    for (const auto& [key, value] : *entry->context) {
        out << ' ' << key << '=' << format_log_value(value);
    }

    out << " source=" << entry->source->fileName << ':' << entry->source->line;
    return out.str();
}

int64_t file_size_bytes(const std::string& path) {
    std::error_code error;
    const auto size = fs::file_size(path, error);
    if (error) {
        return 0;
    }

    return static_cast<int64_t>(size);
}

int64_t file_last_write_epoch_nanos(const std::string& path, int64_t fallback) {
    std::error_code error;
    const auto lastWrite = fs::last_write_time(path, error);
    if (error) {
        return fallback;
    }

    const auto fileNow = fs::file_time_type::clock::now();
    const auto systemNow = std::chrono::system_clock::now();
    const auto systemTime = std::chrono::time_point_cast<std::chrono::system_clock::duration>(lastWrite - fileNow + systemNow);
    return std::chrono::duration_cast<std::chrono::nanoseconds>(systemTime.time_since_epoch()).count();
}

void remove_if_exists(const std::string& path) {
    std::error_code error;
    fs::remove(path, error);
}

void rename_if_exists(const std::string& from, const std::string& to) {
    std::error_code existsError;
    if (!fs::exists(from, existsError) || existsError) {
        return;
    }

    std::error_code removeError;
    fs::remove(to, removeError);

    std::error_code renameError;
    fs::rename(from, to, renameError);
    if (renameError) {
        doof::panic("Failed to roll log file: " + from + " -> " + to);
    }
}

void rotate_files(const RollingFileLogger& logger) {
    const int32_t keepCount = logger.maxFiles < 0 ? 0 : logger.maxFiles;
    if (keepCount == 0) {
        remove_if_exists(logger.path);
        return;
    }

    remove_if_exists(logger.path + "." + std::to_string(static_cast<int64_t>(keepCount)));
    for (int32_t index = keepCount - 1; index >= 1; --index) {
        rename_if_exists(
            logger.path + "." + std::to_string(static_cast<int64_t>(index)),
            logger.path + "." + std::to_string(static_cast<int64_t>(index + 1))
        );
    }

    rename_if_exists(logger.path, logger.path + ".1");
}

}  // namespace

void setSink(LogSink sink) {
    std::lock_guard<std::mutex> lock(sink_mutex());
    active_sink() = std::move(sink);
}

void dispatch(std::shared_ptr<LogEntry> entry) {
    LogSink sink;
    {
        std::lock_guard<std::mutex> lock(sink_mutex());
        sink = active_sink();
    }

    if (!sink) {
        return;
    }

    sink.call(std::move(entry));
}

void ConsoleLogger::log(std::shared_ptr<LogEntry> entry) {
    if (level_rank(entry->level) < level_rank(level)) {
        return;
    }

    const std::string line = format_entry_line(entry, stderr_is_tty());
    std::lock_guard<std::mutex> lock(console_mutex());
    std::fputs((line + "\n").c_str(), stderr);
    std::fflush(stderr);
}

void RollingFileLogger::initializeIfNeeded(int64_t now) {
    if (initialized_) {
        return;
    }

    lastRollEpochNanos_ = fs::exists(path)
        ? file_last_write_epoch_nanos(path, now)
        : now;
    currentSizeBytes_ = file_size_bytes(path);
    openStream();
    initialized_ = true;
}

void RollingFileLogger::openStream() {
    if (stream_.is_open()) {
        return;
    }

    stream_.open(path, std::ios::app | std::ios::binary);
    if (!stream_.is_open()) {
        doof::panic("Failed to open log file: " + path);
    }
}

void RollingFileLogger::resetStream() {
    if (!stream_.is_open()) {
        return;
    }

    stream_.close();
    stream_.clear();
}

void RollingFileLogger::appendLine(const std::string& line) {
    openStream();

    stream_ << line << '\n';
    if (!stream_) {
        doof::panic("Failed to write log file: " + path);
    }

    currentSizeBytes_ += static_cast<int64_t>(line.size()) + 1;
}

void RollingFileLogger::flushStream() {
    openStream();

    stream_.flush();
    if (!stream_) {
        doof::panic("Failed to flush log file: " + path);
    }
}

void RollingFileLogger::flush() {
    const int64_t now = std::chrono::duration_cast<std::chrono::nanoseconds>(
        std::chrono::system_clock::now().time_since_epoch()
    ).count();

    std::lock_guard<std::mutex> lock(mutex_);
    initializeIfNeeded(now);
    flushStream();
}

void RollingFileLogger::log(std::shared_ptr<LogEntry> entry) {
    if (level_rank(entry->level) < level_rank(level)) {
        return;
    }

    const std::string line = format_entry_line(entry, false);
    const int64_t now = entry->timestamp->toEpochNanos();

    std::lock_guard<std::mutex> lock(mutex_);
    initializeIfNeeded(now);

    bool shouldRoll = false;
    if (maxAge != nullptr) {
        shouldRoll = now - lastRollEpochNanos_ >= maxAge->toNanos();
    }
    if (!shouldRoll && maxBytes.has_value()) {
        shouldRoll = currentSizeBytes_ + static_cast<int64_t>(line.size()) + 1 > maxBytes.value();
    }

    if (shouldRoll) {
        resetStream();
        rotate_files(*this);
        lastRollEpochNanos_ = now;
        currentSizeBytes_ = 0;
    }

    appendLine(line);
    if (entry->level == LogLevel::Fatal) {
        flushStream();
    }
}

}  // namespace doof_log