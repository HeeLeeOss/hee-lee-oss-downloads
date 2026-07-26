#!/usr/bin/env node
/**
 * Hee-Lee Oss — Codex CLI adapter installer.
 *
 * Dependency-free (Node builtins only). Two idempotent actions:
 *
 *   1. Copy adapters/codex/prompts/*.md into the user's Codex custom-prompts directory
 *      (default: ~/.codex/prompts — the location Codex CLI reads custom prompts from;
 *      see adapters/codex/README.md for the doc citation). Files are copied by name, so
 *      re-running just overwrites with identical content — no duplication.
 *   2. Append (or update in place) the Hee-Lee Oss work-rules snippet in a target repo's
 *      AGENTS.md, wrapped in `<!-- hee-lee-oss:begin -->` / `<!-- hee-lee-oss:end -->`
 *      markers. Re-running replaces the marked block instead of appending a second copy.
 *
 * Usage:
 *   node adapters/codex/install.mjs [--codex-home <dir>] [--repo <dir>] [--uninstall] [--dry-run]
 *
 *   --codex-home <dir>  Where to install prompts (default: $CODEX_HOME or ~/.codex).
 *   --repo <dir>        Target repo whose AGENTS.md gets the snippet (default: cwd).
 *   --uninstall         Remove the installed prompts and strip the marked snippet block.
 *   --dry-run           Print what would happen; touch nothing.
 *
 * Both actions are safe to run against a scratch/temp directory for testing — pass
 * --codex-home and --repo pointing at a temp dir, never assume ~/.codex.
 */
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROMPTS_SRC_DIR = path.join(__dirname, "prompts");
const SNIPPET_SRC_PATH = path.join(__dirname, "agents-md-snippet.md");

const BEGIN_MARKER = "<!-- hee-lee-oss:begin -->";
const END_MARKER = "<!-- hee-lee-oss:end -->";

function parseArgs(argv) {
  const args = {
    codexHome: process.env.CODEX_HOME || path.join(os.homedir(), ".codex"),
    repo: process.cwd(),
    uninstall: false,
    dryRun: false,
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--codex-home") args.codexHome = argv[++i];
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
    "Usage: node adapters/codex/install.mjs [--codex-home <dir>] [--repo <dir>] [--uninstall] [--dry-run]",
  );
}

function listPromptFiles() {
  return fs
    .readdirSync(PROMPTS_SRC_DIR)
    .filter((f) => f.endsWith(".md"))
    .sort();
}

function installPrompts({ codexHome, dryRun }) {
  const destDir = path.join(codexHome, "prompts");
  const files = listPromptFiles();
  console.log(`Prompts destination: ${destDir}`);
  if (!dryRun) fs.mkdirSync(destDir, { recursive: true });
  for (const file of files) {
    const src = path.join(PROMPTS_SRC_DIR, file);
    const dest = path.join(destDir, file);
    console.log(`  ${dryRun ? "[dry-run] would copy" : "copy"} ${file}`);
    if (!dryRun) fs.copyFileSync(src, dest);
  }
  return files.map((f) => path.join(destDir, f));
}

function uninstallPrompts({ codexHome, dryRun }) {
  const destDir = path.join(codexHome, "prompts");
  const files = listPromptFiles();
  for (const file of files) {
    const dest = path.join(destDir, file);
    if (fs.existsSync(dest)) {
      console.log(`  ${dryRun ? "[dry-run] would remove" : "remove"} ${dest}`);
      if (!dryRun) fs.rmSync(dest);
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
  const next = withoutSnippet
    ? withoutSnippet.replace(/\n*$/, "\n\n") + snippet
    : snippet;
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
    console.log("== Hee-Lee Oss Codex adapter: uninstall ==");
    uninstallPrompts(args);
    uninstallAgentsSnippet(args);
    console.log("Done.");
    return;
  }

  console.log("== Hee-Lee Oss Codex adapter: install ==");
  installPrompts(args);
  installAgentsSnippet(args);
  console.log("Done.");
  console.log("");
  console.log("Next: in a Codex CLI session, type `/` and look for `/prompts:hee-lee-oss-start`,");
  console.log("`/prompts:hee-lee-oss-next`, `/prompts:hee-lee-oss-status`.");
}

main();
