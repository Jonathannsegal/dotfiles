import pathlib
import subprocess
import unittest


class StandardsTests(unittest.TestCase):
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
