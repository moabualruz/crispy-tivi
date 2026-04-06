//! rusqlite `FromSql`/`ToSql` adapters for domain value objects.
//!
//! Domain value objects must not depend on persistence infrastructure.
//! This module lives in the database (infrastructure) layer and implements
//! the SQLite serialisation/deserialisation for each value object, keeping
//! the domain layer free of rusqlite imports.

use rusqlite::types::{FromSql, FromSqlError, FromSqlResult, ToSql, ToSqlOutput, ValueRef};

use crate::value_objects::{
    BackendType, DvrPermission, LayoutType, MediaType, ProfileRole, TransferDirection,
    TransferStatus,
};

// ── ProfileRole ───────────────────────────────────────────────────────────────

impl FromSql for ProfileRole {
    fn column_result(value: ValueRef<'_>) -> FromSqlResult<Self> {
        let n = i32::column_result(value)?;
        Ok(Self::from(n))
    }
}

impl ToSql for ProfileRole {
    fn to_sql(&self) -> rusqlite::Result<ToSqlOutput<'_>> {
        Ok(ToSqlOutput::from(self.as_i32()))
    }
}

// ── DvrPermission ─────────────────────────────────────────────────────────────

impl FromSql for DvrPermission {
    fn column_result(value: ValueRef<'_>) -> FromSqlResult<Self> {
        let n = i32::column_result(value)?;
        Ok(Self::from(n))
    }
}

impl ToSql for DvrPermission {
    fn to_sql(&self) -> rusqlite::Result<ToSqlOutput<'_>> {
        Ok(ToSqlOutput::from(self.as_i32()))
    }
}

// ── BackendType ───────────────────────────────────────────────────────────────

impl FromSql for BackendType {
    fn column_result(value: ValueRef<'_>) -> FromSqlResult<Self> {
        let s = String::column_result(value)?;
        Self::try_from(s.as_str()).map_err(|e| {
            FromSqlError::Other(Box::new(std::io::Error::new(
                std::io::ErrorKind::InvalidData,
                e,
            )))
        })
    }
}

impl ToSql for BackendType {
    fn to_sql(&self) -> rusqlite::Result<ToSqlOutput<'_>> {
        Ok(ToSqlOutput::from(self.as_str()))
    }
}

// ── LayoutType ────────────────────────────────────────────────────────────────

impl FromSql for LayoutType {
    fn column_result(value: ValueRef<'_>) -> FromSqlResult<Self> {
        let s = String::column_result(value)?;
        Self::try_from(s.as_str()).map_err(|e| {
            FromSqlError::Other(Box::new(std::io::Error::new(
                std::io::ErrorKind::InvalidData,
                e,
            )))
        })
    }
}

impl ToSql for LayoutType {
    fn to_sql(&self) -> rusqlite::Result<ToSqlOutput<'_>> {
        Ok(ToSqlOutput::from(self.as_str()))
    }
}

// ── TransferDirection ─────────────────────────────────────────────────────────

impl FromSql for TransferDirection {
    fn column_result(value: ValueRef<'_>) -> FromSqlResult<Self> {
        let s = String::column_result(value)?;
        Self::try_from(s.as_str()).map_err(|e| {
            FromSqlError::Other(Box::new(std::io::Error::new(
                std::io::ErrorKind::InvalidData,
                e,
            )))
        })
    }
}

impl ToSql for TransferDirection {
    fn to_sql(&self) -> rusqlite::Result<ToSqlOutput<'_>> {
        Ok(ToSqlOutput::from(self.as_str()))
    }
}

// ── TransferStatus ────────────────────────────────────────────────────────────

impl FromSql for TransferStatus {
    fn column_result(value: ValueRef<'_>) -> FromSqlResult<Self> {
        let s = String::column_result(value)?;
        Self::try_from(s.as_str()).map_err(|e| {
            FromSqlError::Other(Box::new(std::io::Error::new(
                std::io::ErrorKind::InvalidData,
                e,
            )))
        })
    }
}

impl ToSql for TransferStatus {
    fn to_sql(&self) -> rusqlite::Result<ToSqlOutput<'_>> {
        Ok(ToSqlOutput::from(self.as_str()))
    }
}

// ── MediaType ─────────────────────────────────────────────────────────────────

impl FromSql for MediaType {
    fn column_result(value: ValueRef<'_>) -> FromSqlResult<Self> {
        let s = String::column_result(value)?;
        Self::try_from(s.as_str()).map_err(|e| {
            FromSqlError::Other(Box::new(std::io::Error::new(
                std::io::ErrorKind::InvalidData,
                e,
            )))
        })
    }
}

impl ToSql for MediaType {
    fn to_sql(&self) -> rusqlite::Result<ToSqlOutput<'_>> {
        Ok(ToSqlOutput::from(self.as_str()))
    }
}
