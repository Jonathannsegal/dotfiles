import contextlib
import importlib.util
import io
from pathlib import Path
import tempfile
import threading
from types import SimpleNamespace
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('health', Path(__file__).with_name('health.py'))
health = importlib.util.module_from_spec(spec)
spec.loader.exec_module(health)

class HealthTests(unittest.TestCase):
    def test_fresh_audits_overlap_and_keep_failures_and_partial_cache_sizes(self):
        barrier = threading.Barrier(2, timeout=3)
        calls = []

        def fake_run(args, timeout=60):
            calls.append(args)
            if args[0] == 'bash':
                barrier.wait()  # Both audits must start before either can finish.
                if args[1].endswith('.standards.sh'):
                    return 1, 'DIFF\tcom.apple.finder\tSidebarWidth2', ''
                return 0, 'Everything looks good!', ''
            if args[0] == 'du':
                return 1, f'12582912\t{args[-1]}', 'Permission denied'
            return 127, '', 'Git unavailable'

        with tempfile.TemporaryDirectory() as temp:
            home = Path(temp)
            (home / 'Library/Caches').mkdir(parents=True)
            with patch.object(health, 'HOME', home), patch.object(health, 'ROOT', home / 'repo'), \
                    patch.object(health, 'STATE', home / 'state'), patch.object(health, 'run', side_effect=fake_run), \
                    patch.object(health.shutil, 'disk_usage', return_value=SimpleNamespace(total=100 * 2**30, free=50 * 2**30)):
                first = health.collect()
                second = health.collect()
            self.assertEqual(sum(args[0] == 'bash' for args in calls), 4)
            self.assertEqual(first['issues'], second['issues'])
            self.assertEqual(list(first['details']), ['Standards', 'Johnny.Decimal'])
            self.assertEqual([i['category'] for i in first['issues']],
                             ['PREFERENCE', 'UNAVAILABLE', 'UNAVAILABLE', 'CACHE'])
            self.assertIn('Cache ~/Library/Caches: at least 12.0 GiB', first['summary'])

    def test_manual_commands_always_collect_without_reading_cached_report(self):
        report = {'checked_at': 'now', 'issues': []}
        for args in ([], ['--details'], ['--refresh']):
            with self.subTest(args=args), patch.object(health.sys, 'argv', ['health', *args]), \
                    patch.object(health, 'collect', return_value=report) as collect, \
                    patch.object(health, 'read') as read, \
                    contextlib.redirect_stdout(io.StringIO()) as output:
                health.main()
                health.main()
                self.assertEqual(collect.call_count, 2)
                collect.assert_called_with(wait=True)
                read.assert_not_called()
                self.assertNotIn('Cached report', output.getvalue())

    def test_background_checks_do_not_wait_or_print(self):
        with patch.object(health.sys, 'argv', ['health', '--background']), \
                patch.object(health, 'collect') as collect, \
                contextlib.redirect_stdout(io.StringIO()) as output:
            health.main()
            collect.assert_called_once_with(wait=False)
            self.assertEqual(output.getvalue(), '')

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
