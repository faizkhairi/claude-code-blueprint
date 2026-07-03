# Security Policy

## Scope

This repository contains configuration files (markdown, shell scripts, JSON templates), not application code. However, security matters here because:

- **Hook scripts** execute shell commands on your machine
- **Settings templates** define permission boundaries
- **Skills** can trigger file writes, git operations, and shell commands

## Reporting a Vulnerability

If you discover a security issue in any blueprint component (e.g., a hook script that could be exploited, a permission template that's too permissive, or a skill that could leak sensitive data), please:

1. **Do NOT open a public issue**
2. **Report**: Open a private security advisory via GitHub's [Security Advisories](https://github.com/faizkhairi/claude-code-blueprint/security/advisories/new)
3. Include:
   - Which component is affected (hook, skill, agent, settings template)
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact

## Response Timeline

- **Acknowledgment**: Within 48 hours
- **Assessment**: Within 1 week
- **Fix**: As soon as practical, depending on severity

## Security Best Practices for Users

When adopting components from this blueprint:

1. **Read hook scripts before installing**: they execute on your machine with your permissions
2. **Review the settings template**: don't blindly copy permission allowlists. Remove commands you don't use.
3. **Keep `defaultMode: "dontAsk"` only after** you trust your hooks to catch mistakes. Start with the default mode.
4. **Never commit credentials**: even in CLAUDE.md or memory files. Use `.env` files excluded by `.gitignore`.
5. **Audit Stop hook prompts**: the security verification prompt runs on every response. Ensure it checks for patterns relevant to YOUR project.

## Supported Versions

This is a reference architecture, not versioned software. The `main` branch always contains the latest recommended configuration. There are no backported security fixes; update to the latest `main`.
