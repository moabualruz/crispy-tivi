namespace Crispy.Domain.Enums;

/// <summary>
/// Supported content source types.
/// </summary>
public enum SourceType
{
    /// <summary>
    /// Standard M3U/M3U8 playlist file.
    /// </summary>
    M3U,

    /// <summary>
    /// Xtream Codes compatible API.
    /// </summary>
    XtreamCodes,

    /// <summary>
    /// Stalker Portal (Ministra/MAG) middleware.
    /// </summary>
    StalkerPortal,

    /// <summary>
    /// Jellyfin media server.
    /// </summary>
    Jellyfin,
}
