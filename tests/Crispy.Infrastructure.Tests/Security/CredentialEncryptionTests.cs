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

    // ------------------------------------------------------------------
    // Key management tests via injectable path constructor
    // ------------------------------------------------------------------

    [Fact]
    public void Constructor_CustomKeyPath_CreatesKeyFileOnFirstEncrypt()
    {
        var tempDir = Path.Combine(Path.GetTempPath(), $"crispy-test-{Guid.NewGuid():N}");
        var keyPath = Path.Combine(tempDir, "test.key");
        try
        {
            File.Exists(keyPath).Should().BeFalse("key file should not exist before first use");

            var sut = new CredentialEncryption(keyPath);
            sut.Encrypt("trigger-key-creation");

            File.Exists(keyPath).Should().BeTrue("key file should be created on first encrypt");
            var keyBytes = File.ReadAllBytes(keyPath);
            keyBytes.Should().HaveCount(32, "AES-256 key must be 32 bytes");
        }
        finally
        {
            if (Directory.Exists(tempDir)) Directory.Delete(tempDir, true);
        }
    }

    [Fact]
    public void Constructor_CustomKeyPath_CreatesDirectoryIfMissing()
    {
        var tempDir = Path.Combine(Path.GetTempPath(), $"crispy-test-{Guid.NewGuid():N}", "nested", "dir");
        var keyPath = Path.Combine(tempDir, "credential.key");
        try
        {
            Directory.Exists(tempDir).Should().BeFalse();

            var sut = new CredentialEncryption(keyPath);
            sut.Encrypt("trigger");

            Directory.Exists(tempDir).Should().BeTrue("directory should be created recursively");
        }
        finally
        {
            var root = Path.Combine(Path.GetTempPath(), Path.GetFileName(Path.GetDirectoryName(Path.GetDirectoryName(tempDir))!));
            if (Directory.Exists(root)) Directory.Delete(root, true);
        }
    }

    [Fact]
    public void Constructor_CustomKeyPath_LoadsExistingKeyFile()
    {
        var tempDir = Path.Combine(Path.GetTempPath(), $"crispy-test-{Guid.NewGuid():N}");
        var keyPath = Path.Combine(tempDir, "test.key");
        try
        {
            // First instance creates the key
            var first = new CredentialEncryption(keyPath);
            var encrypted = first.Encrypt("persistence-test");

            // Second instance loads the SAME key from disk
            var second = new CredentialEncryption(keyPath);
            var decrypted = second.Decrypt(encrypted);

            decrypted.Should().Be("persistence-test", "second instance must load the same key");
        }
        finally
        {
            if (Directory.Exists(tempDir)) Directory.Delete(tempDir, true);
        }
    }

    [Fact]
    public void Constructor_CustomKeyPath_GeneratesRandomKey_NotAllZeros()
    {
        var tempDir = Path.Combine(Path.GetTempPath(), $"crispy-test-{Guid.NewGuid():N}");
        var keyPath = Path.Combine(tempDir, "test.key");
        try
        {
            var sut = new CredentialEncryption(keyPath);
            sut.Encrypt("trigger");

            var keyBytes = File.ReadAllBytes(keyPath);
            keyBytes.Should().NotBeEquivalentTo(new byte[32], "key must be random, not all zeros");
        }
        finally
        {
            if (Directory.Exists(tempDir)) Directory.Delete(tempDir, true);
        }
    }

    [Fact]
    public void Constructor_CustomKeyPath_TwoSeparatePaths_ProduceDifferentKeys()
    {
        var tempDir1 = Path.Combine(Path.GetTempPath(), $"crispy-test-{Guid.NewGuid():N}");
        var tempDir2 = Path.Combine(Path.GetTempPath(), $"crispy-test-{Guid.NewGuid():N}");
        var keyPath1 = Path.Combine(tempDir1, "test.key");
        var keyPath2 = Path.Combine(tempDir2, "test.key");
        try
        {
            var sut1 = new CredentialEncryption(keyPath1);
            var sut2 = new CredentialEncryption(keyPath2);
            sut1.Encrypt("trigger");
            sut2.Encrypt("trigger");

            var key1 = File.ReadAllBytes(keyPath1);
            var key2 = File.ReadAllBytes(keyPath2);

            key1.Should().NotBeEquivalentTo(key2, "different instances should generate different random keys");
        }
        finally
        {
            if (Directory.Exists(tempDir1)) Directory.Delete(tempDir1, true);
            if (Directory.Exists(tempDir2)) Directory.Delete(tempDir2, true);
        }
    }

    [Fact]
    public void Decrypt_WithDifferentKeyPath_ThrowsAuthenticationTagMismatch()
    {
        var tempDir1 = Path.Combine(Path.GetTempPath(), $"crispy-test-{Guid.NewGuid():N}");
        var tempDir2 = Path.Combine(Path.GetTempPath(), $"crispy-test-{Guid.NewGuid():N}");
        try
        {
            var sut1 = new CredentialEncryption(Path.Combine(tempDir1, "test.key"));
            var sut2 = new CredentialEncryption(Path.Combine(tempDir2, "test.key"));

            var encrypted = sut1.Encrypt("secret");

            // Decrypting with a different key must fail authentication
            var act = () => sut2.Decrypt(encrypted);
            act.Should().Throw<AuthenticationTagMismatchException>();
        }
        finally
        {
            if (Directory.Exists(tempDir1)) Directory.Delete(tempDir1, true);
            if (Directory.Exists(tempDir2)) Directory.Delete(tempDir2, true);
        }
    }
}
