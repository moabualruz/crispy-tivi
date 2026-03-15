namespace Crispy.Domain.Enums;

/// <summary>
/// Lifecycle state of an offline download task.
/// </summary>
public enum DownloadStatus
{
    /// <summary>Download is queued but not yet started.</summary>
    Queued = 0,

    /// <summary>Download is actively transferring.</summary>
    Downloading = 1,

    /// <summary>Download finished successfully.</summary>
    Completed = 2,

    /// <summary>Download failed and will not retry automatically.</summary>
    Failed = 3,

    /// <summary>Download was paused by the user.</summary>
    Paused = 4,
}
