---
name: register-project
description: "Register an existing project in AI MemoryCore. Use when starting work on a new repo or when a project needs its own context file. Triggers on: 'register project', 'add project to memory', 'track this project', 'create project file'."
user-invocable: true
---

# Register Project in MemoryCore

## Step 1: Detect Project Info

Gather from the current working directory or user input:
- Project name and path
- Framework/language (check package.json, pyproject.toml, composer.json, etc.)
- Test command (check scripts in package manager config)
- Git remote URL
- Current test count (run tests and count)

## Step 2: Read Template

Read `{MEMORYCORE_PATH}/templates/coding-template.md` for the standard format.

## Step 3: Check Capacity

Scan `{MEMORYCORE_PATH}/projects/active/` — if 10+ projects exist, identify the oldest by Last Accessed date and suggest archiving it.

## Step 4: Create Project File

Write to `{MEMORYCORE_PATH}/projects/active/{project-name}.md` using the template, filled with detected info.

## Step 5: Confirm

Show the created file path and key fields to the user.

## Rules
- Never overwrite an existing project file — read it first and update if it exists
- Use the template format exactly
- Set Last Accessed to today's date
- Leave Session Context section with placeholder (populated during actual work)
