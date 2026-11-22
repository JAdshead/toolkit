#!/usr/bin/env python3
"""Tests for skills/agent-coach/scripts/usage-digest. Usage: python3 test/usage_digest_test.py"""
import datetime as dt
import json
import os
import sqlite3
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
DIGEST = os.path.join(HERE, "..", "skills", "agent-coach", "scripts", "usage-digest")
# The window is [since, until) at local midnight; until is the first moment outside it.
UNTIL = dt.datetime(2026, 11, 16).astimezone()
LONG_PROMPT = "please " * 60  # 420 characters, over the 300-character clip


def zulu(moment):
    return moment.astimezone(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


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
            # Repeats within a session are listed once.
            f.write(assistant("2026-11-10T09:04:40Z", [tool_use("Skill", skill="toolkit:implement")]))
            f.write(user("2026-11-10T09:04:50Z", "<command-name>/review</command-name>"))
            # Harness-made assistant turns carry a placeholder model that isn't a real model.
            f.write(assistant("2026-11-10T09:05:00Z", [{"type": "text", "text": "No response requested."}],
                              model="<synthetic>"))
        with open(os.path.join(proj, "s1", "subagents", "agent-1.jsonl"), "w") as f:
            f.write(user("2026-11-10T09:00:10Z", "subagent prompt", isSidechain=True))
        # Outside the window: must be ignored.
        with open(os.path.join(proj, "old.jsonl"), "w") as f:
            f.write(user("2026-10-01T09:00:00Z", "ancient", session="old"))
        with open(os.path.join(proj, "agents.md"), "w") as f:
            f.write("not a transcript")
        # s2 starts before s1 but its file sorts after it; it has more prompts than the digest keeps.
        web = os.path.join(self.claude, "projects", "-work-web")
        os.makedirs(web)
        with open(os.path.join(web, "s2.jsonl"), "w") as f:
            f.write(user("2026-11-09T12:00:00Z", LONG_PROMPT, session="s2", cwd="/work/web"))
            for i in range(1, 10):
                f.write(user(f"2026-11-09T12:0{i}:00Z", f"step {i}", session="s2", cwd="/work/web"))
        # Edges of the window's exclusive upper bound.
        with open(os.path.join(proj, "edge-in.jsonl"), "w") as f:
            f.write(user(zulu(UNTIL - dt.timedelta(seconds=1)), "last second of the window", session="edge-in"))
        with open(os.path.join(proj, "edge-out.jsonl"), "w") as f:
            f.write(user(zulu(UNTIL), "first second after the window", session="edge-out"))

        os.makedirs(self.codex)
        db = sqlite3.connect(os.path.join(self.codex, "state_5.sqlite"))
        db.execute("create table threads (id text, created_at int, updated_at int, cwd text, title text,"
                   " model text, tokens_used int, first_user_message text, archived int, source text)")
        db.execute("insert into threads values ('c1', 1794301200, 1794304800, '/work/api', 'Add rate limit',"
                   " 'gpt-5.1-codex', 1234, 'add a rate limiter to the api', 0, 'cli')")
        db.execute("insert into threads values ('c2', 1794387600, 1794391200, '/work/app', 'Fix login',"
                   " 'gpt-5.1-codex', 766, 'fix the login redirect', 0, 'vscode')")
        db.execute("insert into threads values ('c0', 1700000000, 1700000100, '/work/old', 'Old', 'm', 1, 'x', 0, 'cli')")
        until = int(UNTIL.timestamp())
        db.execute("insert into threads values ('c-at-until', ?, ?, '/work/api', 'Too late', 'm', 50, 'late', 0, 'cli')",
                   (until, until + 60))
        db.commit()
        db.close()
        # An older Codex schema without the optional columns.
        db = sqlite3.connect(os.path.join(self.codex, "state_6.sqlite"))
        db.execute("create table threads (id text, created_at int, updated_at int, cwd text)")
        db.execute("insert into threads values ('c-old-schema', 1794301200, 1794304800, '/work/legacy')")
        db.commit()
        db.close()

    def tearDown(self):
        self.tmp.cleanup()

    def digest(self, *args, codex=None, check=True):
        return subprocess.run([sys.executable, "-I", DIGEST, "--claude-dir", self.claude,
                               "--codex-dir", codex or self.codex, "--since", "2026-11-09", "--until", "2026-11-16",
                               *args], capture_output=True, text=True, check=check)

    def run_digest(self, *args):
        return self.digest(*args).stdout

    def json_digest(self):
        return json.loads(self.run_digest("--format", "json"))

    def test_claude_session_summary(self):
        sessions = {s["id"]: s for s in self.json_digest()["claude_code"]["sessions"]}
        s = sessions["s1"]
        self.assertEqual(s["cwd"], "/work/app")
        self.assertEqual(s["prompts"], ["fix the flaky booking test", "now run the linter too", "and update the docs"])
        self.assertEqual(s["slash_commands"], ["/review"])
        self.assertEqual(s["skills"], ["toolkit:implement"])
        self.assertEqual(s["tools"], {"Bash": 1, "Skill": 2, "mcp__github__create_pr": 1})
        self.assertEqual(s["tool_errors"], 4)
        self.assertEqual(s["denials"], 2)
        self.assertEqual(s["interrupts"], 1)
        self.assertEqual(s["subagents"], 1)
        self.assertEqual(s["models"], ["claude-opus-5-5"])
        self.assertEqual(s["entrypoint"], "claude-desktop")

    def test_sessions_are_ordered_by_start_time(self):
        sessions = self.json_digest()["claude_code"]["sessions"]
        self.assertEqual([s["id"] for s in sessions], ["s2", "s1", "edge-in"])

    def test_window_upper_bound_is_exclusive_for_claude(self):
        sessions = {s["id"]: s for s in self.json_digest()["claude_code"]["sessions"]}
        self.assertNotIn("edge-out", sessions)
        self.assertEqual(sessions["edge-in"]["prompts"], ["last second of the window"])

    def test_prompts_are_capped_and_clipped(self):
        s2 = {s["id"]: s for s in self.json_digest()["claude_code"]["sessions"]}["s2"]
        self.assertEqual(s2["prompt_count"], 10)
        self.assertEqual(len(s2["prompts"]), 8)
        self.assertEqual(s2["prompts"][1:], [f"step {i}" for i in range(1, 8)])
        long = s2["prompts"][0]
        self.assertEqual(len(long), 300)
        self.assertTrue(long.endswith("…"))
        self.assertEqual(long[:-1], LONG_PROMPT[:299])

    def test_claude_totals(self):
        totals = self.json_digest()["claude_code"]["totals"]
        self.assertEqual(totals, {
            "sessions": 3, "prompts": 14, "tool_errors": 4, "denials": 2, "interrupts": 1, "subagents": 1,
            "by_project": {"/work/app": 2, "/work/web": 1},
            "tools": {"Bash": 1, "Skill": 2, "mcp__github__create_pr": 1},
            "skills": {"toolkit:implement": 1}, "slash_commands": {"/review": 1},
            "mcp_servers": {"github": 1},
        })

    def test_codex_threads_in_window(self):
        codex = self.json_digest()["codex"]
        self.assertEqual([t["id"] for t in codex["threads"]], ["c1", "c2", "c-old-schema"])
        self.assertEqual(codex["threads"][0]["first_user_message"], "add a rate limiter to the api")
        self.assertEqual(codex["totals"], {"threads": 3, "tokens_used": 2000,
                                           "by_project": {"/work/api": 1, "/work/app": 1, "/work/legacy": 1}})

    def test_codex_older_schema_thread_is_read(self):
        threads = {t["id"]: t for t in self.json_digest()["codex"]["threads"]}
        self.assertEqual(threads["c-old-schema"]["cwd"], "/work/legacy")
        self.assertNotIn("title", threads["c-old-schema"])

    def test_corrupt_codex_db_is_warned_not_fatal(self):
        with open(os.path.join(self.codex, "state_9.sqlite"), "wb") as f:
            f.write(b"not a database")
        out = self.digest("--format", "json", check=False)
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn("warning: could not read", out.stderr)
        self.assertEqual([t["id"] for t in json.loads(out.stdout)["codex"]["threads"]], ["c1", "c2", "c-old-schema"])

    def test_missing_codex_dir_is_not_fatal(self):
        out = self.digest("--format", "json", codex=os.path.join(self.tmp.name, "nope"))
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
            result = self.digest("--out", out, check=False)
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

    def test_markdown_counters(self):
        md = self.run_digest()
        self.assertIn("- Sessions: 3, human prompts: 14, subagent runs: 1\n", md)
        self.assertIn("- Tool errors: 4, permission denials: 2, interrupts: 1\n", md)
        self.assertIn("\nprompts 3, errors 4, denials 2, interrupts 1, subagents 1, models claude-opus-5-5\n", md)
        self.assertIn("skills: toolkit:implement; commands: /review\n", md)
        self.assertIn("- Threads: 3, tokens: 2000\n", md)


if __name__ == "__main__":
    unittest.main()
