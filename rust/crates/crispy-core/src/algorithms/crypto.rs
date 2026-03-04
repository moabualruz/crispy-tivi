//! AWS S3 Signature V4 signing.
//!
//! Ports the SigV4 logic from Dart
//! `s3_storage_provider.dart` to Rust.

use std::collections::HashMap;

use chrono::{Datelike, NaiveDateTime, Timelike};
use hmac::{Hmac, Mac};
use sha2::{Digest, Sha256};

type HmacSha256 = Hmac<Sha256>;

/// Format bytes as lowercase hex string.
fn to_hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{:02x}", b)).collect()
}

/// SHA-256 hash of a UTF-8 string, returned as hex.
fn sha256_hex(data: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(data.as_bytes());
    to_hex(&hasher.finalize())
}

/// HMAC-SHA256 of `data` keyed by `key`.
fn hmac_sha256(key: &[u8], data: &[u8]) -> Vec<u8> {
    let mut mac = HmacSha256::new_from_slice(key).expect("HMAC accepts any key length");
    mac.update(data);
    mac.finalize().into_bytes().to_vec()
}

/// Format `NaiveDateTime` as `YYYYMMDDTHHMMSSZ`.
fn amz_date(dt: &NaiveDateTime) -> String {
    format!(
        "{:04}{:02}{:02}T{:02}{:02}{:02}Z",
        dt.year(),
        dt.month(),
        dt.day(),
        dt.hour(),
        dt.minute(),
        dt.second(),
    )
}

/// Format `NaiveDateTime` as `YYYYMMDD`.
fn date_stamp(dt: &NaiveDateTime) -> String {
    format!("{:04}{:02}{:02}", dt.year(), dt.month(), dt.day(),)
}

/// 4-level HMAC-SHA256 signing key derivation.
///
/// Mirrors Dart `_getSignatureKey`:
/// ```text
/// kDate    = HMAC("AWS4" + key, dateStamp)
/// kRegion  = HMAC(kDate, region)
/// kService = HMAC(kRegion, service)
/// kSigning = HMAC(kService, "aws4_request")
/// ```
fn get_signature_key(secret_key: &str, date_stamp: &str, region: &str, service: &str) -> Vec<u8> {
    let k_secret = format!("AWS4{}", secret_key).into_bytes();
    let k_date = hmac_sha256(&k_secret, date_stamp.as_bytes());
    let k_region = hmac_sha256(&k_date, region.as_bytes());
    let k_service = hmac_sha256(&k_region, service.as_bytes());
    hmac_sha256(&k_service, b"aws4_request")
}

/// Sign an S3 request using AWS Signature V4.
///
/// Returns a map of headers to add to the HTTP request.
/// The returned headers always include `Authorization`,
/// `x-amz-date`, and `x-amz-content-sha256`.
#[allow(clippy::too_many_arguments)]
pub fn sign_s3_request(
    method: &str,
    path: &str,
    now: NaiveDateTime,
    host: &str,
    region: &str,
    access_key: &str,
    secret_key: &str,
    extra_headers: &HashMap<String, String>,
) -> HashMap<String, String> {
    let amz = amz_date(&now);
    let ds = date_stamp(&now);

    // Collect headers for signing.
    let mut headers: HashMap<String, String> = HashMap::new();
    headers.insert("host".to_string(), host.to_string());
    headers.insert("x-amz-date".to_string(), amz.clone());
    headers.insert(
        "x-amz-content-sha256".to_string(),
        "UNSIGNED-PAYLOAD".to_string(),
    );
    for (k, v) in extra_headers {
        headers.insert(k.clone(), v.clone());
    }

    // Sorted header keys.
    let mut keys: Vec<&String> = headers.keys().collect();
    keys.sort();

    let signed_headers: String = keys
        .iter()
        .map(|k| k.as_str())
        .collect::<Vec<_>>()
        .join(";");

    let canonical_headers: String = keys
        .iter()
        .map(|k| format!("{}:{}", k, headers[k.as_str()]))
        .collect::<Vec<_>>()
        .join("\n");

    let canonical_request = format!(
        "{}\n{}\n\n{}\n\n{}\nUNSIGNED-PAYLOAD",
        method, path, canonical_headers, signed_headers,
    );

    let string_to_sign = format!(
        "AWS4-HMAC-SHA256\n{}\n{}/{}/s3/aws4_request\n{}",
        amz,
        ds,
        region,
        sha256_hex(&canonical_request),
    );

    let signing_key = get_signature_key(secret_key, &ds, region, "s3");
    let signature = to_hex(&hmac_sha256(&signing_key, string_to_sign.as_bytes()));

    let mut result = HashMap::new();
    result.insert(
        "Authorization".to_string(),
        format!(
            "AWS4-HMAC-SHA256 \
             Credential={}/{}/{}/s3/aws4_request, \
             SignedHeaders={}, \
             Signature={}",
            access_key, ds, region, signed_headers, signature,
        ),
    );
    result.insert("x-amz-date".to_string(), amz);
    result.insert(
        "x-amz-content-sha256".to_string(),
        "UNSIGNED-PAYLOAD".to_string(),
    );
    result
}

/// Percent-encode a value for use in AWS query strings.
///
/// Encodes everything except unreserved characters
/// (A-Z a-z 0-9 - _ . ~) per RFC 3986.
fn uri_encode(input: &str) -> String {
    let mut out = String::with_capacity(input.len());
    for byte in input.bytes() {
        match byte {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => {
                out.push(byte as char)
            }
            _ => {
                out.push_str(&format!("%{:02X}", byte));
            }
        }
    }
    out
}

/// Generate a pre-signed URL for an S3 GET request.
///
/// Returns a full URL with query-string authentication
/// valid for `expires_secs` seconds.
#[allow(clippy::too_many_arguments)]
pub fn generate_presigned_url(
    endpoint: &str,
    bucket: &str,
    object_key: &str,
    region: &str,
    access_key: &str,
    secret_key: &str,
    expires_secs: i64,
    now: NaiveDateTime,
) -> String {
    let amz = amz_date(&now);
    let ds = date_stamp(&now);
    let credential = format!("{}/{}/{}/s3/aws4_request", access_key, ds, region,);

    // Build canonical query string (sorted by key).
    // Keys are already in sorted order here.
    let canonical_qs = format!(
        "X-Amz-Algorithm=AWS4-HMAC-SHA256\
         &X-Amz-Credential={}\
         &X-Amz-Date={}\
         &X-Amz-Expires={}\
         &X-Amz-SignedHeaders=host",
        uri_encode(&credential),
        uri_encode(&amz),
        expires_secs,
    );

    // Derive host from the endpoint + bucket URL.
    let base_url = format!(
        "{}/{}/{}",
        endpoint.trim_end_matches('/'),
        bucket,
        object_key,
    );

    // Extract host from the base URL.
    let host = base_url
        .strip_prefix("https://")
        .or_else(|| base_url.strip_prefix("http://"))
        .unwrap_or(&base_url)
        .split('/')
        .next()
        .unwrap_or("");

    // Build the canonical URI path. For path-style URLs
    // this is /bucket/object_key.
    let canonical_uri = format!("/{}/{}", bucket, object_key);

    let canonical_request = format!(
        "GET\n{}\n{}\nhost:{}\n\nhost\nUNSIGNED-PAYLOAD",
        canonical_uri, canonical_qs, host,
    );

    let string_to_sign = format!(
        "AWS4-HMAC-SHA256\n{}\n{}/{}/s3/aws4_request\n{}",
        amz,
        ds,
        region,
        sha256_hex(&canonical_request),
    );

    let signing_key = get_signature_key(secret_key, &ds, region, "s3");
    let signature = to_hex(&hmac_sha256(&signing_key, string_to_sign.as_bytes()));

    format!(
        "{}?{}&X-Amz-Signature={}",
        base_url, canonical_qs, signature,
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::NaiveDate;

    /// Known test vector: verify the 4-level HMAC
    /// derivation produces deterministic output.
    #[test]
    fn signature_key_deterministic() {
        let key = get_signature_key(
            "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY",
            "20130524",
            "us-east-1",
            "s3",
        );
        // Must be 32 bytes (SHA-256 output).
        assert_eq!(key.len(), 32);

        // Same inputs must produce same output.
        let key2 = get_signature_key(
            "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY",
            "20130524",
            "us-east-1",
            "s3",
        );
        assert_eq!(key, key2);
    }

    /// Different inputs must produce different keys.
    #[test]
    fn signature_key_varies_with_input() {
        let k1 = get_signature_key("secret1", "20240101", "us-east-1", "s3");
        let k2 = get_signature_key("secret2", "20240101", "us-east-1", "s3");
        assert_ne!(k1, k2);

        let k3 = get_signature_key("secret1", "20240102", "us-east-1", "s3");
        assert_ne!(k1, k3);

        let k4 = get_signature_key("secret1", "20240101", "eu-west-1", "s3");
        assert_ne!(k1, k4);
    }

    fn test_datetime() -> NaiveDateTime {
        NaiveDate::from_ymd_opt(2024, 1, 15)
            .unwrap()
            .and_hms_opt(12, 30, 45)
            .unwrap()
    }

    #[test]
    fn amz_date_format() {
        let dt = test_datetime();
        assert_eq!(amz_date(&dt), "20240115T123045Z");
    }

    #[test]
    fn date_stamp_format() {
        let dt = test_datetime();
        assert_eq!(date_stamp(&dt), "20240115");
    }

    #[test]
    fn sign_request_returns_required_headers() {
        let now = test_datetime();
        let extra = HashMap::new();
        let result = sign_s3_request(
            "GET",
            "/recordings/test.ts",
            now,
            "s3.example.com",
            "us-east-1",
            "AKIAIOSFODNN7EXAMPLE",
            "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLE",
            &extra,
        );

        assert!(result.contains_key("Authorization"));
        assert!(result.contains_key("x-amz-date"));
        assert!(result.contains_key("x-amz-content-sha256"));
    }

    #[test]
    fn sign_request_authorization_format() {
        let now = test_datetime();
        let extra = HashMap::new();
        let result = sign_s3_request(
            "PUT",
            "/recordings/video.ts",
            now,
            "s3.example.com",
            "us-east-1",
            "AKIAIOSFODNN7EXAMPLE",
            "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLE",
            &extra,
        );

        let auth = &result["Authorization"];
        assert!(auth.starts_with("AWS4-HMAC-SHA256 Credential="));
        assert!(auth.contains("SignedHeaders="));
        assert!(auth.contains("Signature="));
        assert!(auth.contains(
            "AKIAIOSFODNN7EXAMPLE/20240115/\
             us-east-1/s3/aws4_request"
        ));
    }

    #[test]
    fn sign_request_content_sha256_is_unsigned() {
        let now = test_datetime();
        let result = sign_s3_request(
            "GET",
            "/test",
            now,
            "s3.example.com",
            "us-east-1",
            "key",
            "secret",
            &HashMap::new(),
        );

        assert_eq!(result["x-amz-content-sha256"], "UNSIGNED-PAYLOAD",);
    }

    #[test]
    fn sign_request_headers_sorted() {
        let now = test_datetime();
        let result = sign_s3_request(
            "GET",
            "/test",
            now,
            "s3.example.com",
            "us-east-1",
            "key",
            "secret",
            &HashMap::new(),
        );

        let auth = &result["Authorization"];
        // Extract SignedHeaders value.
        let sh_start = auth.find("SignedHeaders=").unwrap() + "SignedHeaders=".len();
        let sh_end = auth[sh_start..].find(',').unwrap() + sh_start;
        let signed_headers = &auth[sh_start..sh_end];

        // Verify sorted order.
        let parts: Vec<&str> = signed_headers.split(';').collect();
        let mut sorted = parts.clone();
        sorted.sort();
        assert_eq!(parts, sorted);

        // Must include host and x-amz-date.
        assert!(parts.contains(&"host"));
        assert!(parts.contains(&"x-amz-date"));
        assert!(parts.contains(&"x-amz-content-sha256"));
    }

    #[test]
    fn sign_request_extra_headers_included() {
        let now = test_datetime();
        let mut extra = HashMap::new();
        extra.insert("content-length".to_string(), "1024".to_string());

        let result = sign_s3_request(
            "PUT",
            "/test",
            now,
            "s3.example.com",
            "us-east-1",
            "key",
            "secret",
            &extra,
        );

        let auth = &result["Authorization"];
        let sh_start = auth.find("SignedHeaders=").unwrap() + "SignedHeaders=".len();
        let sh_end = auth[sh_start..].find(',').unwrap() + sh_start;
        let signed_headers = &auth[sh_start..sh_end];

        assert!(
            signed_headers.contains("content-length"),
            "extra headers must be in SignedHeaders"
        );
    }

    #[test]
    fn sign_request_deterministic() {
        let now = test_datetime();
        let extra = HashMap::new();
        let r1 = sign_s3_request(
            "GET",
            "/test",
            now,
            "host.com",
            "us-east-1",
            "key",
            "secret",
            &extra,
        );
        let r2 = sign_s3_request(
            "GET",
            "/test",
            now,
            "host.com",
            "us-east-1",
            "key",
            "secret",
            &extra,
        );
        assert_eq!(r1["Authorization"], r2["Authorization"],);
    }

    #[test]
    fn presigned_url_contains_required_params() {
        let now = test_datetime();
        let url = generate_presigned_url(
            "https://s3.example.com",
            "my-bucket",
            "recordings/test.ts",
            "us-east-1",
            "AKIAIOSFODNN7EXAMPLE",
            "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLE",
            604800,
            now,
        );

        assert!(url.starts_with(
            "https://s3.example.com/my-bucket/\
             recordings/test.ts?"
        ));
        assert!(url.contains("X-Amz-Algorithm=AWS4-HMAC-SHA256"));
        assert!(url.contains("X-Amz-Credential="));
        assert!(url.contains("X-Amz-Date="));
        assert!(url.contains("X-Amz-Expires=604800"));
        assert!(url.contains("X-Amz-SignedHeaders=host"));
        assert!(url.contains("X-Amz-Signature="));
    }

    #[test]
    fn presigned_url_deterministic() {
        let now = test_datetime();
        let url1 = generate_presigned_url(
            "https://s3.example.com",
            "bucket",
            "key.ts",
            "us-east-1",
            "ak",
            "sk",
            3600,
            now,
        );
        let url2 = generate_presigned_url(
            "https://s3.example.com",
            "bucket",
            "key.ts",
            "us-east-1",
            "ak",
            "sk",
            3600,
            now,
        );
        assert_eq!(url1, url2);
    }

    #[test]
    fn presigned_url_credential_encoded() {
        let now = test_datetime();
        let url = generate_presigned_url(
            "https://s3.example.com",
            "bucket",
            "key.ts",
            "us-east-1",
            "AKID",
            "secret",
            3600,
            now,
        );

        // Credential contains '/' which must be
        // percent-encoded as %2F in the query string.
        assert!(url.contains("%2F"), "credential slashes must be encoded");
    }

    #[test]
    fn presigned_url_signature_is_hex() {
        let now = test_datetime();
        let url = generate_presigned_url(
            "https://s3.example.com",
            "bucket",
            "key.ts",
            "us-east-1",
            "ak",
            "sk",
            3600,
            now,
        );

        let sig_param = "X-Amz-Signature=";
        let start = url.find(sig_param).unwrap() + sig_param.len();
        let sig = &url[start..];
        // Signature must be 64 hex chars (SHA-256).
        assert_eq!(sig.len(), 64);
        assert!(sig.chars().all(|c| c.is_ascii_hexdigit()));
    }

    #[test]
    fn uri_encode_unreserved_unchanged() {
        assert_eq!(uri_encode("ABCxyz0123456789-_.~"), "ABCxyz0123456789-_.~",);
    }

    #[test]
    fn uri_encode_special_chars() {
        assert_eq!(uri_encode("/"), "%2F");
        assert_eq!(uri_encode(" "), "%20");
        assert_eq!(uri_encode("a/b c"), "a%2Fb%20c");
    }

    #[test]
    fn to_hex_works() {
        assert_eq!(to_hex(&[0x00, 0xff, 0xab, 0x12]), "00ffab12",);
    }

    #[test]
    fn sha256_hex_known_value() {
        // SHA-256 of empty string.
        assert_eq!(
            sha256_hex(""),
            "e3b0c44298fc1c149afbf4c8996fb924\
             27ae41e4649b934ca495991b7852b855",
        );
    }
}
