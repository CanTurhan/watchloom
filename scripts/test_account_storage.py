#!/usr/bin/env python3
"""Exercise the app's actual SQLite schema/dirty triggers with SQLite itself."""
from pathlib import Path
import re
import sqlite3
import tempfile
import unittest

SOURCE = (Path(__file__).resolve().parents[1] / 'lib/core/database/watchloom_database.dart').read_text()
SQL = re.findall(r"database\.execute\('''(.*?)'''\)", SOURCE, re.S)


def schema(db, backup=True):
    for sql in SQL:
        if '$' not in sql and ('backup_state' not in sql or backup):
            db.execute(sql)
    if backup:
        add_backup_triggers(db)


def add_backup_triggers(db):
    db.execute('INSERT INTO backup_state(id) VALUES(1)')
    template = next(sql for sql in SQL if 'CREATE TRIGGER' in sql)
    for table in ['library_entries', 'episode_watch_logs', 'unlocked_achievements']:
        for operation in ['INSERT', 'UPDATE', 'DELETE']:
            sql = template.replace('${table}', table).replace('${operation.toLowerCase()}', operation.lower())
            sql = sql.replace('$operation', operation).replace('$table', table)
            db.execute(sql)


def save_show(db, show_id, note='Private note'):
    db.execute("INSERT INTO library_entries(show_id,name,status,personal_note,is_favorite,added_at,updated_at) VALUES(?,?,'watching',?,1,'2026-11-05','2026-11-05')", (show_id, 'Show', note))


class StorageTests(unittest.TestCase):
    def test_v5_media_upgrade_preserves_legacy_data_and_backup_triggers(self):
        db = sqlite3.connect(':memory:')
        # Reconstruct the actual pre-upgrade table by removing only v6 fields.
        library_sql = next(sql for sql in SQL if 'CREATE TABLE IF NOT EXISTS library_entries' in sql)
        for column in ['media_type', 'runtime_minutes', 'trailer_url', 'content_rating']:
            library_sql = re.sub(r'^\s*' + column + r'[^\n]*\n', '', library_sql, flags=re.M)
        db.execute(library_sql)
        # Existing CREATE IF NOT EXISTS does not replace the old library table.
        # Include the actual activity schema and dirty-state triggers too.
        schema(db)
        save_show(db, 42, 'Özel not 🎬')
        db.execute("INSERT INTO episode_watch_logs(show_id,show_name,episode_id,season,episode_number,watched_at) VALUES(42,'Show',4201,2,3,'2026-11-05')")
        db.execute("INSERT INTO unlocked_achievements VALUES('first_episode','2026-11-05')")
        db.execute('UPDATE backup_state SET saved_version=local_version, remote_revision=7')
        backup_before = db.execute('SELECT * FROM backup_state').fetchone()
        migrations = re.findall(r"database\.execute\(\s*['\"](ALTER TABLE library_entries ADD COLUMN [^\n]+?)['\"],?\s*\)", SOURCE)
        self.assertEqual(len(migrations), 4)
        for migration in migrations:
            db.execute(migration)
        self.assertEqual(db.execute('SELECT show_id,personal_note,is_favorite,media_type FROM library_entries').fetchone(), (42, 'Özel not 🎬', 1, 'series'))
        self.assertEqual(db.execute('SELECT show_id,season,episode_number FROM episode_watch_logs').fetchone(), (42, 2, 3))
        self.assertEqual(db.execute('SELECT code FROM unlocked_achievements').fetchone()[0], 'first_episode')
        self.assertEqual(db.execute('SELECT * FROM backup_state').fetchone(), backup_before)
        db.execute("INSERT INTO library_entries(show_id,name,status,added_at,updated_at,media_type,runtime_minutes) VALUES(1000001375666,'Inception','completed','2026-11-12','2026-11-12','movie',148)")
        self.assertEqual(db.execute('SELECT COUNT(*) FROM library_entries').fetchone()[0], 2)
        self.assertEqual(db.execute('SELECT local_version FROM backup_state').fetchone()[0], backup_before[1] + 1)

    def test_existing_v6_file_reopens_with_series_movies_and_account_metadata(self):
        # A binary-only update keeps the same file and schema version. Reopen a
        # real SQLite file rather than replacing it with an empty schema.
        with tempfile.TemporaryDirectory() as directory:
            filename = Path(directory) / 'watchloom.db'
            with sqlite3.connect(filename) as db:
                schema(db)
                db.execute('PRAGMA user_version = 6')
                save_show(db, 42, 'Dizi notu 🎬')
                db.execute("INSERT INTO library_entries(show_id,name,status,personal_note,is_favorite,added_at,updated_at,media_type,runtime_minutes) VALUES(1000001375666,'Inception','completed','Film notu',1,'2026-11-12','2026-11-12','movie',148)")
                db.execute("INSERT INTO episode_watch_logs(show_id,show_name,episode_id,season,episode_number,watched_at) VALUES(42,'Show',4201,2,3,'2026-11-05')")
                db.execute("INSERT INTO unlocked_achievements VALUES('first_episode','2026-11-05')")
                db.execute('UPDATE backup_state SET saved_version=local_version, remote_revision=9')
                expected = {table: db.execute(f'SELECT * FROM {table}').fetchall() for table in ['library_entries', 'episode_watch_logs', 'unlocked_achievements', 'backup_state']}
            db.close()
            with sqlite3.connect(filename) as reopened:
                self.assertEqual(reopened.execute('PRAGMA user_version').fetchone()[0], 6)
                for table, rows in expected.items():
                    self.assertEqual(reopened.execute(f'SELECT * FROM {table}').fetchall(), rows)
            reopened.close()

    def test_v4_upgrade_preserves_legacy_library_and_notes(self):
        db = sqlite3.connect(':memory:')
        schema(db, backup=False)
        save_show(db, 42, 'Özel not 🎬')
        db.execute(next(sql for sql in SQL if 'CREATE TABLE backup_state' in sql))
        add_backup_triggers(db)
        self.assertEqual(db.execute('SELECT show_id,personal_note,is_favorite FROM library_entries').fetchone(), (42, 'Özel not 🎬', 1))
        db.execute("UPDATE library_entries SET personal_note='Edited' WHERE show_id=42")
        self.assertEqual(db.execute('SELECT local_version FROM backup_state').fetchone()[0], 1)

    def test_failed_transaction_rolls_back_records_and_dirty_marker(self):
        db = sqlite3.connect(':memory:')
        schema(db); db.commit()
        with self.assertRaises(sqlite3.IntegrityError):
            with db:
                save_show(db, 1)
                save_show(db, 1)
        self.assertEqual(db.execute('SELECT COUNT(*) FROM library_entries').fetchone()[0], 0)
        self.assertEqual(db.execute('SELECT local_version FROM backup_state').fetchone()[0], 0)

    def test_all_watch_data_tables_mark_the_backup_dirty(self):
        db = sqlite3.connect(':memory:'); schema(db)
        save_show(db, 1)
        db.execute("INSERT INTO episode_watch_logs(show_id,show_name,episode_id,season,episode_number,watched_at) VALUES(1,'Show',2,1,1,'2026-11-05')")
        db.execute("INSERT INTO unlocked_achievements VALUES('first_episode','2026-11-05')")
        for table in ['library_entries', 'episode_watch_logs', 'unlocked_achievements']:
            db.execute(f'DELETE FROM {table}')
        self.assertEqual(db.execute('SELECT local_version FROM backup_state').fetchone()[0], 6)

    def test_account_files_do_not_share_records_and_guest_survives(self):
        with tempfile.TemporaryDirectory() as directory:
            stores = [sqlite3.connect(str(Path(directory) / name)) for name in ['watchloom.db', 'account_a.db', 'account_b.db']]
            for store in stores: schema(store)
            save_show(stores[0], 1); save_show(stores[1], 2)
            self.assertEqual(stores[2].execute('SELECT COUNT(*) FROM library_entries').fetchone()[0], 0)
            stores[1].execute('DELETE FROM library_entries')
            self.assertEqual(stores[0].execute('SELECT show_id FROM library_entries').fetchone()[0], 1)
            for store in stores: store.close()


if __name__ == '__main__':
    unittest.main()
