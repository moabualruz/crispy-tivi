using System.Security.Cryptography;

using Crispy.Infrastructure.Security;

using FluentAssertions;

using Xunit;

namespace Crispy.Infrastructure.Tests.Security;

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
}
