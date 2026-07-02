---
name: status
description: Show project status dashboard across registered repositories
user-invocable: true
---

Project status dashboard:

1. **Git Status** for each project in the workspace:
   - Branch name, uncommitted changes, last commit, ahead/behind remote
   - Check CLAUDE.md or memory for registered project paths

2. **Services**: Check if dev servers are running
   - Check CLAUDE.md for configured dev ports
   - Use `lsof -i :PORT` or `netstat` to check port availability

3. **Database**: Check database connectivity if applicable
   - Test connection using the project's database URL from its env/config (`.env`, `application.yml`, `config/database.yml`, etc.)

4. **Recent Activity**: Last 3 commits per repo

5. **Test Status**: Run a quick test count (if test command is known from CLAUDE.md)

Present as a clean dashboard with status indicators.
