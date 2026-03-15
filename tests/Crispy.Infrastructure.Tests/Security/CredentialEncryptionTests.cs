using System.Security.Cryptography;

using Crispy.Infrastructure.Security;

using FluentAssertions;

using Xunit;

namespace Crispy.Infrastructure.Tests.Security;

[Trait("Category", "Unit")]
public class CredentialEncryptionTests
{
    private readonly CredentialEncryption _sut = new();

    [Fact]
    public void Encrypt_ThenDecrypt_ReturnsOriginalPlaintext()
    {
        const string original = "super-secret-password-123!";

        var encrypted = _sut.Encrypt(original);
        var decrypted = _sut.Decrypt(encrypted);

        decrypted.Should().Be(original);
    }

    [Fact]
    public void Encrypt_SamePlaintext_ProducesDifferentCiphertexts()
    {
        const string plaintext = "same-input";

        var first = _sut.Encrypt(plaintext);
        var second = _sut.Encrypt(plaintext);

        first.Should().NotBe(second);
    }

    [Fact]
    public void Decrypt_TamperedCiphertext_ThrowsAuthenticationTagMismatch()
    {
        var encrypted = _sut.Encrypt("some-value");
        var blob = Convert.FromBase64String(encrypted);

        // Flip a byte in the ciphertext area (after the 12-byte nonce + 16-byte tag)
        blob[28] ^= 0xFF;
        var tampered = Convert.ToBase64String(blob);

        var act = () => _sut.Decrypt(tampered);

        act.Should().Throw<AuthenticationTagMismatchException>();
    }

    [Fact]
    public void Encrypt_ThenDecrypt_EmptyString_RoundTrips()
    {
        var encrypted = _sut.Encrypt(string.Empty);
        var decrypted = _sut.Decrypt(encrypted);

        decrypted.Should().Be(string.Empty);
    }

    [Fact]
    public void Encrypt_ThenDecrypt_UnicodeString_RoundTrips()
    {
        const string unicode = "パスワード 🔐 пароль";

        var encrypted = _sut.Encrypt(unicode);
        var decrypted = _sut.Decrypt(encrypted);

        decrypted.Should().Be(unicode);
    }

    // ------------------------------------------------------------------
    // Null argument guards
    // ------------------------------------------------------------------

    [Fact]
    public void Encrypt_NullInput_ThrowsArgumentNullException()
    {
        var act = () => _sut.Encrypt(null!);

        act.Should().Throw<ArgumentNullException>();
    }

    [Fact]
    public void Decrypt_NullInput_ThrowsArgumentNullException()
    {
        var act = () => _sut.Decrypt(null!);

        act.Should().Throw<ArgumentNullException>();
    }

    // ------------------------------------------------------------------
    // Invalid base64 → FormatException
    // ------------------------------------------------------------------

    [Fact]
    public void Decrypt_InvalidBase64_ThrowsFormatException()
    {
        var act = () => _sut.Decrypt("not-valid-base64!!!");

        act.Should().Throw<FormatException>();
    }

    // ------------------------------------------------------------------
    // Large payload roundtrip
    // ------------------------------------------------------------------

    [Fact]
    public void Encrypt_ThenDecrypt_LargePayload_RoundTrips()
    {
        var large = new string('x', 10_000);

        var encrypted = _sut.Encrypt(large);
        var decrypted = _sut.Decrypt(encrypted);

        decrypted.Should().Be(large);
    }

    // ------------------------------------------------------------------
    // Encrypt returns valid base64
    // ------------------------------------------------------------------

    [Fact]
    public void Encrypt_ReturnsValidBase64String()
    {
        var encrypted = _sut.Encrypt("test-value");

        var act = () => Convert.FromBase64String(encrypted);

        act.Should().NotThrow();
    }

    // ------------------------------------------------------------------
    // Second instance reuses existing key file (LoadOrCreateKey "file exists" branch)
    // ------------------------------------------------------------------

    [Fact]
    public void Encrypt_ThenDecrypt_WithSecondInstance_RoundTrips()
    {
        // First instance creates or reuses the key file
        var first = new CredentialEncryption();
        var encrypted = first.Encrypt("cross-instance-test");

        // Second instance must load the same key from disk
        var second = new CredentialEncryption();
        var decrypted = second.Decrypt(encrypted);

        decrypted.Should().Be("cross-instance-test");
    }
}
