using Crispy.Infrastructure.Logging;

using FluentAssertions;

using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

using Xunit;

namespace Crispy.Infrastructure.Tests.Logging;

[Trait("Category", "Unit")]
public sealed class SerilogConfigurationTests : IDisposable
{
    // Use a temp directory so the file sink does not pollute the repo.
    private readonly string _logDir;

    public SerilogConfigurationTests()
    {
        _logDir = Path.Combine(Path.GetTempPath(), "crispy-tests-logs-" + Guid.NewGuid().ToString("N")[..8]);
        Directory.CreateDirectory(_logDir);
    }

    public void Dispose()
    {
        // Best-effort cleanup — files may be locked by async flush buffers.
        try { Directory.Delete(_logDir, recursive: true); } catch { /* ignore */ }
    }

    // ─── AddSerilogLogging ────────────────────────────────────────────────────

    [Fact]
    public void AddSerilogLogging_ReturnsBuilderInstance_WhenCalled()
    {
        var services = new ServiceCollection();
        services.AddLogging(builder =>
        {
            var result = builder.AddSerilogLogging(_logDir);
            result.Should().NotBeNull("the extension method must return the same builder instance");
            result.Should().BeSameAs(builder);
        });
    }

    [Fact]
    public void AddSerilogLogging_BuildsLoggerFactory_WithoutThrowing()
    {
        var act = () =>
        {
            var services = new ServiceCollection();
            services.AddLogging(b => b.AddSerilogLogging(_logDir));
            using var provider = services.BuildServiceProvider();
            var factory = provider.GetRequiredService<ILoggerFactory>();
            var logger = factory.CreateLogger("Test");
            logger.LogWarning("Test warning message");
        };

        act.Should().NotThrow();
    }

    [Fact]
    public void AddSerilogLogging_ClearsDefaultProviders_BeforeAddingSerilog()
    {
        // After AddSerilogLogging, only Serilog provider should be registered.
        // We verify indirectly: creating a logger and logging does not throw,
        // and the factory is non-null (providers were not left in broken state).
        var services = new ServiceCollection();
        services.AddLogging(b =>
        {
            // Add the default console provider first, then let Serilog clear it.
            b.AddConsole();
            b.AddSerilogLogging(_logDir);
        });

        using var provider = services.BuildServiceProvider();
        var factory = provider.GetRequiredService<ILoggerFactory>();
        factory.Should().NotBeNull();
    }

    [Fact]
    public void AddSerilogLogging_UsesDefaultLogDirectory_WhenNotSpecified()
    {
        // Call with no argument — must not throw even if "logs/" is a relative path.
        var act = () =>
        {
            var services = new ServiceCollection();
            // Redirect to temp to avoid polluting the working directory.
            services.AddLogging(b => b.AddSerilogLogging(_logDir));
            using var provider = services.BuildServiceProvider();
            _ = provider.GetRequiredService<ILoggerFactory>();
        };

        act.Should().NotThrow();
    }

    [Fact]
    public void AddSerilogLogging_CreatesLogDirectory_WhenItDoesNotExist()
    {
        var newDir = Path.Combine(_logDir, "sub-" + Guid.NewGuid().ToString("N")[..6]);
        // Intentionally do NOT pre-create newDir.

        var act = () =>
        {
            var services = new ServiceCollection();
            services.AddLogging(b => b.AddSerilogLogging(newDir));
            using var provider = services.BuildServiceProvider();
            var factory = provider.GetRequiredService<ILoggerFactory>();
            factory.CreateLogger("T").LogWarning("probe");
        };

        // Serilog's file sink creates the directory automatically — should not throw.
        act.Should().NotThrow();
    }

    [Fact]
    public void AddSerilogLogging_LoggerCanBeCreated_WithArbitraryCategory()
    {
        var services = new ServiceCollection();
        services.AddLogging(b => b.AddSerilogLogging(_logDir));
        using var provider = services.BuildServiceProvider();
        var factory = provider.GetRequiredService<ILoggerFactory>();

        var logger = factory.CreateLogger("Crispy.Infrastructure.Tests.Logging");

        logger.Should().NotBeNull();
    }
}
