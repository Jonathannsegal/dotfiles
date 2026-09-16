'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const { detect } = require('./detect');
async function fixture(t, files) {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'dotfiles-detect-'));
  t.after(() => fs.rm(root, { recursive: true, force: true }));
  for (const [name, content] of Object.entries(files)) {
    await fs.mkdir(path.dirname(path.join(root, name)), { recursive: true });
    await fs.writeFile(path.join(root, name), content);
  }
  return root;
}
test('fresh Python clone is detected without stored folder associations', async t => {
  const root = await fixture(t, { 'pyproject.toml': '', 'paper/main.tex': '' });
  assert.equal((await detect(root)).profile, 'Research/Python');
});
test('Unity marker wins over helper Python files', async t => {
  const root = await fixture(t, { 'ProjectSettings/ProjectVersion.txt': '', 'tools/build.py': '' });
  assert.equal((await detect(root)).profile, 'Unity/C#');
});
test('paper sources select writing; dependency trees are ignored', async t => {
  const root = await fixture(t, { 'paper/main.tex': '', 'node_modules/tool/pyproject.toml': '' });
  assert.equal((await detect(root)).profile, 'Writing/LaTeX');
});
test('general projects and collection folders stay lightweight', async t => {
  const root = await fixture(t, { 'package.json': '{}', 'src/index.ts': '' });
  assert.equal((await detect(root)).profile, 'Lightweight');
  assert.equal((await detect(os.homedir())).profile, 'Lightweight');
});
test('tracked override wins and invalid values fail safely', async t => {
  const root = await fixture(t, { 'pyproject.toml': '', '.vscode/dotfiles-profile.json': '{"profile":"Writing/LaTeX"}' });
  assert.equal((await detect(root)).profile, 'Writing/LaTeX');
  await fs.writeFile(path.join(root, '.vscode/dotfiles-profile.json'), '{"profile":"Unknown"}');
  await assert.rejects(detect(root), /Unknown profile/);
});
test('does not follow symlinks into other projects', async t => {
  const root = await fixture(t, {});
  const other = await fixture(t, { 'main.tex': '' });
  await fs.symlink(other, path.join(root, 'linked-project'));
  assert.equal((await detect(root)).profile, 'Lightweight');
});
