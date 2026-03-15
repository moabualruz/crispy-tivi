using Microsoft.Extensions.Logging;

using Serilog;

namespace Crispy.Infrastructure.Logging;

/// <summary>
/// Configures Serilog logging with file and console sinks.
/// </summary>
public static class SerilogConfiguration
{
    /// <summary>
    /// Configures Serilog and registers it with the logging builder.
    /// </summary>
    public static ILoggingBuilder AddSerilogLogging(this ILoggingBuilder builder, string logDirectory = "logs")
    {
        var logger = new LoggerConfiguration()
            .MinimumLevel.Warning()
            .WriteTo.Console()
            .WriteTo.File(
                Path.Combine(logDirectory, "crispy-.log"),
                rollingInterval: RollingInterval.Day,
                fileSizeLimitBytes: 10 * 1024 * 1024,
                retainedFileCountLimit: 7)
            .CreateLogger();

        builder.ClearProviders();
        builder.AddSerilog(logger, dispose: true);

        return builder;
    }
}
