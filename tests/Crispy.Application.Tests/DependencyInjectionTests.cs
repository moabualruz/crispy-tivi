using Crispy.Application.Services;
using Crispy.Domain.Interfaces;

using FluentAssertions;

using Microsoft.Extensions.DependencyInjection;

using NSubstitute;

using Xunit;

namespace Crispy.Application.Tests;

[Trait("Category", "Unit")]
public class DependencyInjectionTests
{
    [Fact]
    public void AddApplicationServices_ShouldRegisterISettingsService()
    {
        var services = new ServiceCollection();
        // SettingsService depends on ISettingsRepository — register a mock so resolution works.
        services.AddSingleton(Substitute.For<ISettingsRepository>());

        services.AddApplicationServices();

        var descriptor = services.FirstOrDefault(d => d.ServiceType == typeof(ISettingsService));
        descriptor.Should().NotBeNull();
        descriptor!.Lifetime.Should().Be(ServiceLifetime.Singleton);
    }

    [Fact]
    public void AddApplicationServices_ShouldResolveISettingsService_AsSettingsService()
    {
        var services = new ServiceCollection();
        services.AddSingleton(Substitute.For<ISettingsRepository>());
        services.AddApplicationServices();

        using var provider = services.BuildServiceProvider();
        using var scope = provider.CreateScope();

        var resolved = scope.ServiceProvider.GetRequiredService<ISettingsService>();

        resolved.Should().NotBeNull();
        resolved.Should().BeOfType<SettingsService>();
    }

    [Fact]
    public void AddApplicationServices_ShouldReturnSameServiceCollection()
    {
        var services = new ServiceCollection();

        var returned = services.AddApplicationServices();

        returned.Should().BeSameAs(services);
    }
}
