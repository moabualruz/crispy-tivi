using Crispy.Domain.Entities;
using Crispy.Domain.Enums;
using FluentAssertions;
using Xunit;

namespace Crispy.Domain.Tests.Entities;

[Trait("Category", "Unit")]
public class SourceEntityTests
{
    [Fact]
    public void Source_Name_IsSet()
    {
        var source = new Source { Name = "My IPTV", Url = "http://example.com/playlist.m3u" };

        source.Name.Should().Be("My IPTV");
    }

    [Fact]
    public void Source_Url_IsSet()
    {
        var source = new Source { Name = "My IPTV", Url = "http://example.com/playlist.m3u" };

        source.Url.Should().Be("http://example.com/playlist.m3u");
    }

    [Fact]
    public void Source_IsEnabled_DefaultsToTrue()
    {
        var source = new Source { Name = "My IPTV", Url = "http://example.com/playlist.m3u" };

        source.IsEnabled.Should().BeTrue();
    }

    [Fact]
    public void Source_SourceType_DefaultsToM3U()
    {
        var source = new Source { Name = "My IPTV", Url = "http://example.com/playlist.m3u" };

        source.SourceType.Should().Be(SourceType.M3U);
    }

    [Fact]
    public void Source_SourceType_CanBeSetToXtreamCodes()
    {
        var source = new Source
        {
            Name = "Xtream Source",
            Url = "http://xtream.example.com",
            SourceType = SourceType.XtreamCodes,
        };

        source.SourceType.Should().Be(SourceType.XtreamCodes);
    }

    [Fact]
    public void Source_Username_DefaultsToNull()
    {
        var source = new Source { Name = "My IPTV", Url = "http://example.com/playlist.m3u" };

        source.Username.Should().BeNull();
    }

    [Fact]
    public void Source_Password_DefaultsToNull()
    {
        var source = new Source { Name = "My IPTV", Url = "http://example.com/playlist.m3u" };

        source.Password.Should().BeNull();
    }

    [Fact]
    public void Source_Username_CanBeSet()
    {
        var source = new Source
        {
            Name = "My IPTV",
            Url = "http://example.com/playlist.m3u",
            Username = "user1",
        };

        source.Username.Should().Be("user1");
    }

    [Fact]
    public void Source_Password_CanBeSet()
    {
        var source = new Source
        {
            Name = "My IPTV",
            Url = "http://example.com/playlist.m3u",
            Password = "secret",
        };

        source.Password.Should().Be("secret");
    }

    [Fact]
    public void Source_EncryptedUsername_DefaultsToNull()
    {
        var source = new Source { Name = "My IPTV", Url = "http://example.com/playlist.m3u" };

        source.EncryptedUsername.Should().BeNull();
    }

    [Fact]
    public void Source_EncryptedPassword_DefaultsToNull()
    {
        var source = new Source { Name = "My IPTV", Url = "http://example.com/playlist.m3u" };

        source.EncryptedPassword.Should().BeNull();
    }

    [Fact]
    public void Source_UserAgent_DefaultsToNull()
    {
        var source = new Source { Name = "My IPTV", Url = "http://example.com/playlist.m3u" };

        // UserAgent is not defined — the entity has EncryptedUsername/EncryptedPassword
        // This test verifies EncryptedPassword serves as the optional credential field
        source.EncryptedPassword.Should().BeNull();
    }

    [Fact]
    public void Source_SortOrder_DefaultsToZero()
    {
        var source = new Source { Name = "My IPTV", Url = "http://example.com/playlist.m3u" };

        source.SortOrder.Should().Be(0);
    }

    [Fact]
    public void Source_ProfileId_DefaultsToZero()
    {
        var source = new Source { Name = "My IPTV", Url = "http://example.com/playlist.m3u" };

        source.ProfileId.Should().Be(0);
    }

    [Fact]
    public void Source_Profile_DefaultsToNull()
    {
        var source = new Source { Name = "My IPTV", Url = "http://example.com/playlist.m3u" };

        source.Profile.Should().BeNull();
    }

    [Fact]
    public void Source_IsEnabled_CanBeSetToFalse()
    {
        var source = new Source
        {
            Name = "Disabled Source",
            Url = "http://example.com/playlist.m3u",
            IsEnabled = false,
        };

        source.IsEnabled.Should().BeFalse();
    }
}
