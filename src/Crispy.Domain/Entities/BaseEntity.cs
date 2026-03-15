namespace Crispy.Domain.Entities;

/// <summary>
/// Base entity with common audit fields for all database entities.
/// </summary>
public abstract class BaseEntity
{
    /// <summary>
    /// Primary key, auto-incremented by the database.
    /// </summary>
    public int Id { get; set; }

    /// <summary>
    /// UTC timestamp when the entity was created.
    /// </summary>
    public DateTime CreatedAt { get; set; }

    /// <summary>
    /// UTC timestamp when the entity was last updated.
    /// </summary>
    public DateTime UpdatedAt { get; set; }

    /// <summary>
    /// UTC timestamp when the entity was soft-deleted, or null if active.
    /// </summary>
    public DateTime? DeletedAt { get; set; }
}
