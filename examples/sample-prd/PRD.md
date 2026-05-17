# Sample PRD: Quick Notes App

> Example PRD to test `/hwan-refactor-idea` on.
> Use: copy this to a new directory as `PRD.md`, run `claude`, then `/hwan-refactor-idea`.

## Product Overview
A minimal note-taking web app. Users can create, edit, and delete short text notes. Notes are stored locally in browser. No accounts, no sync.

## Target Users
Anyone who wants quick notes without account setup. Primarily desktop users.

## Core Features (MVP)
1. Create a new note (title + body)
2. Edit existing note
3. Delete note
4. Search notes by title
5. Auto-save while typing

## Out of Scope (v1)
- Multi-device sync
- Account/login
- Sharing
- Markdown rendering
- Images/attachments

## Success Metrics
- 100 daily active users in month 1
- < 2s page load time
- 0 data loss reports

## Technical Approach
- React + Vite
- LocalStorage for persistence
- No backend in v1
- Deploy on Vercel

## Timeline
2 weeks total.
- Week 1: Core CRUD + auto-save
- Week 2: Search, polish, deploy

---

**Run `/hwan-refactor-idea` on this PRD to see what issues a quality gate finds.**

Expected findings:
- Missing edge cases (empty state, storage quota, browser support)
- Vague success metric (how to measure DAU without analytics?)
- Mobile users dismissed but no rationale
- "No data loss" promise vs LocalStorage reality (incognito, cache clear, etc.)
- Search behavior undefined (case-sensitive? full-text body or just title?)
- Auto-save frequency unspecified
- No accessibility considerations
