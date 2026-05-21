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
      try { fs.rmdirSync(dir); } catch { /* not empty */ }
    }
  }

  return removed;
}

function doInstall() {
  // 1. Install hooks via atomic CLI (if supported)
  const hasAtomic = tryExec("atomic --version");
  if (hasAtomic) {
    const installed = tryExec("atomic agent enable --agent kiro --global");
    if (!silent) {
      if (installed) {
        console.log("  hooks: installed via atomic agent");
      } else {
        console.log("  hooks: configure manually in Kiro IDE (see README)");
      }
    }
  } else {
    if (!silent) {
      console.warn("  hooks: skipped (atomic not found on PATH)");
      console.warn("         install Atomic VCS first, then configure hooks in Kiro IDE");
    }
  }

  // 2. Symlink skills
  const skills = linkFiles(SKILL_LINKS, SKILLS_TARGET, "skills");

  // 3. Symlink steering
  const steering = linkFiles(STEERING_LINKS, STEERING_TARGET, "steering");

  if (!silent) {
    console.log();
    console.log(`✓ atomic-kiro installed (${skills.linked} skills, ${steering.linked} steering files linked)`);
    console.log();
    console.log("Copy AGENTS.md into your project root to enable the agent prompt:");
    console.log(`  cp ${path.join(PKG_DIR, "AGENTS.md")} /path/to/your/project/`);
    console.log();
    console.log("Configure hooks in Kiro IDE → Agent Steering & Skills panel:");
    console.log(`  Prompt Submit  → Shell: ${path.join(PKG_DIR, "hooks", "prompt-submit.sh")}`);
    console.log(`  Agent Stop     → Shell: ${path.join(PKG_DIR, "hooks", "agent-stop.sh")}`);
    console.log(`  Pre Tool Use   → Shell: ${path.join(PKG_DIR, "hooks", "pre-tool-use.sh")}`);
    console.log(`  Post Tool Use  → Shell: ${path.join(PKG_DIR, "hooks", "post-tool-use.sh")}`);
    console.log(`  Post Task Exec → Shell: ${path.join(PKG_DIR, "hooks", "post-task-execution.sh")}`);
    console.log();
  }
}

function doUninstall() {
  // 1. Remove hooks via atomic CLI
  const hasAtomic = tryExec("atomic --version");
  if (hasAtomic) {
    tryExec("atomic agent disable --agent kiro --global");
    if (!silent) console.log("  hooks: removed via atomic agent");
  }

  // 2. Remove skill symlinks
  const skillsRemoved = unlinkFiles(SKILL_LINKS, SKILLS_TARGET, "skills");

  // 3. Remove steering symlinks
  const steeringRemoved = unlinkFiles(STEERING_LINKS, STEERING_TARGET, "steering");

  if (!silent) {
    console.log();
    console.log(`✓ atomic-kiro uninstalled (${skillsRemoved} skills, ${steeringRemoved} steering files removed)`);
    console.log("  Note: AGENTS.md in project roots must be removed manually.");
    console.log("  Note: Hook configurations in Kiro IDE must be removed manually.");
  }
}

if (uninstall) {
  doUninstall();
} else {
  doInstall();
}
