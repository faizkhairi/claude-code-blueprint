---
name: init-project
description: Scaffold a new project with standard structure, configs, and CLAUDE.md
user-invocable: true
argument-hint: "[project-name] [type: nuxt|next|vue-springboot|expo|node|library]"
---

Initialize a new project at {PROJECTS_ROOT}/$ARGUMENTS:

1. **Parse arguments**: Extract project name and type (default: nuxt)

2. **Create project** based on type (before copying any boilerplate: verify the template directory exists with `test -d`. If missing, fall back to framework CLI scaffolding — npx nuxi, npx create-next-app, etc.):
   - **nuxt** (or from template): Use `{PROJECTS_ROOT}/{BOILERPLATE_NAME}` as template — copy or clone into new directory, then replace app name in package.json/README. Alternatively: `npx nuxi@latest init [name]` then add Tailwind, Prisma, Vitest.
   - **next**: Use `{PROJECTS_ROOT}/{BOILERPLATE_NAME}` as template — copy into new directory, update package name and README.
   - **vue-springboot**: Use `{PROJECTS_ROOT}/{BOILERPLATE_NAME}` as template — copy into new directory, update backend/frontend names and README.
   - **expo**: Use `{PROJECTS_ROOT}/{BOILERPLATE_NAME}` as template — copy into new directory, update app.json name and README.
   - **node**: Create Express/Fastify project with TypeScript, Prisma, Vitest
   - **library**: Create npm package with TypeScript, Vitest, tsup bundler

3. **When using a boilerplate template**: Copy the template folder to {PROJECTS_ROOT}/[project-name], then update any project-specific names (package.json name, README title, app.json slug, etc.). Skip step 4 if template already has CLAUDE.md and .env.example.

4. **Generate standard files** (if not from template or if template is minimal):
   - `CLAUDE.md` with project-specific instructions, commands, and stack description
   - `.env.example` with required environment variables
   - `.gitignore` tailored to the stack
   - `vitest.config.ts` with sensible defaults (for JS/TS projects)

5. **Initialize git**: `git init` and create initial commit (if not already a git repo)

6. **Register in MemoryCore**: Create project entry in `{MEMORYCORE_PATH}/projects/active/` using the coding template at `{MEMORYCORE_PATH}/templates/coding-template.md`

7. **Report**: Show project structure and next steps. For templates, remind user to set env vars (e.g. DATABASE_URL, NEXTAUTH_SECRET, JWT_SECRET) per template README.
