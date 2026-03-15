using Crispy.Domain.Enums;

namespace Crispy.Domain.Entities;

/// <summary>
/// Tracks an offline download task for any content type.
/// </summary>
public class Download : BaseEntity
{
    /// <summary>Type of the content being downloaded.</summary>
    public ContentType ContentType { get; set; }

    /// <summary>Primary key of the content item.</summary>
    public required int ContentId { get; set; }

    /// <summary>Current lifecycle status of the download.</summary>
    public DownloadStatus Status { get; set; } = DownloadStatus.Queued;

    /// <summary>Download progress from 0.0 (not started) to 1.0 (complete).</summary>
    public double Progress { get; set; }

    /// <summary>Absolute path to the downloaded file on the local filesystem.</summary>
    public string? FilePath { get; set; }

    /// <summary>Quality label selected for download (e.g. "1080p", "720p").</summary>
    public string? Quality { get; set; }

    /// <summary>Total file size in bytes (0 until the download begins and size is known).</summary>
    public long SizeBytes { get; set; }
}
