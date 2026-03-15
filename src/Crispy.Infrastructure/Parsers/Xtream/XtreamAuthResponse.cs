using System.Text.Json.Serialization;

namespace Crispy.Infrastructure.Parsers.Xtream;

/// <summary>
/// Full authentication response from the Xtream Codes API.
/// </summary>
public sealed class XtreamAuthResponse
{
    [JsonPropertyName("user_info")]
    public XtreamUserInfo? UserInfo { get; init; }

    [JsonPropertyName("server_info")]
    public XtreamServerInfo? ServerInfo { get; init; }
}

/// <summary>
/// User/subscription information from the Xtream Codes authentication response.
/// </summary>
public sealed class XtreamUserInfo
{
    [JsonPropertyName("username")]
    public string? Username { get; init; }

    [JsonPropertyName("password")]
    public string? Password { get; init; }

    [JsonPropertyName("status")]
    public string? Status { get; init; }

    /// <summary>Subscription expiry as a Unix timestamp string (may be null for lifetime subs).</summary>
    [JsonPropertyName("exp_date")]
    public string? ExpDateRaw { get; init; }

    [JsonPropertyName("max_connections")]
    public string? MaxConnections { get; init; }

    [JsonPropertyName("active_cons")]
    public string? ActiveConnections { get; init; }

    /// <summary>Parsed subscription expiry. Null for lifetime subscriptions.</summary>
    [JsonIgnore]
    public DateTimeOffset? ExpDate => long.TryParse(ExpDateRaw, out var unix)
        ? DateTimeOffset.FromUnixTimeSeconds(unix)
        : null;

    /// <summary>Days remaining until expiry. Null for lifetime subscriptions.</summary>
    [JsonIgnore]
    public int? DaysUntilExpiry => ExpDate.HasValue
        ? (int)Math.Ceiling((ExpDate.Value - DateTimeOffset.UtcNow).TotalDays)
        : null;
}

/// <summary>
/// Server information from the Xtream Codes authentication response.
/// </summary>
public sealed class XtreamServerInfo
{
    [JsonPropertyName("url")]
    public string? Url { get; init; }

    [JsonPropertyName("port")]
    public string? Port { get; init; }

    [JsonPropertyName("https_port")]
    public string? HttpsPort { get; init; }

    [JsonPropertyName("server_protocol")]
    public string? Protocol { get; init; }

    [JsonPropertyName("timezone")]
    public string? Timezone { get; init; }
}
