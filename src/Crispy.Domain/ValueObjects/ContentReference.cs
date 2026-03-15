using Crispy.Domain.Enums;

namespace Crispy.Domain.ValueObjects;

/// <summary>
/// Polymorphic content reference — identifies any playable item by type and primary key.
/// Used in WatchHistory, Downloads, and EPG reminders to avoid separate FK columns per type.
/// </summary>
public readonly record struct ContentReference(ContentType ContentType, int ContentId);
