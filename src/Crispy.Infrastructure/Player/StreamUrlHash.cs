using System.Security.Cryptography;
using System.Text;

namespace Crispy.Infrastructure.Player;

/// <summary>
/// Shared utility for computing a stream URL hash used as the key in StreamHealthRepository.
/// Hash = first 8 bytes of SHA-256(url) in lowercase hex (16 hex characters).
/// </summary>
public static class StreamUrlHash
{
    /// <summary>
    /// Computes the URL hash for a stream endpoint.
    /// </summary>
    public static string Compute(string url)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(url));
        return Convert.ToHexString(bytes[..8]).ToLowerInvariant();
    }
}
