import pathlib
import subprocess
import unittest


class MaintenanceTests(unittest.TestCase):
    def run_update(self, fail_command=''):
        script = r'''
source "$1"
fail_command="$2"
bash() { echo 'sync local tap'; }
brew() {
  echo "brew $*"
  [[ "$1" != "$fail_command" ]]
}
mas() { echo 'mas update'; }
npm() { echo 'npm update'; }
pipx() { echo 'pipx update'; }
code() { echo "code $*"; }
softwareupdate() { echo 'system update check'; }
jq() { echo 'Research/Python'; }
check() { echo "health $*"; }
update
'''
        return subprocess.run(
            ['bash', '-c', script, '--', str(pathlib.Path(__file__).with_name('maintain.sh')), fail_command],
            capture_output=True, text=True, check=False)

    def test_success_updates_profiles_and_refreshes_without_dumping_inventory(self):
        result = self.run_update()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('code --profile Research/Python --update-extensions', result.stdout)
        self.assertIn('health --refresh', result.stdout)
        self.assertNotIn('bundle dump', result.stdout)

    def test_failed_cleanup_still_refreshes_and_returns_failure(self):
        result = self.run_update('cleanup')
        self.assertEqual(result.returncode, 1)
        self.assertIn('health --refresh', result.stdout)
        self.assertIn('1 update step(s) need attention', result.stderr)

    def test_failed_catalog_refresh_stops_before_upgrading(self):
        result = self.run_update('update')
        self.assertEqual(result.returncode, 1)
        self.assertNotIn('brew upgrade', result.stdout)


if __name__ == '__main__':
    unittest.main()
