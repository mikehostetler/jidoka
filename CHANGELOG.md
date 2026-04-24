# Changelog

All notable changes to Jidoka will be documented in this file.

This project follows conventional commits and is not published yet. The current
codebase is an experimental spike and may change substantially before a first
release.

## 0.1.0 - Unreleased

### Added

- Spark-backed `Jidoka.Agent` DSL for chat-oriented Jido/Jido.AI agents.
- Jidoka-native tools, plugins, hooks, guardrails, runtime context, memory, skills,
  MCP tools, and manager-pattern subagents.
- Imported JSON/YAML agent specs with explicit registries.
- Demo Mix task with chat, orchestrator, imported-agent, and kitchen-sink modes.

### Changed

- Refactored agent compilation, subagent runtime, imported-agent handling, and
  demo CLI internals into smaller single-purpose modules.

### Notes

- Jidoka is experimental and should not be treated as a stable public package.
