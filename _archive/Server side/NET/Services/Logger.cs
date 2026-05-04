using System;
using System.IO;
using System.Text.Json;

namespace Services
{
    public class Logger
    {
        private readonly string _filePath;

        public Logger(string filePath)
        {
            _filePath = filePath;
        }

        private void Log(string level, string message, object? extra = null)
        {
            var entry = new
            {
                Timestamp = DateTime.UtcNow.ToString("O"),
                Level = level,
                Message = message,
                Extra = extra
            };
            lock (_filePath)
            {
                File.AppendAllText(_filePath, JsonSerializer.Serialize(entry) + Environment.NewLine);
            }
        }

        public void LogInfo(string message, object? extra = null)
        {
            Log("INFO", message, extra);
        }
        public void LogError(string message, Exception? ex = null)
        {
            Log("ERROR", message, ex != null ? new { Exception = ex.ToString() } : null);
        }
    }
}