#!/usr/bin/env node
/**
 * Hee-Lee Oss — Kimi Code CLI adapter installer.
 *
 * Dependency-free (Node builtins only). Two idempotent actions:
 *
 *   1. Copy adapters/kimi/skills/<name>/SKILL.md directories into a Kimi Code CLI skills
 *      directory. Kimi Code CLI's generic (non-branded) skills location is
 *      `~/.config/agents/skills/` (the docs mark this the "recommended" generic path,
 *      alongside the brand-specific `~/.kimi/skills/`; see adapters/kimi/README.md for the doc
 *      citation). Skill directories are copied by name, so re-running just overwrites with
 *      identical content — no duplication.
 *   2. Append (or update in place) the Hee-Lee Oss work-rules snippet in a target repo's
 *      AGENTS.md, wrapped in `<!-- hee-lee-oss:begin -->` / `<!-- hee-lee-oss:end -->`
 *      markers. Re-running replaces the marked block instead of appending a second copy.
 *
 * Usage:
 *   node adapters/kimi/install.mjs [--skills-dir <dir>] [--repo <dir>] [--uninstall] [--dry-run]
 *
 *   --skills-dir <dir>  Where to install skills (default: $KIMI_SKILLS_DIR or
 *                       ~/.config/agents/skills).
 *   --repo <dir>        Target repo whose AGENTS.md gets the snippet (default: cwd).
 *   --uninstall         Remove the installed skills and strip the marked snippet block.
 *   --dry-run           Print what would happen; touch nothing.
 *
 * Both actions are safe to run against a scratch/temp directory for testing — pass
 * --skills-dir and --repo pointing at a temp dir, never assume ~/.config/agents/skills.
 */
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const SKILLS_SRC_DIR = path.join(__dirname, "skills");
const SNIPPET_SRC_PATH = path.join(__dirname, "agents-md-snippet.md");

const BEGIN_MARKER = "<!-- hee-lee-oss:begin -->";
const END_MARKER = "<!-- hee-lee-oss:end -->";

function parseArgs(argv) {
  const args = {
    skillsDir:
      process.env.KIMI_SKILLS_DIR || path.join(os.homedir(), ".config", "agents", "skills"),
    repo: process.cwd(),
    uninstall: false,
    dryRun: false,
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--skills-dir") args.skillsDir = argv[++i];
    else if (a === "--repo") args.repo = argv[++i];
    else if (a === "--uninstall") args.uninstall = true;
    else if (a === "--dry-run") args.dryRun = true;
    else if (a === "--help" || a === "-h") {
      printHelp();
      process.exit(0);
    } else {
      console.error(`Unknown argument: ${a}`);
      printHelp();
      process.exit(1);
    }
  }
  return args;
}

function printHelp() {
  console.log(
    "Usage: node adapters/kimi/install.mjs [--skills-dir <dir>] [--repo <dir>] [--uninstall] [--dry-run]",
  );
}

function listSkillNames() {
  return fs
    .readdirSync(SKILLS_SRC_DIR, { withFileTypes: true })
    .filter((e) => e.isDirectory())
    .map((e) => e.name)
    .sort();
}

/** Recursively copy a directory (Node-builtin only, no deps). */
function copyDir(src, dest) {
  fs.mkdirSync(dest, { recursive: true });
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    const srcPath = path.join(src, entry.name);
    const destPath = path.join(dest, entry.name);
    if (entry.isDirectory()) {
      copyDir(srcPath, destPath);
    } else {
      fs.copyFileSync(srcPath, destPath);
    }
  }
}

function installSkills({ skillsDir, dryRun }) {
  const names = listSkillNames();
  console.log(`Skills destination: ${skillsDir}`);
  for (const name of names) {
    const src = path.join(SKILLS_SRC_DIR, name);
    const dest = path.join(skillsDir, name);
    console.log(`  ${dryRun ? "[dry-run] would copy" : "copy"} ${name}/SKILL.md`);
    if (!dryRun) copyDir(src, dest);
  }
  return names.map((n) => path.join(skillsDir, n));
}

function uninstallSkills({ skillsDir, dryRun }) {
  const names = listSkillNames();
  for (const name of names) {
    const dest = path.join(skillsDir, name);
    if (fs.existsSync(dest)) {
      console.log(`  ${dryRun ? "[dry-run] would remove" : "remove"} ${dest}`);
      if (!dryRun) fs.rmSync(dest, { recursive: true, force: true });
    }
  }
}

/** Strip any previously-installed hee-lee-oss block (between markers, inclusive) from text. */
function stripSnippet(text) {
  const beginIdx = text.indexOf(BEGIN_MARKER);
  const endIdx = text.indexOf(END_MARKER);
  if (beginIdx === -1 || endIdx === -1) return text;
  const before = text.slice(0, beginIdx);
  const after = text.slice(endIdx + END_MARKER.length);
  // Trim trailing blank lines left behind on `before` so re-inserting doesn't accumulate gaps.
  return before.replace(/\n{2,}$/, "\n").trimEnd() + (after.trim() ? "\n\n" + after.trimStart() : "\n");
}

function installAgentsSnippet({ repo, dryRun }) {
  const target = path.join(repo, "AGENTS.md");
  const snippet = fs.readFileSync(SNIPPET_SRC_PATH, "utf8").trimEnd() + "\n";
  let existing = "";
  if (fs.existsSync(target)) {
    existing = fs.readFileSync(target, "utf8");
  }
  const withoutSnippet = existing ? stripSnippet(existing) : "";
  const next = withoutSnippet ? withoutSnippet.replace(/\n*$/, "\n\n") + snippet : snippet;
  console.log(
    `AGENTS.md: ${dryRun ? "[dry-run] would write" : "write"} ${target} (${
      existing ? "updating existing snippet block" : "creating new file"
    })`,
  );
  if (!dryRun) fs.writeFileSync(target, next, "utf8");
  return target;
}

function uninstallAgentsSnippet({ repo, dryRun }) {
  const target = path.join(repo, "AGENTS.md");
  if (!fs.existsSync(target)) return;
  const existing = fs.readFileSync(target, "utf8");
  if (!existing.includes(BEGIN_MARKER)) return;
  const stripped = stripSnippet(existing);
  console.log(`AGENTS.md: ${dryRun ? "[dry-run] would strip" : "strip"} snippet block from ${target}`);
  if (!dryRun) {
    if (stripped.trim().length === 0) {
      fs.rmSync(target);
    } else {
      fs.writeFileSync(target, stripped, "utf8");
    }
  }
}

function main() {
  const args = parseArgs(process.argv.slice(2));

  if (args.uninstall) {
    console.log("== Hee-Lee Oss Kimi adapter: uninstall ==");
    uninstallSkills(args);
    uninstallAgentsSnippet(args);
    console.log("Done.");
    return;
  }

  console.log("== Hee-Lee Oss Kimi adapter: install ==");
  installSkills(args);
  installAgentsSnippet(args);
  console.log("Done.");
  console.log("");
  console.log("Next: in a Kimi Code CLI session, type `/skill:hee-lee-oss-start`,");
  console.log("`/skill:hee-lee-oss-next`, or `/skill:hee-lee-oss-status`.");
}

main();
