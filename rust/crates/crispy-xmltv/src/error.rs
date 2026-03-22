//! Error types for XMLTV parsing and writing.

/// Errors that can occur during XMLTV parsing or writing.
#[derive(Debug, thiserror::Error)]
pub enum XmltvError {
    /// XML parsing or structure error.
    #[error("XML error: {0}")]
    Xml(String),

    /// Invalid or unparseable XMLTV timestamp.
    #[error("invalid timestamp: {0}")]
    Timestamp(String),

    /// I/O error during reading.
    #[error("I/O error: {0}")]
    Io(#[from] std::io::Error),

    /// Decompression error (gzip or XZ).
    #[error("decompression error: {0}")]
    Decompression(String),
}

impl From<quick_xml::Error> for XmltvError {
    fn from(e: quick_xml::Error) -> Self {
        Self::Xml(e.to_string())
    }
}

impl From<quick_xml::events::attributes::AttrError> for XmltvError {
    fn from(e: quick_xml::events::attributes::AttrError) -> Self {
        Self::Xml(e.to_string())
    }
}
