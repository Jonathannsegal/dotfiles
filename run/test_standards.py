import os
import pathlib
import subprocess
import unittest


class StandardsTests(unittest.TestCase):
    def test_sidebar_width_tolerance_rejects_large_drift_and_invalid_values(self):
        for value in ('156', '158', '160', '164', '155', '165', '<unset>', 'abc', '158.5'):
            with self.subTest(value=value):
                result = subprocess.run(
                    ['bash', '-c', 'source "$1"; '
                     'read_default() { echo "$TEST_WIDTH"; }; '
                     'check_default_int_tolerance com.apple.finder SidebarWidth2 160 4',
                     '--', str(pathlib.Path(__file__).with_name('.standards.sh'))],
                    env={**os.environ, 'TEST_WIDTH': value},
                    capture_output=True, text=True, check=False)
                self.assertEqual(result.returncode, 0 if value in ('156', '158', '160', '164') else 1,
                                 result.stderr)

    def test_parallel_audit_preserves_order_and_reports_crashed_check(self):
        script = r'''
source "$1"
check_apps() { sleep 0.1; violation 'first category'; }
check_settings() { violation 'second category'; }
check_home() { echo 'inventory failure'; return 7; }
check_launchagents() { :; }
check_installer_guard() { :; }
check_adobe_app_bundles() { :; }
check_desktop() { :; }
check_downloads() { :; }
check_unwanted_artifacts() { :; }
full_audit
'''
        result = subprocess.run(
            ['bash', '-c', script, '--', str(pathlib.Path(__file__).with_name('.standards.sh'))],
            capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertLess(result.stdout.index('first category'), result.stdout.index('second category'))
        self.assertIn('inventory failure', result.stdout)
        self.assertIn('audit check failed: check_home', result.stdout)
        self.assertIn('FAIL: 3 strict-standard violation(s).', result.stdout)

    def test_full_audit_reports_each_unmanaged_package_once(self):
        script = r'''
source "$1"
check_apps() {
  check_formula_drift
  check_set_drift cask installed_casks 'brewfile_entries cask'
}
installed_formulas() { printf 'libnghttp3\nlibngtcp2\n'; }
installed_formulae_all() { installed_formulas; }
installed_casks() { echo chatgpt; }
brewfile_entries() { :; }
unwanted_paths() { :; }
check_settings() { :; }
check_home() { :; }
check_launchagents() { :; }
check_installer_guard() { :; }
check_adobe_app_bundles() { :; }
check_desktop() { :; }
check_downloads() { :; }
full_audit
'''
        result = subprocess.run(
            ['bash', '-c', script, '--', str(pathlib.Path(__file__).with_name('.standards.sh'))],
            capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(result.stdout.count('VIOLATION\t'), 3, result.stdout)
        self.assertIn('FAIL: 3 strict-standard violation(s).', result.stdout)


if __name__ == '__main__':
    unittest.main()
