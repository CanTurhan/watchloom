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
