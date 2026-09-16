'use strict';
const fs = require('node:fs/promises');
const path = require('node:path');
const os = require('node:os');
const profiles = ['Lightweight', 'Research/Python', 'Unity/C#', 'Writing/LaTeX'];
const ignored = new Set(['.git', '.venv', 'venv', 'node_modules', 'Library', 'Temp', 'Logs', 'obj', 'bin', 'build', 'dist', '__pycache__']);
async function exists(p) { try { await fs.stat(p); return true; } catch { return false; } }
async function detect(root) {
  // A home/collection folder is not a project. Never scan Library or cloud roots.
  if ([os.homedir(), path.join(os.homedir(), 'Developer'), path.join(os.homedir(), 'Downloads')].includes(root)) return { profile: 'Lightweight', reason: 'collection folder' };
  const marker = path.join(root, '.vscode', 'dotfiles-profile.json');
  if (await exists(marker)) {
    const stat = await fs.stat(marker);
    if (stat.size > 4096) throw new Error('Profile override must be a small JSON file.');
    const value = JSON.parse(await fs.readFile(marker, 'utf8')).profile;
    if (!profiles.includes(value)) throw new Error(`Unknown profile override: ${value}`);
    return { profile: value, reason: '.vscode/dotfiles-profile.json' };
  }
  if (await exists(path.join(root, 'ProjectSettings/ProjectVersion.txt'))) return { profile: 'Unity/C#', reason: 'Unity ProjectSettings' };
  for (const name of ['pyproject.toml', 'requirements.txt', 'Pipfile', 'setup.py', 'environment.yml']) {
    if (await exists(path.join(root, name))) return { profile: 'Research/Python', reason: name };
  }
  let python = false, latex = false, csharp = false, visited = 0;
  const queue = [[root, 0]];
  while (queue.length && visited < 500) {
    const [dir, depth] = queue.shift();
    let entries; try { entries = await fs.readdir(dir, { withFileTypes: true }); } catch { continue; }
    for (const e of entries) {
      if (++visited > 500) break;
      if (e.isSymbolicLink() || e.name.startsWith('.') || ignored.has(e.name)) continue;
      if (e.isDirectory() && depth < 1) queue.push([path.join(dir, e.name), depth + 1]);
      if (e.isFile()) {
        python ||= /\.(py|ipynb)$/.test(e.name);
        latex ||= /\.tex$/.test(e.name);
        csharp ||= /\.(sln|slnx|csproj)$/.test(e.name);
      }
    }
  }
  if (csharp) return { profile: 'Unity/C#', reason: 'C# project/solution' };
  if (latex) return { profile: 'Writing/LaTeX', reason: 'LaTeX source' };
  if (python) return { profile: 'Research/Python', reason: 'Python/notebook source' };
  return { profile: 'Lightweight', reason: 'general editing' };
}
module.exports = { detect, profiles };
