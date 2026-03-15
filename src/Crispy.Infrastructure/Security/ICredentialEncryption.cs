namespace Crispy.Infrastructure.Security;

/// <summary>
/// Encrypts and decrypts credential strings using AES-256-GCM with a platform-protected key.
/// </summary>
public interface ICredentialEncryption
{
    /// <summary>
    /// Encrypts <paramref name="plaintext"/> and returns a base64-encoded ciphertext blob.
    /// Each call produces a different output due to random nonce generation.
    /// </summary>
    string Encrypt(string plaintext);

    /// <summary>
    /// Decrypts a blob previously produced by <see cref="Encrypt"/>.
    /// Throws <see cref="System.Security.Cryptography.AuthenticationTagMismatchException"/>
    /// if the ciphertext has been tampered with.
    /// </summary>
    string Decrypt(string ciphertext);
}
