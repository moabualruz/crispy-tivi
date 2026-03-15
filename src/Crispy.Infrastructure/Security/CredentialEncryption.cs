using System.Runtime.InteropServices;
using System.Runtime.Versioning;
using System.Security.Cryptography;
using System.Text;

namespace Crispy.Infrastructure.Security;

/// <summary>
/// AES-256-GCM credential encryption with a platform-protected key file.
/// Key protection strategy:
///   Windows  — Key stored in %APPDATA%\CrispyTivi\credential.key (protected by
///               Windows user-profile ACLs; DPAPI wrapping added in a future hardening pass).
///   Unix/Mac — Key stored in ~/.crispy/machine.key (chmod 600 on creation).
/// Encrypted blob format: base64( nonce[12] || tag[16] || ciphertext[N] )
/// </summary>
public sealed class CredentialEncryption : ICredentialEncryption
{
    private const int KeyBytes = 32;   // AES-256
    private const int NonceBytes = 12; // GCM standard nonce
    private const int TagBytes = 16;   // GCM authentication tag

    private readonly Lazy<byte[]> _key;

    /// <summary>
    /// Initialises the encryption service. Key is loaded lazily on first use.
    /// </summary>
    public CredentialEncryption()
    {
        _key = new Lazy<byte[]>(LoadOrCreateKey, LazyThreadSafetyMode.ExecutionAndPublication);
    }

    /// <inheritdoc />
    public string Encrypt(string plaintext)
    {
        ArgumentNullException.ThrowIfNull(plaintext);

        var plaintextBytes = Encoding.UTF8.GetBytes(plaintext);
        var nonce = new byte[NonceBytes];
        RandomNumberGenerator.Fill(nonce);

        var ciphertext = new byte[plaintextBytes.Length];
        var tag = new byte[TagBytes];

        using var aes = new AesGcm(_key.Value, TagBytes);
        aes.Encrypt(nonce, plaintextBytes, ciphertext, tag);

        // blob = nonce || tag || ciphertext
        var blob = new byte[NonceBytes + TagBytes + ciphertext.Length];
        nonce.CopyTo(blob, 0);
        tag.CopyTo(blob, NonceBytes);
        ciphertext.CopyTo(blob, NonceBytes + TagBytes);

        return Convert.ToBase64String(blob);
    }

    /// <inheritdoc />
    public string Decrypt(string ciphertext)
    {
        ArgumentNullException.ThrowIfNull(ciphertext);

        var blob = Convert.FromBase64String(ciphertext);

        var nonce = blob[..NonceBytes];
        var tag = blob[NonceBytes..(NonceBytes + TagBytes)];
        var encryptedData = blob[(NonceBytes + TagBytes)..];

        var plaintext = new byte[encryptedData.Length];

        using var aes = new AesGcm(_key.Value, TagBytes);
        aes.Decrypt(nonce, encryptedData, tag, plaintext);

        return Encoding.UTF8.GetString(plaintext);
    }

    // -------------------------------------------------------------------------
    // Key management
    // -------------------------------------------------------------------------

    private static byte[] LoadOrCreateKey()
    {
        var keyFilePath = GetKeyFilePath();
        var dir = Path.GetDirectoryName(keyFilePath)!;

        if (File.Exists(keyFilePath))
            return File.ReadAllBytes(keyFilePath);

        var key = GenerateRandomKey();
        Directory.CreateDirectory(dir);
        File.WriteAllBytes(keyFilePath, key);

        // On Unix: restrict to owner only (chmod 600)
        if (!RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
        {
            SetPosixFilePermissions(keyFilePath);
        }

        return key;
    }

    private static byte[] GenerateRandomKey()
    {
        var key = new byte[KeyBytes];
        RandomNumberGenerator.Fill(key);
        return key;
    }

    private static string GetKeyFilePath()
    {
        if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
        {
            return Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
                "CrispyTivi",
                "credential.key");
        }

        return Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
            ".crispy",
            "machine.key");
    }

    [UnsupportedOSPlatform("windows")]
    private static void SetPosixFilePermissions(string path)
    {
        try
        {
            // UnixFileMode is supported on net6+ on non-Windows
            File.SetUnixFileMode(path, UnixFileMode.UserRead | UnixFileMode.UserWrite);
        }
        catch (Exception)
        {
            // Best-effort — leave as-is if the platform doesn't support it.
        }
    }
}
