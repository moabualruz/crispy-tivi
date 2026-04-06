//! Convenience extension trait for [`rusqlite::Row`].
//!
//! Encapsulates the common column-index to domain-type conversions
//! (`int → bool`, `i64 timestamp → NaiveDateTime`, optional variants)
//! that every `*_from_row` function repeats. Existing functions are
//! unchanged; this trait is available for incremental adoption.

use chrono::NaiveDateTime;
use rusqlite::Row;

/// Extension methods for [`rusqlite::Row`] that perform the common
/// type conversions used throughout the CrispyTivi service layer.
pub trait RowExt {
    /// Read a SQLite integer column (0/1) and convert to `bool`.
    ///
    /// Equivalent to `int_to_bool(row.get(idx)?)`.
    fn get_bool(&self, idx: usize) -> rusqlite::Result<bool>;

    /// Read a nullable SQLite integer column and convert to
    /// `Option<bool>`.
    ///
    /// Returns `Ok(None)` when the column value is SQL NULL.
    fn get_opt_bool(&self, idx: usize) -> rusqlite::Result<Option<bool>>;

    /// Read a nullable SQLite integer column as a Unix timestamp and
    /// convert to `Option<NaiveDateTime>`.
    ///
    /// Returns `Ok(None)` when the column value is SQL NULL.
    /// Equivalent to `opt_ts_to_dt(row.get(idx)?)`.
    fn get_datetime(&self, idx: usize) -> rusqlite::Result<Option<NaiveDateTime>>;

    /// Read a nullable SQLite text column as `Option<String>`.
    ///
    /// Returns `Ok(None)` when the column value is SQL NULL.
    fn get_opt_string(&self, idx: usize) -> rusqlite::Result<Option<String>>;
}

impl RowExt for Row<'_> {
    fn get_bool(&self, idx: usize) -> rusqlite::Result<bool> {
        let v: i32 = self.get(idx)?;
        Ok(v != 0)
    }

    fn get_opt_bool(&self, idx: usize) -> rusqlite::Result<Option<bool>> {
        let v: Option<i32> = self.get(idx)?;
        Ok(v.map(|i| i != 0))
    }

    fn get_datetime(&self, idx: usize) -> rusqlite::Result<Option<NaiveDateTime>> {
        let ts: Option<i64> = self.get(idx)?;
        Ok(ts.map(|t| {
            chrono::DateTime::from_timestamp(t, 0)
                .unwrap_or_default()
                .naive_utc()
        }))
    }

    fn get_opt_string(&self, idx: usize) -> rusqlite::Result<Option<String>> {
        self.get(idx)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn open_test_db() -> rusqlite::Connection {
        let conn = rusqlite::Connection::open_in_memory().expect("in-memory db");
        conn.execute_batch(
            "CREATE TABLE t (
                b_col   INTEGER,
                ob_col  INTEGER,
                ts_col  INTEGER,
                s_col   TEXT
            );
            INSERT INTO t VALUES (1, NULL, 1_700_000_000, 'hello');
            INSERT INTO t VALUES (0, 0,    NULL,           NULL);",
        )
        .expect("setup");
        conn
    }

    #[test]
    fn get_bool_true() {
        let conn = open_test_db();
        let result: bool = conn
            .query_row("SELECT b_col FROM t LIMIT 1", [], |row| row.get_bool(0))
            .unwrap();
        assert!(result);
    }

    #[test]
    fn get_bool_false() {
        let conn = open_test_db();
        let result: bool = conn
            .query_row("SELECT b_col FROM t LIMIT 1 OFFSET 1", [], |row| {
                row.get_bool(0)
            })
            .unwrap();
        assert!(!result);
    }

    #[test]
    fn get_opt_bool_null_returns_none() {
        let conn = open_test_db();
        let result: Option<bool> = conn
            .query_row("SELECT ob_col FROM t LIMIT 1", [], |row| {
                row.get_opt_bool(0)
            })
            .unwrap();
        assert_eq!(result, None);
    }

    #[test]
    fn get_opt_bool_zero_returns_some_false() {
        let conn = open_test_db();
        let result: Option<bool> = conn
            .query_row("SELECT ob_col FROM t LIMIT 1 OFFSET 1", [], |row| {
                row.get_opt_bool(0)
            })
            .unwrap();
        assert_eq!(result, Some(false));
    }

    #[test]
    fn get_datetime_valid_timestamp() {
        let conn = open_test_db();
        let result: Option<NaiveDateTime> = conn
            .query_row("SELECT ts_col FROM t LIMIT 1", [], |row| {
                row.get_datetime(0)
            })
            .unwrap();
        let dt = result.expect("should have datetime");
        assert_eq!(dt.and_utc().timestamp(), 1_700_000_000);
    }

    #[test]
    fn get_datetime_null_returns_none() {
        let conn = open_test_db();
        let result: Option<NaiveDateTime> = conn
            .query_row("SELECT ts_col FROM t LIMIT 1 OFFSET 1", [], |row| {
                row.get_datetime(0)
            })
            .unwrap();
        assert_eq!(result, None);
    }

    #[test]
    fn get_opt_string_some() {
        let conn = open_test_db();
        let result: Option<String> = conn
            .query_row("SELECT s_col FROM t LIMIT 1", [], |row| {
                row.get_opt_string(0)
            })
            .unwrap();
        assert_eq!(result, Some("hello".to_string()));
    }

    #[test]
    fn get_opt_string_null_returns_none() {
        let conn = open_test_db();
        let result: Option<String> = conn
            .query_row("SELECT s_col FROM t LIMIT 1 OFFSET 1", [], |row| {
                row.get_opt_string(0)
            })
            .unwrap();
        assert_eq!(result, None);
    }
}
