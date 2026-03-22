//! Device identity generation for Stalker portal authentication.
//!
//! Faithfully translated from:
//! - Python: `stalker.py` — `generate_serial`, `generate_device_id`, `generate_signature`
//! - TypeScript: `stalker-client.ts` — `generateSerial`, `generateDeviceId`, `generateSignature`

use md5::{Digest, Md5};
use sha2::Sha256;

/// Generate a 13-character serial from a MAC address.
///
/// Python: `serial = hashlib.md5(mac.encode()).hexdigest()[:13].upper()`
/// TypeScript: `CryptoJS.MD5(mac).toString().substring(0, 13).toUpperCase()`
pub fn generate_serial(mac: &str) -> String {
    let mut hasher = Md5::new();
    hasher.update(mac.as_bytes());
    let hash = hasher.finalize();
    hex::encode(hash)[..13].to_uppercase()
}

/// Generate a 64-character hex device ID from a MAC address (SHA-256).
///
/// Python: `hashlib.sha256(mac.encode()).hexdigest().upper()`
/// TypeScript: `CryptoJS.SHA256(mac).toString().toUpperCase()`
pub fn generate_device_id(mac: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(mac.trim().as_bytes());
    let hash = hasher.finalize();
    hex::encode(hash).to_uppercase()
}

/// Generate a signature for profile requests.
///
/// Python: `hashlib.sha256(f"{mac}{serial}{device_id1}{device_id2}".encode()).hexdigest().upper()`
/// TypeScript: `CryptoJS.SHA256(mac + serial + deviceId + deviceId2).toString().toUpperCase()`
pub fn generate_signature(mac: &str, serial: &str, device_id: &str, device_id2: &str) -> String {
    let data = format!("{mac}{serial}{device_id}{device_id2}");
    let mut hasher = Sha256::new();
    hasher.update(data.as_bytes());
    let hash = hasher.finalize();
    hex::encode(hash).to_uppercase()
}

/// Generate a random 40-character hex string.
///
/// Python: `''.join(random.choices('0123456789abcdef', k=40))`
/// TypeScript: `CryptoJS.lib.WordArray.random(20).toString(CryptoJS.enc.Hex)`
pub fn generate_random_hex() -> String {
    use rand::Rng;
    let mut rng = rand::thread_rng();
    let bytes: Vec<u8> = (0..20).map(|_| rng.r#gen()).collect();
    hex::encode(bytes)
}

/// Generate a random token string (32 uppercase alphanumeric chars).
///
/// Python: `''.join(random.choices(string.ascii_uppercase + string.digits, k=32))`
pub fn generate_token() -> String {
    use rand::Rng;
    const CHARSET: &[u8] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    let mut rng = rand::thread_rng();
    (0..32)
        .map(|_| {
            let idx = rng.gen_range(0..CHARSET.len());
            CHARSET[idx] as char
        })
        .collect()
}

/// Generate a prehash from a token using SHA-1.
///
/// Python: `hashlib.sha1(token.encode()).hexdigest()`
pub fn generate_prehash(token: &str) -> String {
    use sha1::Digest;
    let mut hasher = sha1::Sha1::new();
    hasher.update(token.as_bytes());
    let hash = hasher.finalize();
    hex::encode(hash)
}

/// Generate metrics JSON for profile requests.
///
/// Python: `json.dumps({"mac": mac, "sn": serial, "type": "STB", "model": "MAG250", "uid": "", "random": random})`
pub fn generate_metrics(mac: &str, serial: &str, random: &str) -> String {
    serde_json::json!({
        "mac": mac,
        "sn": serial,
        "type": "STB",
        "model": "MAG250",
        "uid": "",
        "random": random,
    })
    .to_string()
}

/// Generate `hw_version_2` using SHA-1 of MAC.
///
/// Python: `hashlib.sha1(self.mac.encode()).hexdigest()`
/// TypeScript: `CryptoJS.SHA1(this.config.mac).toString()`
pub fn generate_hw_version_2(mac: &str) -> String {
    use sha1::Digest;
    let mut hasher = sha1::Sha1::new();
    hasher.update(mac.as_bytes());
    let hash = hasher.finalize();
    hex::encode(hash)
}

/// Simple hex encoding (avoids pulling in the `hex` crate).
mod hex {
    const HEX_CHARS: &[u8; 16] = b"0123456789abcdef";

    pub fn encode(bytes: impl AsRef<[u8]>) -> String {
        let bytes = bytes.as_ref();
        let mut s = String::with_capacity(bytes.len() * 2);
        for &b in bytes {
            s.push(HEX_CHARS[(b >> 4) as usize] as char);
            s.push(HEX_CHARS[(b & 0x0f) as usize] as char);
        }
        s
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn serial_from_mac_is_13_uppercase_hex() {
        let serial = generate_serial("00:1A:79:AB:CD:EF");
        assert_eq!(serial.len(), 13);
        assert!(serial.chars().all(|c| c.is_ascii_hexdigit()));
        assert_eq!(serial, serial.to_uppercase());
    }

    #[test]
    fn serial_is_deterministic() {
        let s1 = generate_serial("00:1A:79:AB:CD:EF");
        let s2 = generate_serial("00:1A:79:AB:CD:EF");
        assert_eq!(s1, s2);
    }

    #[test]
    fn serial_differs_for_different_macs() {
        let s1 = generate_serial("00:1A:79:AB:CD:EF");
        let s2 = generate_serial("00:1A:79:AB:CD:FF");
        assert_ne!(s1, s2);
    }

    #[test]
    fn device_id_is_64_uppercase_hex() {
        let device_id = generate_device_id("00:1A:79:AB:CD:EF");
        assert_eq!(device_id.len(), 64);
        assert!(device_id.chars().all(|c| c.is_ascii_hexdigit()));
        assert_eq!(device_id, device_id.to_uppercase());
    }

    #[test]
    fn device_id_is_deterministic() {
        let d1 = generate_device_id("00:1A:79:AB:CD:EF");
        let d2 = generate_device_id("00:1A:79:AB:CD:EF");
        assert_eq!(d1, d2);
    }

    #[test]
    fn signature_combines_all_fields() {
        let mac = "00:1A:79:AB:CD:EF";
        let serial = generate_serial(mac);
        let device_id = generate_device_id(mac);
        let sig = generate_signature(mac, &serial, &device_id, &device_id);
        assert_eq!(sig.len(), 64);
        assert!(sig.chars().all(|c| c.is_ascii_hexdigit()));
        assert_eq!(sig, sig.to_uppercase());
    }

    #[test]
    fn signature_is_deterministic() {
        let mac = "00:1A:79:AB:CD:EF";
        let serial = generate_serial(mac);
        let device_id = generate_device_id(mac);
        let s1 = generate_signature(mac, &serial, &device_id, &device_id);
        let s2 = generate_signature(mac, &serial, &device_id, &device_id);
        assert_eq!(s1, s2);
    }

    #[test]
    fn prehash_is_sha1_of_token() {
        let token = "TESTTOKEN123";
        let prehash = generate_prehash(token);
        // SHA-1 produces 40 hex chars
        assert_eq!(prehash.len(), 40);
        assert!(prehash.chars().all(|c| c.is_ascii_hexdigit()));
    }

    #[test]
    fn random_hex_is_40_chars() {
        let r = generate_random_hex();
        assert_eq!(r.len(), 40);
        assert!(r.chars().all(|c| c.is_ascii_hexdigit()));
    }

    #[test]
    fn token_is_32_uppercase_alphanumeric() {
        let t = generate_token();
        assert_eq!(t.len(), 32);
        assert!(
            t.chars()
                .all(|c| c.is_ascii_uppercase() || c.is_ascii_digit())
        );
    }

    #[test]
    fn metrics_is_valid_json() {
        let m = generate_metrics("00:1A:79:AB:CD:EF", "ABCDEF1234567", "aabbcc");
        let parsed: serde_json::Value = serde_json::from_str(&m).unwrap();
        assert_eq!(parsed["mac"], "00:1A:79:AB:CD:EF");
        assert_eq!(parsed["sn"], "ABCDEF1234567");
        assert_eq!(parsed["model"], "MAG250");
    }

    #[test]
    fn hw_version_2_is_sha1_of_mac() {
        let hw = generate_hw_version_2("00:1A:79:AB:CD:EF");
        assert_eq!(hw.len(), 40);
    }
}
