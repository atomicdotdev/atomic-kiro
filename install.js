#!/usr/bin/env node

/**
 * atomic-kiro install
 *
 * Installs Atomic hooks (via atomic CLI if supported),
 * symlinks skills into ~/.kiro/skills/,
 * and symlinks steering files into ~/.kiro/steering/.
 *
 * Usage:
 *   npx atomic-kiro          # install from npm
 *   node install.js           # install from local checkout
 *   node install.js --silent  # postinstall (no output on success)
 *   node install.js --uninstall  # remove skills and steering symlinks
 */

const fs = require("fs");
const path = require("path");
const os = require("os");
const { execSync } = require("child_process");

const silent = process.argv.includes("--silent");
const uninstall = process.argv.includes("--uninstall");

const PKG_DIR = __dirname;
const KIRO_DIR = path.join(os.homedir(), ".kiro");
const SKILLS_TARGET = path.join(KIRO_DIR, "skills");
const STEERING_TARGET = path.join(KIRO_DIR, "steering");

const SKILL_LINKS = [
  {
    src: "skills/atomic-vault/SKILL.md",
    dst: "atomic-vault/SKILL.md",
  },
  {
    src: "skills/atomic-vcs/SKILL.md",
    dst: "atomic-vcs/SKILL.md",
  },
  {
    src: "skills/code-intelligence/SKILL.md",
    dst: "code-intelligence/SKILL.md",
  },
  {
    src: "skills/codebase-context/SKILL.md",
    dst: "codebase-context/SKILL.md",
  },
  {
    src: "skills/intent-builder/SKILL.md",
    dst: "intent-builder/SKILL.md",
  },
];

const STEERING_LINKS = [
  {
    src: "steering/atomic-agent.md",
    dst: "atomic-agent.md",
  },
];

function ensureDir(filePath) {
  const dir = path.dirname(filePath);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
}

function isOurSymlink(dstPath) {
  try {
    if (!fs.lstatSync(dstPath).isSymbolicLink()) return false;
    const target = fs.readlinkSync(dstPath);
    return target.startsWith(PKG_DIR);
  } catch {
    return false;
  }
}

function tryExec(cmd) {
  try {
    execSync(cmd, { stdio: "pipe" });
    return true;
  } catch {
    return false;
  }
}

function linkFiles(links, targetDir, label) {
  let linked = 0;
  let skipped = 0;

  for (const { src, dst } of links) {
    const srcPath = path.join(PKG_DIR, src);
    const dstPath = path.join(targetDir, dst);

    if (!fs.existsSync(srcPath)) {
      if (!silent) console.warn(`  skip: ${src} (not found in package)`);
      continue;
    }

    if (fs.existsSync(dstPath) && !isOurSymlink(dstPath)) {
      skipped++;
      if (!silent) console.log(`  keep: ${dst} (user file, not overwriting)`);
      continue;
    }

    if (fs.existsSync(dstPath) || isOurSymlink(dstPath)) {
      fs.unlinkSync(dstPath);
    }

    ensureDir(dstPath);
    fs.symlinkSync(srcPath, dstPath);
    linked++;
    if (!silent) console.log(`  link: ${label}/${dst}`);
  }

  return { linked, skipped };
}

function unlinkFiles(links, targetDir, label) {
  let removed = 0;

  for (const { dst } of links) {
    const dstPath = path.join(targetDir, dst);

    if (isOurSymlink(dstPath)) {
      fs.unlinkSync(dstPath);
      removed++;
      if (!silent) console.log(`  unlink: ${label}/${dst}`);

      // Try to remove parent directory if empty
      const dir = path.dirname(dstPath);
      try {
        fs.rmdirSync(dir);
      } catch {
        /* not empty */
      }
    }
  }

  return removed;
}

function doInstall() {
  // 1. Kiro hooks are written directly as .kiro/hooks/*.kiro.hook files
  //    (step 4) and call `atomic agent hooks kiro <verb>` at runtime. Kiro has
  //    no global settings file to merge into, so there is no
  //    `atomic agent enable` step.
  if (!silent && !tryExec("atomic --version")) {
    console.warn(
      "  note: 'atomic' not on PATH — install it so the hooks work at runtime",
    );
  }

  // 2. Symlink skills
  const skills = linkFiles(SKILL_LINKS, SKILLS_TARGET, "skills");

  // 3. Symlink steering
  const steering = linkFiles(STEERING_LINKS, STEERING_TARGET, "steering");

  // 4. Write .kiro/hooks/ files into the current working directory (project)
  const cwd = process.cwd();
  const hooksWritten = installKiroHooks(cwd);
  if (!silent)
    console.log(
      `  hooks: ${hooksWritten} hook files → ${path.join(cwd, ".kiro", "hooks")}/`,
    );

  if (!silent) {
    console.log();
    console.log(
      `✓ atomic-kiro installed (${skills.linked} skills, ${steering.linked} steering files linked)`,
    );
    console.log();
    console.log(
      "Copy AGENTS.md into your project root to enable the agent prompt:",
    );
    console.log(
      `  cp ${path.join(PKG_DIR, "AGENTS.md")} /path/to/your/project/`,
    );
    console.log();
    console.log("Or run from your project directory to install hooks there:");
    console.log("  cd /path/to/your/project && npx atomic-kiro");
    console.log();
  }
}

const HOOK_SCRIPTS_DIR = path.join(PKG_DIR, "hooks");

const KIRO_HOOK_DEFS = [
  {
    file: "atomic-prompt-submit.kiro.hook",
    name: "Atomic Turn Start",
    when: { type: "promptSubmit" },
    script: "prompt-submit.sh",
  },
  {
    file: "atomic-turn-stop.kiro.hook",
    name: "Atomic Turn Stop",
    when: { type: "agentStop" },
    script: "agent-stop.sh",
  },
  // Per-tool hooks so the tool name is passed as an argument
  {
    file: "atomic-pre-tool-write.kiro.hook",
    name: "Atomic Pre Tool Use (write)",
    when: { type: "preToolUse", toolTypes: ["write"] },
    script: "pre-tool-use.sh write",
  },
  {
    file: "atomic-pre-tool-shell.kiro.hook",
    name: "Atomic Pre Tool Use (shell)",
    when: { type: "preToolUse", toolTypes: ["shell"] },
    script: "pre-tool-use.sh shell",
  },
  {
    file: "atomic-pre-tool-read.kiro.hook",
    name: "Atomic Pre Tool Use (read)",
    when: { type: "preToolUse", toolTypes: ["read"] },
    script: "pre-tool-use.sh read",
  },
  {
    file: "atomic-post-tool-write.kiro.hook",
    name: "Atomic Post Tool Use (write)",
    when: { type: "postToolUse", toolTypes: ["write"] },
    script: "post-tool-use.sh write",
  },
  {
    file: "atomic-post-tool-shell.kiro.hook",
    name: "Atomic Post Tool Use (shell)",
    when: { type: "postToolUse", toolTypes: ["shell"] },
    script: "post-tool-use.sh shell",
  },
  {
    file: "atomic-post-tool-read.kiro.hook",
    name: "Atomic Post Tool Use (read)",
    when: { type: "postToolUse", toolTypes: ["read"] },
    script: "post-tool-use.sh read",
  },
  {
    file: "atomic-post-task.kiro.hook",
    name: "Atomic Post Task Execution",
    when: { type: "postTaskExecution" },
    script: "post-task-execution.sh",
  },
];

function installKiroHooks(projectDir) {
  const hooksDir = path.join(projectDir, ".kiro", "hooks");
  fs.mkdirSync(hooksDir, { recursive: true });
  let written = 0;
  for (const def of KIRO_HOOK_DEFS) {
    const hook = {
      version: "1.0.0",
      enabled: true,
      name: def.name,
      when: def.when,
      then: {
        type: "runCommand",
        command: path.join(HOOK_SCRIPTS_DIR, def.script),
      },
    };
    fs.writeFileSync(
      path.join(hooksDir, def.file),
      JSON.stringify(hook, null, 2) + "\n",
    );
    written++;
  }
  return written;
}

function removeKiroHooks(projectDir) {
  const hooksDir = path.join(projectDir, ".kiro", "hooks");
  let removed = 0;
  for (const def of KIRO_HOOK_DEFS) {
    const hookPath = path.join(hooksDir, def.file);
    if (fs.existsSync(hookPath)) {
      fs.unlinkSync(hookPath);
      removed++;
    }
  }
  return removed;
}

function doUninstall() {
  // Kiro's hooks are project .kiro/hooks files (removed below) — there is no
  // global `atomic agent` registration to undo.

  // 2. Remove skill symlinks
  const skillsRemoved = unlinkFiles(SKILL_LINKS, SKILLS_TARGET, "skills");

  // 3. Remove steering symlinks
  const steeringRemoved = unlinkFiles(
    STEERING_LINKS,
    STEERING_TARGET,
    "steering",
  );

  // 4. Remove .kiro/hooks files from current project
  const hooksRemoved = removeKiroHooks(process.cwd());
  if (!silent && hooksRemoved > 0)
    console.log(
      `  hooks: ${hooksRemoved} hook files removed from .kiro/hooks/`,
    );

  if (!silent) {
    console.log();
    console.log(
      `✓ atomic-kiro uninstalled (${skillsRemoved} skills, ${steeringRemoved} steering files removed)`,
    );
    console.log("  Note: AGENTS.md in project roots must be removed manually.");
  }
}

if (uninstall) {
  doUninstall();
} else {
  doInstall();
}
