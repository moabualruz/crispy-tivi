//! S3 ListBucketResult XML response parser.
//!
//! Ported from Dart regex-based S3 XML parsing.
//! Extracts Key, Size, LastModified from `<Contents>`
//! entries using regex (no full XML parser dependency).

use std::sync::LazyLock;

use regex::Regex;
use serde::{Deserialize, Serialize};

static CONTENTS_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?s)<Contents>(.*?)</Contents>").unwrap());
static KEY_RE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"<Key>(.*?)</Key>").unwrap());
static SIZE_RE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"<Size>(.*?)</Size>").unwrap());
static MODIFIED_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"<LastModified>(.*?)</LastModified>").unwrap());

/// A single object entry from an S3 ListBucketResult.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct S3Object {
    /// Object key (path within the bucket).
    pub key: String,
    /// Object size in bytes.
    pub size: i64,
    /// Last modified timestamp (ISO 8601 string).
    pub last_modified: String,
}

/// Parse an S3 ListBucketResult XML response body.
///
/// Extracts all `<Contents>` entries with Key, Size,
/// and LastModified fields. Entries missing any of these
/// three fields are silently skipped.
pub fn parse_s3_list_objects(xml: &str) -> Vec<S3Object> {
    CONTENTS_RE
        .captures_iter(xml)
        .filter_map(|cap| {
            let block = cap.get(1)?.as_str();

            let key = KEY_RE.captures(block)?.get(1)?.as_str().to_string();

            let size_str = SIZE_RE.captures(block)?.get(1)?.as_str();
            let size: i64 = size_str.parse().ok()?;

            let last_modified = MODIFIED_RE.captures(block)?.get(1)?.as_str().to_string();

            Some(S3Object {
                key,
                size,
                last_modified,
            })
        })
        .collect()
}

// ── Tests ────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_multiple_objects() {
        let xml = r#"<?xml version="1.0" encoding="UTF-8"?>
<ListBucketResult>
  <Name>my-bucket</Name>
  <Contents>
    <Key>folder/file1.mp4</Key>
    <Size>1048576</Size>
    <LastModified>2025-01-15T10:30:00.000Z</LastModified>
  </Contents>
  <Contents>
    <Key>folder/file2.jpg</Key>
    <Size>256000</Size>
    <LastModified>2025-02-20T14:00:00.000Z</LastModified>
  </Contents>
  <Contents>
    <Key>root.txt</Key>
    <Size>42</Size>
    <LastModified>2024-12-01T00:00:00.000Z</LastModified>
  </Contents>
</ListBucketResult>"#;

        let objects = parse_s3_list_objects(xml);
        assert_eq!(objects.len(), 3);

        assert_eq!(objects[0].key, "folder/file1.mp4");
        assert_eq!(objects[0].size, 1_048_576);
        assert_eq!(objects[0].last_modified, "2025-01-15T10:30:00.000Z",);

        assert_eq!(objects[1].key, "folder/file2.jpg");
        assert_eq!(objects[1].size, 256_000);

        assert_eq!(objects[2].key, "root.txt");
        assert_eq!(objects[2].size, 42);
    }

    #[test]
    fn empty_response() {
        let xml = r#"<?xml version="1.0" encoding="UTF-8"?>
<ListBucketResult>
  <Name>empty-bucket</Name>
  <Prefix></Prefix>
  <IsTruncated>false</IsTruncated>
</ListBucketResult>"#;

        let objects = parse_s3_list_objects(xml);
        assert!(objects.is_empty());
    }

    #[test]
    fn missing_fields_skipped() {
        let xml = r#"<ListBucketResult>
  <Contents>
    <Key>good.txt</Key>
    <Size>100</Size>
    <LastModified>2025-01-01T00:00:00Z</LastModified>
  </Contents>
  <Contents>
    <Key>no-size.txt</Key>
    <LastModified>2025-01-01T00:00:00Z</LastModified>
  </Contents>
  <Contents>
    <Size>200</Size>
    <LastModified>2025-01-01T00:00:00Z</LastModified>
  </Contents>
  <Contents>
    <Key>no-modified.txt</Key>
    <Size>300</Size>
  </Contents>
</ListBucketResult>"#;

        let objects = parse_s3_list_objects(xml);
        assert_eq!(objects.len(), 1);
        assert_eq!(objects[0].key, "good.txt");
        assert_eq!(objects[0].size, 100);
    }

    #[test]
    fn large_size_values() {
        let xml = r#"<ListBucketResult>
  <Contents>
    <Key>huge.bin</Key>
    <Size>10737418240</Size>
    <LastModified>2025-06-01T12:00:00Z</LastModified>
  </Contents>
</ListBucketResult>"#;

        let objects = parse_s3_list_objects(xml);
        assert_eq!(objects.len(), 1);
        assert_eq!(objects[0].size, 10_737_418_240); // 10 GB
    }

    #[test]
    fn xml_with_namespace_prefix() {
        // Some S3-compatible APIs wrap tags with namespace
        // prefixes. Our regex targets unqualified tags, so
        // prefixed tags should not match — result is empty.
        // This documents the expected behavior.
        let xml = r#"<?xml version="1.0" encoding="UTF-8"?>
<s3:ListBucketResult xmlns:s3="http://s3.amazonaws.com/doc/2006-03-01/">
  <s3:Contents>
    <s3:Key>ns-file.txt</s3:Key>
    <s3:Size>500</s3:Size>
    <s3:LastModified>2025-03-01T00:00:00Z</s3:LastModified>
  </s3:Contents>
</s3:ListBucketResult>"#;

        // Prefixed tags don't match our patterns.
        let objects = parse_s3_list_objects(xml);
        assert!(objects.is_empty());

        // However, AWS S3 itself never uses namespace prefixes
        // on these tags — this test just documents the boundary.
    }

    #[test]
    fn malformed_size_non_numeric() {
        // <Size> contains a non-numeric string. The i64
        // parse fails so the entry is silently skipped.
        let xml = r#"<ListBucketResult>
  <Contents>
    <Key>bad-size.txt</Key>
    <Size>not_a_number</Size>
    <LastModified>2025-01-01T00:00:00Z</LastModified>
  </Contents>
  <Contents>
    <Key>good.txt</Key>
    <Size>42</Size>
    <LastModified>2025-01-01T00:00:00Z</LastModified>
  </Contents>
</ListBucketResult>"#;

        let objects = parse_s3_list_objects(xml);
        assert_eq!(objects.len(), 1);
        assert_eq!(objects[0].key, "good.txt");
    }

    #[test]
    fn malformed_size_float() {
        // <Size> as a float is not valid i64, should skip.
        let xml = r#"<ListBucketResult>
  <Contents>
    <Key>float-size.txt</Key>
    <Size>1024.5</Size>
    <LastModified>2025-01-01T00:00:00Z</LastModified>
  </Contents>
</ListBucketResult>"#;

        let objects = parse_s3_list_objects(xml);
        assert!(objects.is_empty());
    }

    #[test]
    fn negative_size_value() {
        // Negative size is technically parseable as i64.
        let xml = r#"<ListBucketResult>
  <Contents>
    <Key>negative.txt</Key>
    <Size>-1</Size>
    <LastModified>2025-01-01T00:00:00Z</LastModified>
  </Contents>
</ListBucketResult>"#;

        let objects = parse_s3_list_objects(xml);
        assert_eq!(objects.len(), 1);
        assert_eq!(objects[0].size, -1);
    }

    #[test]
    fn very_long_key_with_many_segments() {
        let long_key = (0..50)
            .map(|i| format!("segment{}", i))
            .collect::<Vec<_>>()
            .join("/");
        let xml = format!(
            r#"<ListBucketResult>
  <Contents>
    <Key>{}</Key>
    <Size>100</Size>
    <LastModified>2025-06-15T00:00:00Z</LastModified>
  </Contents>
</ListBucketResult>"#,
            long_key
        );

        let objects = parse_s3_list_objects(&xml);
        assert_eq!(objects.len(), 1);
        assert_eq!(objects[0].key, long_key);
        assert!(objects[0].key.matches('/').count() == 49);
    }

    #[test]
    fn response_with_common_prefixes() {
        // S3 folder listing uses <CommonPrefixes> instead
        // of <Contents>. Parser only extracts <Contents>,
        // so <CommonPrefixes> are ignored.
        let xml = r#"<ListBucketResult>
  <Name>my-bucket</Name>
  <Delimiter>/</Delimiter>
  <CommonPrefixes>
    <Prefix>folder1/</Prefix>
  </CommonPrefixes>
  <CommonPrefixes>
    <Prefix>folder2/</Prefix>
  </CommonPrefixes>
  <Contents>
    <Key>root-file.txt</Key>
    <Size>256</Size>
    <LastModified>2025-03-01T12:00:00Z</LastModified>
  </Contents>
</ListBucketResult>"#;

        let objects = parse_s3_list_objects(xml);
        assert_eq!(objects.len(), 1);
        assert_eq!(objects[0].key, "root-file.txt");
    }

    #[test]
    fn truncated_xml_response() {
        // Response is cut off mid-tag. The <Contents>
        // regex requires a closing tag, so incomplete
        // entries are not matched.
        let xml = r#"<ListBucketResult>
  <Contents>
    <Key>complete.txt</Key>
    <Size>100</Size>
    <LastModified>2025-01-01T00:00:00Z</LastModified>
  </Contents>
  <Contents>
    <Key>incomplete.txt</Key>
    <Size>200</Size>
    <LastModi"#;

        let objects = parse_s3_list_objects(xml);
        assert_eq!(objects.len(), 1);
        assert_eq!(objects[0].key, "complete.txt");
    }

    #[test]
    fn key_with_special_characters() {
        // Keys can contain spaces, unicode, and other
        // characters that might trip up simple parsing.
        let xml = r#"<ListBucketResult>
  <Contents>
    <Key>path/to/my file (1).mp4</Key>
    <Size>500</Size>
    <LastModified>2025-01-01T00:00:00Z</LastModified>
  </Contents>
  <Contents>
    <Key>日本語/ファイル.txt</Key>
    <Size>50</Size>
    <LastModified>2025-02-01T00:00:00Z</LastModified>
  </Contents>
</ListBucketResult>"#;

        let objects = parse_s3_list_objects(xml);
        assert_eq!(objects.len(), 2);
        assert_eq!(objects[0].key, "path/to/my file (1).mp4",);
        assert_eq!(objects[1].key, "日本語/ファイル.txt");
    }
}
