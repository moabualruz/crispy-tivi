/// Execute an `INSERT OR REPLACE` statement.
///
/// Generates and executes a full-row replace upsert.  SQLite's
/// `OR REPLACE` conflict resolution deletes the conflicting row
/// and inserts the new one, so every column is always written.
///
/// # Arguments
/// * `$conn` — a rusqlite `Connection` (or `PooledConnection`)
/// * `$table` — table name literal, e.g. `"db_bookmarks"`
/// * `[$($col),+]` — ordered column name literals
/// * `$params` — a `rusqlite::params![...]` expression matching
///   the column order above
///
/// # Example
/// ```ignore
/// insert_or_replace!(
///     conn,
///     "db_settings",
///     ["key", "value"],
///     params![key, value],
/// )?;
/// ```
#[macro_export]
macro_rules! insert_or_replace {
    (
        $conn:expr,
        $table:expr,
        [$($col:expr),+ $(,)?],
        $params:expr $(,)?
    ) => {{
        let columns = [$($col),+];
        let placeholders: Vec<String> =
            (1..=columns.len()).map(|i| format!("?{i}")).collect();
        let sql = format!(
            "INSERT OR REPLACE INTO {} ({}) VALUES ({})",
            $table,
            columns.join(", "),
            placeholders.join(", "),
        );
        $conn.execute(&sql, $params)
    }};
}

/// Execute an `INSERT … ON CONFLICT … DO UPDATE SET excluded.*`
/// statement.
///
/// All non-conflict columns are set to their `excluded` value on
/// conflict, which is the standard "upsert all fields" pattern.
/// Use this when you need explicit conflict-key control rather
/// than `OR REPLACE` semantics (which deletes + reinserts).
///
/// # Arguments
/// * `$conn` — a rusqlite `Connection` (or `PooledConnection`)
/// * `$table` — table name literal
/// * `[$($col),+]` — ordered column name literals (must include
///   the conflict key column(s))
/// * `$conflict` — conflict target literal, e.g. `"id"` or
///   `"source_id, native_id"`
/// * `$params` — a `rusqlite::params![...]` expression
///
/// # Example
/// ```ignore
/// upsert!(
///     conn,
///     "db_playback_checkpoints",
///     ["content_id", "position_secs", "timestamp", "content_type"],
///     "content_id",
///     params![content_id, position_secs, timestamp, content_type],
/// )?;
/// ```
#[macro_export]
macro_rules! upsert {
    (
        $conn:expr,
        $table:expr,
        [$($col:expr),+ $(,)?],
        $conflict:expr,
        $params:expr $(,)?
    ) => {{
        let columns = [$($col),+];
        let conflict_cols: Vec<&str> = $conflict
            .split(',')
            .map(|s| s.trim())
            .collect();
        let placeholders: Vec<String> =
            (1..=columns.len()).map(|i| format!("?{i}")).collect();
        let updates: Vec<String> = columns
            .iter()
            .filter(|c| !conflict_cols.contains(c))
            .map(|c| format!("{c} = excluded.{c}"))
            .collect();
        let sql = format!(
            "INSERT INTO {} ({}) VALUES ({}) \
             ON CONFLICT({}) DO UPDATE SET {}",
            $table,
            columns.join(", "),
            placeholders.join(", "),
            $conflict,
            updates.join(", "),
        );
        $conn.execute(&sql, $params)
    }};
}
