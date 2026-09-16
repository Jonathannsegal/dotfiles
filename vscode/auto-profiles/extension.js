'use strict';
const vscode = require('vscode');
const fs = require('node:fs');
const path = require('node:path');
const { detect } = require('./detect');
function activate(context) {
  const log = vscode.window.createOutputChannel('Dotfiles Profiles');
  const status = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 10);
  status.command = 'dotfilesProfiles.detect';
  context.subscriptions.push(log, status);
  let busy = false;
  // Do not reload an existing window just because this extension was installed.
  const installedAt = JSON.parse(fs.readFileSync(path.join(__dirname, 'installed.json'), 'utf8')).time;
  const existingSession = Date.now() - process.uptime() * 1000 < installedAt;
  async function apply(manual = false) {
    if (busy || !vscode.workspace.isTrusted) return;
    const folders = vscode.workspace.workspaceFolders;
    if (!folders?.length || folders.some(f => f.uri.scheme !== 'file')) return;
    busy = true;
    try {
      const detected = await Promise.all(folders.map(f => detect(f.uri.fsPath)));
      // Mixed workspaces prioritize Unity, then Python, then writing.
      const priority = ['Unity/C#', 'Research/Python', 'Writing/LaTeX', 'Lightweight'];
      const name = priority.find(n => detected.some(d => d.profile === n));
      const map = JSON.parse(fs.readFileSync(path.join(__dirname, 'profile-map.json'), 'utf8'));
      const id = map[name];
      const parts = context.globalStorageUri.fsPath.split(path.sep);
      const index = parts.lastIndexOf('profiles');
      const current = index < 0 ? '__default__profile__' : parts[index + 1];
      status.text = `$(settings) ${name}`;
      status.tooltip = detected.map((d, i) => `${folders[i].name}: ${d.reason}`).join('\n');
      status.show();
      log.appendLine(`${name}: ${status.tooltip}`);
      if (id === current || (!manual && existingSession)) return;
      if (!manual && !vscode.workspace.getConfiguration('dotfilesProfiles').get('enabled', true)) return;
      if (vscode.workspace.textDocuments.some(d => d.isDirty)) {
        status.text = `$(warning) Profile ready: ${name}`;
        status.tooltip += '\nSave edits and click to apply the detected profile.';
        return;
      }
      // Use the native per-profile switch command, never rewrite VS Code's live DB.
      const command = `workbench.profiles.actions.profileEntry.${id}`;
      const available = await vscode.commands.getCommands(true);
      if (!id || !available.includes(command)) throw new Error('Native profile switch command unavailable; rerun dotfiles profile setup.');
      await vscode.commands.executeCommand(command);
    } catch (error) {
      log.appendLine(String(error));
      status.text = '$(warning) Profile detection';
      status.tooltip = String(error); status.show();
      if (manual) vscode.window.showWarningMessage(String(error));
    } finally { busy = false; }
  }
  context.subscriptions.push(vscode.commands.registerCommand('dotfilesProfiles.detect', () => apply(true)));
  context.subscriptions.push(vscode.workspace.onDidChangeWorkspaceFolders(() => apply()));
  const watcher = vscode.workspace.createFileSystemWatcher('**/.vscode/dotfiles-profile.json');
  context.subscriptions.push(watcher, watcher.onDidChange(() => apply()), watcher.onDidCreate(() => apply()), watcher.onDidDelete(() => apply()));
  const timer = setTimeout(() => apply(), 1200);
  context.subscriptions.push({ dispose: () => clearTimeout(timer) });
}
module.exports = { activate };
