import contextlib
import importlib.util
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('health', Path(__file__).with_name('health.py'))
health = importlib.util.module_from_spec(spec)
spec.loader.exec_module(health)

class HealthTests(unittest.TestCase):
    def test_only_new_issues_notify_and_resolved_issues_can_recur(self):
        with tempfile.TemporaryDirectory() as temp:
            previous = health.STATE
            health.STATE = Path(temp)
            try:
                report = {'checked_at': 'now', 'issues': [{'id': 'one', 'category': 'MISSING', 'message': 'Missing app'}]}
                first, repeat, recurring = io.StringIO(), io.StringIO(), io.StringIO()
                with contextlib.redirect_stdout(first): health.notify(report)
                with contextlib.redirect_stdout(repeat): health.notify(report)
                health.notify({'checked_at': 'now', 'issues': []})
                with contextlib.redirect_stdout(recurring): health.notify(report)
                self.assertIn('Missing app', first.getvalue())
                self.assertEqual('', repeat.getvalue())
                self.assertIn('Missing app', recurring.getvalue())
            finally: health.STATE = previous

    def test_daily_startup_runs_once_and_again_next_day(self):
        with tempfile.TemporaryDirectory() as temp, patch.object(health, 'STATE', Path(temp)), patch.object(health.subprocess, 'Popen') as spawn:
            health.startup()
            health.startup()
            self.assertEqual(spawn.call_count, 1)
            health.save('daily.json', {'date': '2000-01-01'})
            health.startup()
            self.assertEqual(spawn.call_count, 2)
            self.assertTrue(spawn.call_args.kwargs['start_new_session'])

    def test_manual_refresh_today_prevents_redundant_daily_run(self):
        with tempfile.TemporaryDirectory() as temp, patch.object(health, 'STATE', Path(temp)), patch.object(health.subprocess, 'Popen') as spawn:
            health.save('latest.json', {'checked_at': health.dt.datetime.now(health.dt.timezone.utc).isoformat(), 'issues': []})
            health.startup()
            spawn.assert_not_called()

    def test_missing_inventory_is_not_empty_success(self):
        code, out, error = health.run(['/nonexistent/dotfiles-test'])
        self.assertNotEqual(code, 0)
        self.assertTrue(error)

    def test_corrupt_cache_is_safe_for_startup(self):
        with tempfile.TemporaryDirectory() as temp:
            previous = health.STATE
            health.STATE = Path(temp)
            try:
                (health.STATE / 'latest.json').write_text('{broken')
                self.assertEqual({}, health.read('latest.json', {}))
            finally: health.STATE = previous

if __name__ == '__main__': unittest.main()
