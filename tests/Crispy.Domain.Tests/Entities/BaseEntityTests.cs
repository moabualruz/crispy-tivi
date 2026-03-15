using Crispy.Domain.Entities;

using FluentAssertions;

using Xunit;

namespace Crispy.Domain.Tests.Entities;

public class BaseEntityTests
{
    private sealed class TestEntity : BaseEntity;

    [Fact]
    public void Id_ShouldDefaultToZero()
    {
        var entity = new TestEntity();

        entity.Id.Should().Be(0);
    }

    [Fact]
    public void DeletedAt_ShouldDefaultToNull()
    {
        var entity = new TestEntity();

        entity.DeletedAt.Should().BeNull();
    }
}
