using Crispy.Domain.Entities;

namespace Crispy.Application.Sources;

/// <summary>
/// Common parsing contract for all source types (M3U, Xtream Codes, Stalker Portal).
/// Implementations are registered by <see cref="Source.SourceType"/> via a factory.
/// </summary>
public interface ISourceParser
{
    /// <summary>Parses content from the given source and returns a structured result.</summary>
    Task<ParseResult> ParseAsync(Source source, CancellationToken ct = default);
}
