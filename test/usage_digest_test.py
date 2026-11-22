#!/usr/bin/env python3
"""Tests for skills/agent-coach/scripts/usage-digest. Usage: python3 test/usage_digest_test.py"""
import json
import os
import sqlite3
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
DIGEST = os.path.join(HERE, "..", "skills", "agent-coach", "scripts", "usage-digest")


def line(**entry):
    return json.dumps(entry) + "\n"


def user(ts, text, session="s1", cwd="/work/app", **extra):
    return line(type="user", timestamp=ts, sessionId=session, cwd=cwd, gitBranch="main",
                entrypoint="claude-desktop", message={"role": "user", "content": text}, **extra)


def assistant(ts, blocks, session="s1", model="claude-opus-5-5"):
    return line(type="assistant", timestamp=ts, sessionId=session,
                message={"role": "assistant", "model": model, "content": blocks,
                         "usage": {"input_tokens": 10, "output_tokens": 5}})


def tool_use(name, **inp):
    return {"type": "tool_use", "id": "t", "name": name, "input": inp}


def tool_result(ts, is_error, text, session="s1"):
    return line(type="user", timestamp=ts, sessionId=session,
                message={"role": "user", "content": [
                    {"type": "tool_result", "tool_use_id": "t", "is_error": is_error, "content": text}]})


class UsageDigestTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = self.tmp.name
        self.claude = os.path.join(root, "claude")
        self.codex = os.path.join(root, "codex")
        proj = os.path.join(self.claude, "projects", "-work-app")
        os.makedirs(os.path.join(proj, "s1", "subagents"))
        with open(os.path.join(proj, "s1.jsonl"), "w") as f:
            f.write(user("2026-11-10T09:00:00Z", "fix the flaky booking test"))
            f.write(assistant("2026-11-10T09:00:05Z", [
                {"type": "text", "text": "ok"},
                tool_use("Bash", command="npm test"),
                tool_use("Skill", skill="toolkit:implement"),
                tool_use("mcp__github__create_pr", title="x"),
            ]))
            f.write(tool_result("2026-11-10T09:00:06Z", True, "boom"))
            f.write(tool_result("2026-11-10T09:00:07Z", True,
                                "The user doesn't want to proceed with this tool use."))
            f.write(tool_result("2026-11-10T09:00:08Z", False, "all tests passed"))
            f.write(tool_result("2026-11-10T09:00:09Z", True,
                                "Permission for this action was denied by the Claude Code auto mode classifier."
                                " Reason: pushes to main."))
            f.write(tool_result("2026-11-10T09:00:09Z", True,
                                "The Claude Code auto mode classifier gave no verdict for this action."))
            f.write(user("2026-11-10T09:01:00Z", "<command-name>/review</command-name>"))
            f.write(user("2026-11-10T09:02:00Z", "caveat", isMeta=True))
            f.write(user("2026-11-10T09:03:00Z", "[Request interrupted by user]"))
            f.write(user("2026-11-10T09:03:30Z", "This session is being continued from a previous conversation that ran out of context."))
            f.write(user("2026-11-10T09:04:00Z", "now run the linter too"))
            f.write(user("2026-11-10T09:04:10Z", "subagent prompt in main file", isSidechain=True))
            f.write(user("2026-11-10T09:04:20Z", "<local-command-stdout>done</local-command-stdout>"))
            f.write(user("2026-11-10T09:04:30Z", [
                {"type": "text", "text": "<system-reminder>context</system-reminder>"},
                {"type": "text", "text": "and update the docs"},
            ]))
        with open(os.path.join(proj, "s1", "subagents", "agent-1.jsonl"), "w") as f:
            f.write(user("2026-11-10T09:00:10Z", "subagent prompt", isSidechain=True))
        # Outside the window: must be ignored.
        with open(os.path.join(proj, "old.jsonl"), "w") as f:
            f.write(user("2026-10-01T09:00:00Z", "ancient", session="old"))
        with open(os.path.join(proj, "agents.md"), "w") as f:
            f.write("not a transcript")

        os.makedirs(self.codex)
        db = sqlite3.connect(os.path.join(self.codex, "state_5.sqlite"))
        db.execute("create table threads (id text, created_at int, updated_at int, cwd text, title text,"
                   " model text, tokens_used int, first_user_message text, archived int, source text)")
        db.execute("insert into threads values ('c1', 1794301200, 1794304800, '/work/api', 'Add rate limit',"
                   " 'gpt-5.1-codex', 1234, 'add a rate limiter to the api', 0, 'cli')")
        db.execute("insert into threads values ('c0', 1700000000, 1700000100, '/work/old', 'Old', 'm', 1, 'x', 0, 'cli')")
        db.commit()
        db.close()

    def tearDown(self):
        self.tmp.cleanup()

    def run_digest(self, *args):
        out = subprocess.run([sys.executable, "-I", DIGEST, "--claude-dir", self.claude,
                              "--codex-dir", self.codex, "--since", "2026-11-09", "--until", "2026-11-16",
                              *args], capture_output=True, text=True, check=True)
        return out.stdout

    def test_claude_session_summary(self):
        data = json.loads(self.run_digest("--format", "json"))
        sessions = data["claude_code"]["sessions"]
        self.assertEqual([s["id"] for s in sessions], ["s1"])
        s = sessions[0]
        self.assertEqual(s["cwd"], "/work/app")
        self.assertEqual(s["prompts"], ["fix the flaky booking test", "now run the linter too", "and update the docs"])
        self.assertEqual(s["slash_commands"], ["/review"])
        self.assertEqual(s["skills"], ["toolkit:implement"])
        self.assertEqual(s["tools"], {"Bash": 1, "Skill": 1, "mcp__github__create_pr": 1})
        self.assertEqual(s["tool_errors"], 4)
        self.assertEqual(s["denials"], 2)
        self.assertEqual(s["interrupts"], 1)
        self.assertEqual(s["subagents"], 1)
        self.assertEqual(s["models"], ["claude-opus-5-5"])
        self.assertEqual(s["entrypoint"], "claude-desktop")

    def test_claude_totals(self):
        totals = json.loads(self.run_digest("--format", "json"))["claude_code"]["totals"]
        self.assertEqual(totals["sessions"], 1)
        self.assertEqual(totals["prompts"], 3)
        self.assertEqual(totals["by_project"], {"/work/app": 1})
        self.assertEqual(totals["mcp_servers"], {"github": 1})

    def test_codex_threads_in_window(self):
        codex = json.loads(self.run_digest("--format", "json"))["codex"]
        self.assertEqual([t["id"] for t in codex["threads"]], ["c1"])
        self.assertEqual(codex["threads"][0]["first_user_message"], "add a rate limiter to the api")
        self.assertEqual(codex["totals"]["by_project"], {"/work/api": 1})

    def test_missing_codex_dir_is_reported_not_fatal(self):
        out = subprocess.run([sys.executable, "-I", DIGEST, "--claude-dir", self.claude,
                              "--codex-dir", os.path.join(self.tmp.name, "nope"),
                              "--since", "2026-11-09", "--until", "2026-11-16", "--format", "json"],
                             capture_output=True, text=True, check=True)
        self.assertEqual(json.loads(out.stdout)["codex"]["threads"], [])

    def test_out_file_and_folder_are_owner_only(self):
        report_dir = os.path.join(self.tmp.name, "reports")
        os.makedirs(report_dir, mode=0o755)
        os.chmod(report_dir, 0o755)
        out = os.path.join(report_dir, "digest.md")
        with open(out, "w") as f:
            f.write("stale")
        os.chmod(out, 0o644)
        old_umask = os.umask(0o022)
        try:
            self.run_digest("--out", out)
        finally:
            os.umask(old_umask)
        self.assertEqual(os.stat(report_dir).st_mode & 0o777, 0o700)
        self.assertEqual(os.stat(out).st_mode & 0o777, 0o600)
        with open(out) as f:
            self.assertIn("fix the flaky booking test", f.read())

    def test_out_creates_missing_folder_owner_only(self):
        out = os.path.join(self.tmp.name, "new", "digest.md")
        self.run_digest("--out", out)
        self.assertEqual(os.stat(os.path.dirname(out)).st_mode & 0o777, 0o700)
        self.assertEqual(os.stat(out).st_mode & 0o777, 0o600)

    def test_out_in_folder_not_owned_still_writes_private_file(self):
        if os.stat("/tmp").st_uid == os.getuid():
            self.skipTest("/tmp is owned by this user")
        out = os.path.join("/tmp", f"usage-digest-test-{os.getpid()}.md")
        try:
            result = subprocess.run([sys.executable, "-I", DIGEST, "--claude-dir", self.claude,
                                     "--codex-dir", self.codex, "--since", "2026-11-09", "--until", "2026-11-16",
                                     "--out", out], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("warning", result.stderr)
            self.assertEqual(os.stat(out).st_mode & 0o777, 0o600)
        finally:
            if os.path.exists(out):
                os.remove(out)

    def test_markdown_mentions_window_and_prompts(self):
        md = self.run_digest()
        self.assertIn("2026-11-09", md)
        self.assertIn("fix the flaky booking test", md)
        self.assertIn("Add rate limit", md)


if __name__ == "__main__":
    unittest.main()
