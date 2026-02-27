Create and apply a database migration for $ARGUMENTS.

1. Analyze the requested schema change
2. Generate a migration file with:
   - Timestamp-based filename (e.g., 20240101_120000_add_users_table.sql)
   - UP migration (apply changes)
   - DOWN migration (rollback changes)
3. Validate SQL syntax
4. Show the migration and wait for confirmation before applying
