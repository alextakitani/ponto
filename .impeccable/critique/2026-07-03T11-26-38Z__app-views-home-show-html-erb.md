---
target: tracker (home/show)
total_score: 24
p0_count: 0
p1_count: 3
timestamp: 2026-07-03T11-26-38Z
slug: app-views-home-show-html-erb
---
# Critique — Tracker (`home/show` + timer bar)

**Method: dual-agent** (A: design review · B: detector evidence) — both isolated sub-agents, parallel, synthesized.
**Target:** `app/views/home/show.html.erb` → `home/_tracker_entries` → `home/_day_group` → `time_entries/_time_entry`/`_frame`, plus the shell timer bar (`timers/_bar` in `layouts/app.html.erb`).

## Design Health Score

| # | Heuristic | Score | Key issue |
|---|-----------|-------|-----------|
| 1 | Visibility of System Status | 3 | Running state loud & clear; the *stop* moment is silent — no transient confirmation. |
| 2 | Match System / Real World | 3 | Verbs natural; "Sem descrição" is a link describing nothing. |
| 3 | User Control & Freedom | 2 | No undo after Excluir; inline-edit Cancel drifts to the show page. |
| 4 | Consistency & Standards | 3 | Five independent `<details>` can be open at once, no coordination. |
| 5 | Error Prevention | 2 | Start button not disabled during round-trip (double-click → 409); no client guard on start>end. |
| 6 | Recognition Rather Than Recall | 3 | Day headers are `03/07/2026`, forcing "is this today?" math. |
| 7 | Flexibility & Efficiency | 1 | Zero keyboard shortcuts, no quick-restart, no bulk, no pagination. |
| 8 | Aesthetic & Minimalist | 3 | Redundant page-header subtitle; long descriptions + separators wrap into noise. |
| 9 | Error Recovery | 2 | Inline-edit error block can render off-screen in a long list; no scroll-to-error. |
| 10 | Help & Documentation | 2 | Duration format & split bounds live only in vanishing placeholders. |
| **Total** | | **24/40** | **Acceptable — solid bones, real holes in power-user & mobile paths.** |

## Anti-Patterns Verdict — does this look AI-generated?

**No.** Deterministic scan and design review agree on quality: detector returned **zero findings** across every markup file (stub + real); z-index scale is a disciplined 10/5; no gradient text, glassmorphism, side-stripe, stray hex, or rogue `!important` (the only four are the canonical `prefers-reduced-motion` reset). Token system, two-state timer bar, small clean Stimulus controllers read as considered, not scaffolded. A Linear/Raycast-fluent user would trust it.

Slop that leaks is behavioral, not decorative (invisible to a CSS detector):
- Redundant header narration (restates the screen).
- Affordance collapse: "Adicionar manualmente", the `⋮` menu, and "Tags" all render as the same `btn--quiet btn--sm` chip.
- Undefined classes rendering as unstyled divs.

Detector caught + review corroborated: touch targets. Review caught, detector can't: the above. False positives dropped: `__eyebrow` uppercase micro-label (intentional, Linear-idiomatic), sidebar `border-right` (1px structural divider), `#9aa0ac` in a comment. No browser overlay — Rails app needs auth, no server in this env (detector is the required part and it ran).

## What's Working

1. **Two-state timer bar is genuinely good.** Idle vs running are distinct modes, not a button swap. Turbo-frame `src: timer_path` means it never shows stale state on load — delivers "the timer bar is sacred."
2. **Day-grouped list with daily totals hits the density target.** Date header + right-aligned `tabular-nums` total, 32px between days, 1px row dividers — rhythm without a single card/shadow. The Linear-dense aesthetic, achieved.
3. **Stimulus controllers minimal and correct.** `stopwatch`, `duration_fields` (parses "2:30"/"2h30"), `menu` (Escape + focus-return). Small, DOM-only, no leaks.

## Priority Issues

**[P1] Touch targets ~25–36px on mobile — below the 44px floor.** (both assessors)
`.btn--sm` = `4px 8px` + 12px text ≈ 25px; `⋮` menu, "Adicionar manualmente", "Tags", inline Save/Cancel all use it. Tab bar ~33px; Start/Stop `.btn` ~36px. On mobile `⋮` is the only path to edit/delete. Fix: `@media (max-width:48rem){ .btn.btn--sm{ min-height:2.75rem; padding: var(--space-2) var(--space-3);} }` + 44px min-height on tab bar / primary `.btn`. → `/impeccable adapt`

**[P1] Timer bar sits at the top on mobile — the thumb-hostile zone.** (A)
The signature control is anchored top ~80px on phones, and scrolls off entirely when the manual-entry `<details>` opens — no visible Stop. Contradicts principle #1. Fix: dock a compact timer control into/above the bottom tab bar, or make `.shell-timerbar` sticky. Design decision — flag, don't auto-fix. → `/impeccable adapt`

**[P1] No keyboard shortcuts, no quick-restart, no pagination.** (A; heuristic #7 = 1/4)
Start/stop mouse-only; "Duplicar" is 3 clicks deep; `home#show` loads full history unpaginated (`authorized_scope(TimeEntry.all)`). Biggest functional gap for a daily tool. Fix: global keydown Stimulus (focus description + start), one-click "restart last entry" on idle bar, windowed/paginated history. → `/impeccable shape`

**[P2] Undefined classes render as unstyled divs.** (A, verified: 0 CSS defs, used in views)
`tracker-entry__main`, `tracker-entry__tags`, `tags-field__chips` in markup, in no stylesheet. Block flow stacks them so not visibly broken today — but summary/tag spacing is accidental and `.tag-badge`'s `margin-left` double-gaps in the undefined flex chip container. Fix: define in `tracker.css` (`__main`: flex column, gap --space-1, min-width:0; `__tags`: flex wrap). → `/impeccable layout`

**[P2] Day labels lack "Hoje"/"Ontem".** (A, verified: `date.strftime("%d/%m/%Y")`)
Two most-accessed groups force date math, every session. Fix: relative label for today/yesterday, absolute for older. → `/impeccable clarify`

**[P2] Dead stub `time_entries/index.html.erb` should be deleted.** (both; verified HTML index action `redirect_to home_path`)
Never rendered, references classes in no CSS, copy admits it's a slice artifact. Fix: `git rm app/views/time_entries/index.html.erb`. → trivial.

## Persona Red Flags

- **Alex (power user):** no start/stop hotkey; "restart last" is 3 clicks; unpaginated list degrades at 500+ entries. Nothing rewards fluency.
- **Sam (a11y):** focus ring solid AA, `⋮` has real `aria-label` — good. Running signal leans on accent color but **mitigated**: `tracker_entry_time_range` prints "Rodando" as text (verified), so not color-only. Nested `<details>` makes a long keyboard tab-path; pending-chips order not announced meaningfully.
- **Casey (mobile one-handed):** the P1 pair bites hardest — Start/Stop at top, ~25px `⋮`, Stop scrolls out of view when manual form open.

## Minor Observations
- Redundant `page-header` subtitle — cut it.
- Stopwatch SSRs `00:00:00` before JS; seed `tracker_duration(Time.current - started_at)` to read correctly pre-hydration.
- No `<datalist>` on the description field (repeat-work autocomplete).
- Empty state points at no action — the only start control is the bar above it.

## Questions to Consider
1. Was the timer bar's top placement on mobile a decision or a default? It's the one thing contradicting "the bar is sacred."
2. Should there be one-open-panel-at-a-time coordination across the five `<details>`?
3. The billable amount is "the main deliverable," yet the row shows no billable/rate signal — is a logged hour's worth invisible on purpose?
