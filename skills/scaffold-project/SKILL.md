---
name: scaffold-project
description: Scaffold a new project with standard structure, configs, and CLAUDE.md
user-invocable: true
argument-hint: "[project-name] [type: nuxt|next|vue-springboot|expo|node|library]"
---

> **Before using:** Replace `{PROJECTS_ROOT}` and `{BOILERPLATE_NAME}` with your actual paths in your copy of this skill. (`./memory/` is the built-in memory folder, no replacement needed.)
>
> **Example only, these scaffolds target JS/TS stacks** (Nuxt, Next, Node, npm library). This is a project generator, so its type menu is intentionally stack-specific. Replace the `type:` list and the per-type steps below with your own stack's scaffolds, such as `rails new`, `django-admin startproject`, `cargo new`, `dotnet new`, `go mod init`, `mvn archetype:generate`, etc.

Initialize a new project at {PROJECTS_ROOT}/$ARGUMENTS:

1. **Parse arguments**: Extract project name and type (default: nuxt)

2. **Create project** based on type (before copying any boilerplate: verify the template directory exists with `test -d`. If missing, fall back to framework CLI scaffolding, such as npx nuxi, npx create-next-app, etc.):
   - **nuxt** (or from template): Use `{PROJECTS_ROOT}/{BOILERPLATE_NAME}` as template, copy or clone into new directory, then replace app name in package.json/README. Alternatively: `npx nuxi@latest init [name]` then add Tailwind, Prisma, Vitest.
   - **next**: Use `{PROJECTS_ROOT}/{BOILERPLATE_NAME}` as template, copy into new directory, update package name and README.
   - **vue-springboot**: Use `{PROJECTS_ROOT}/{BOILERPLATE_NAME}` as template, copy into new directory, update backend/frontend names and README.
   - **expo**: Use `{PROJECTS_ROOT}/{BOILERPLATE_NAME}` as template, copy into new directory, update app.json name and README.
   - **node**: Create Express/Fastify project with TypeScript, Prisma, Vitest
   - **library**: Create npm package with TypeScript, Vitest, tsup bundler

3. **When using a boilerplate template**: Copy the template folder to {PROJECTS_ROOT}/[project-name], then update any project-specific names (package.json name, README title, app.json slug, etc.). Skip step 4 if template already has CLAUDE.md and .env.example.

4. **Generate standard files** (if not from template or if template is minimal):
   - `CLAUDE.md` with project-specific instructions, commands, and stack description
   - `.env.example` with required environment variables
   - `.gitignore` tailored to the stack
   - `vitest.config.ts` with sensible defaults (for JS/TS projects)

5. **Initialize git**: `git init` and create initial commit (if not already a git repo)

6. **Register in memory**: Create project entry in `./memory/projects/active/` using the coding template at `./memory/templates/coding-template.md`

7. **Report**: Show project structure and next steps. For templates, remind user to set env vars (e.g. DATABASE_URL, NEXTAUTH_SECRET, JWT_SECRET) per template README.
