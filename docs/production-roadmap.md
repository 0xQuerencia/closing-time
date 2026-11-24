# Closing Time — production execution specification

Companion to the November 24 production bible (sections 1–5). Canonical setting: Bellwick, Route 9, November 24–25, 2006. Jamie Walker works at Marlow's Market; Evan Miller's disappearance and the financial records are the mystery. No supernatural twist. All asset work must be authored for this project or verified as the owner's original work.

## 6. Chapter implementation and pacing

| Chapter | Target | Mandatory sequence | Optional discoveries |
|---|---:|---|---|
| Prologue | 30 sec | Retrospective text with skip; no lengthy logos | — |
| 1. Apartment | 5 min | Dina's request, keys, vest, exit | rent notice, Kay photo |
| 2. Old Route 9 | 5 min | car entry, guided drive, park, arrival; accessibility skip carries same flags | bypass sign, radio |
| 3. Handover | 8 min | Dina walks through checkout and office, Mara sale, cooler count | opening photo, schedule, Evan photo, Mara memory |
| 4. Routine | 10 min | Ben sale/coffee, Nora directions/payment, Gus delivery discrepancy, restock | Ben memory, bypass clipping, delivery note, locker note |
| 5. Closing | 9 min | Ruth sale, Leon first visit, cash drop, trash, latch, Leon second visit | circular, termination, missing notice, notebook, ledger, binder, key log |
| 6. Outage | 9 min | alert, choose power or safety route, open safe route | DVR, Dina statement, Arthur message, maintenance log, wet prints |
| 7. Leave | 6 min | valid exit, guarded rescue, or caught | evidence handoff if safely possible |
| Epilogue | 1–2 min | consequence card and apartment reuse; skip after reading | newspaper follow-up |

These are experience targets, not timer gates. A first playthrough target is 45–60 minutes; the measured result determines whether more content or shorter tasks are needed. Fast playthrough may be 30–40 min. Optional clues must never be required for survival. Do not force the player to investigate during pursuit.

## 7. Dialogue direction and script seeds

Full dialogue trees are implemented as data with stable IDs, choice text, next IDs, once-only events, and optional flags. The following beats establish voice; extend them with task-specific contextual lines, not repetitive exposition.

- Dina, handover: "Register's already counted. If the cooler says twelve and you see eleven, write eleven. Don't fix the sheet for them." Jamie: "Who's them?" Dina: "Management. Anyway, the rear latch sticks."
- Kay, apartment: "You owe me breakfast if you're working again." Jamie choices: "I'll be home after one" / "You buying?" Both retain the safety check-in later.
- Mara: "Evan knew which tea I bought without looking. You new here?" Jamie can ask about Evan or continue checkout. Mara: "Haven't seen him since August. Hope he's all right."
- Ben: "Coffee still on?" On optional question: "Kid who used to work here said he had a meeting after close. Good kid." 
- Nora: "Where'd you move the batteries? I have to get home before my roommate locks me out." Ordinary customer, no ominous delivery.
- Gus: "Sign for what I actually brought, not what the sheet says. Been getting calls about that all month."
- Ruth: "Just milk. Long night." Optional: "Your manager looks exhausted. Tell her she needs a day off."
- Leon, first visit: "You got a new person every week now?" / "There a box of old employee stuff in back?" Jamie: "I'll have to ask Dina." Other choices are equally survivable.
- Leon, second visit: "I used to work here. I know where everything is. I just need you to let me look." He leaves visibly unsettled when access is denied.
- Arthur: "Employee records are private. Don't discuss the August incident with customers."
- Dina, after anomaly: "I saw Evan come back that night. They told me he'd left. Jamie, if someone's there, forget the paperwork and get out."
- Kay, danger: "You don't have to finish the shift. Call someone. Please."
- Dispatcher: short responses confirming location and advising immediate safety. No investigation objectives while the threat is active.
- Survivor Jamie: "I thought leaving would mean I'd failed at something. It took me a long time to understand the shift was never more important than getting home."

No modern slang, social apps, lengthy monologues or copied dialogue. The chapter JSON currently contains evidence text; full interactive trees and message choices remain implementation tasks.

## 8. Evidence and story items

Twenty-four IDs live in production_story.json. The six substantive categories are town, witness, records, cover_story, access, timeline; life details humanize the cast. Evidence records are immutable content; discovery events are saveable, idempotent and optional. Each item has an authored physical location, interaction prompt, readable transcript and optional narrative reaction. The binder and DVR or Dina corroboration enable the strongest ending only if evidence can be preserved without a mandatory risky detour. Do not show completion percentages during danger.

Physical item requirements: original paper layouts for ledger, missing notice, schedule, notebook, key log and circular; an original CRT clip or authored low-cost sequence; photographed-style project-original staff imagery; world-space readable props with larger accessible inspection text.

## 9. Systems and contracts

- ChapterProgress owns ordered events, required checks, optional discovery, restore validation and ending IDs; a session coordinator owns scene transitions. Never mark a task finished because a timer expired.
- Input router owns mouse capture and pause. World controller uses InputMap actions; phone, dialogue, CCTV and menus acquire exclusive focus; Escape and browser focus loss release capture. Test no duplicate key handling.
- Customer profiles are data-driven. Each has entrance, browse, request, checkout/payment, exit, optional contextual dialogue. Use original character rig and clear path markers. Deliveries are not forced to behave as retail purchases.
- Shift tasks use explicit event IDs: stock, cooler count, delivery verification, cash drop, trash, latch. Supply recoverable item placements, no duplicated progress after restore.
- Save snapshots contain schema, chapter, event IDs, evidence, settings and location-specific checkpoint data. Restore validates earlier required events and refuses future or duplicate IDs; browser persistence failure is reported. Never serialize arbitrary scene objects.
- Phone: period feature-phone design, inbox, readable SMS, replies, silent mode, archive and separate accessible transcript. Preserve messages across chapters.
- CCTV: one live camera viewport when viewing, 320x240 target, bounded authored archive, no continuous readback/JPEG loop. Evidence accessible without requiring every feed.
- Ending resolver consumes actual exit, rescue/safety state and evidence; no free win after an arbitrary countdown. A timer may signal approaching help, never replace safety conditions.
- Accessibility: subtitles for critical sounds, readable type, remappable controls, independent audio sliders, toggle sprint, camera bob and VHS off, reduced flashes, optional drive skip, no required microphone.

## 10. Tension and endings

Ordinary cues become meaningful: rain, door chime, refrigerator hum, familiar customer routes, a changed object, then a clear credible intrusion. No constant jumpscares. Leon's threat transitions: away, seen, suspicious, searching, pursuing, recovering; player-visible sound and movement cues, fair hiding and doors. Do not spawn him in view or teleport. A checkpoint before danger is required.

- Escaped: Jamie reaches a valid safe exit; records may be incomplete.
- Rescued: help arrives after valid contact and a sustained safe state; never a timer-only victory.
- Evidence preserved: safe survival plus binder and corroboration; investigation reopens, no guaranteed conviction.
- Caught: neutral incident card; no survivor narration, clear retry from checkpoint.

## 11. Art and audio production

Original-only policy: retain verified original market geometry, generated labels, surfaces, props and synthesized sounds; replace imported NPCs, motion, office props, electronics, car, retro props, footstep recordings, fonts and any unverified material. Do not substitute another external asset pack. Existing owner-authored house assets can be reused only if verified; absence of search results is not proof of absence. Keep original credits until actual removal. Record source path, author, generator, seed and derived asset references.

Targets are planning budgets until measured: NPC 1,500–3,000 triangles each, 256/512 atlas, shared original skeleton; hero props 100–700 tris; static fixture batches; world textures 128–512; no expensive real-time reflection probes. Use one shared material per surface family, small texture atlases, nearest filtering, low-res 3D viewport separate from readable native UI. Use weather silhouettes, grounded worn materials and period-specific props. Avoid generic stylized blockout as final art. Character models must have original source and usable exported rig/animation; image concept art is not a game asset.

Audio: original recordings or deterministic synthesis; variations for dry/wet footsteps, door/checkout cues, compressor, rain, ventilation, radio static and distant traffic. Use spatial attenuation and room tone; no borrowed music or recordings. Original UI type design or project-authored bitmap glyph set; do not remove credited fonts before usable replacement is tested.

## 12. Browser architecture and performance

Godot 4.6.3 Compatibility, single-threaded Web export, explicit JSON inclusion. Target WebGL 2 desktop Chrome/Firefox, itch embed; keyboard/mouse capture after user gesture. No network services. Test focus loss, re-entry, browser audio unlocking, fullscreen, resizing and storage. The package script must verify index HTML/JS/WASM/PCK and compressed size <=80 MB. The 60 MB transfer goal is separate and measured. Profile on a defined integrated-GPU device and on the owner's machine; report actual frame time, memory, draw calls and tri counts, never estimates as measurements. Target sustained 30 FPS on defined low-end hardware and 60 FPS on stronger systems.

## 13. PR sequence and acceptance

Use the current default branch ui-pass until a deliberate integration decision. Keep PR titles and bodies short. Draft until runtime and visual checks pass. Independent asset work may proceed in parallel; stacked chapters retarget after prerequisites merge.

| Phase | PR slice | Definition of done |
|---|---|---|
| P0 | Web foundation | Compatibility, export preset, CI, real ZIP and import/validation results |
| P0 | Baseline measurements | scripted timings, actual metrics and reproducible report |
| P0 | Chapter/evidence core | schema, events, restore and tested four outcomes |
| P0 | Input and focus | one owner, action bindings, pointer lock/focus tests |
| P0 | Session/save coordinator | chapter transitions, atomic snapshots, migration/recovery |
| P1 | Original asset inventory | all used/bundled assets traced, unknowns fail release |
| P1 | Original office props | replace all references, visual review, collision compatibility |
| P1 | Original foley | dry/wet variants, original source, remove imported recordings |
| P1 | Original character bodies | owner-authored mesh, UVs, textures, shared rig |
| P1 | Original animation library | idle, walk, turn, talk, browse, reach, carry, pay, door; chase/search for Leon |
| P1 | Original vehicles and exterior | replace wagon and any imported embedded meshes, original source |
| P1 | Original typography and remaining props | replace imported fonts and props, source and accessible glyphs |
| P2 | Apartment opening | actual room, collision, interactions, first-person navigation and checkpoint |
| P2 | Route 9 | playable drive, original car interior and safe skip |
| P2 | New Game integration | prologue -> apartment -> road -> handover; no preview-only flag |
| P3 | Dina and Mara handover | tutorial, checkout, cooler, optional memories |
| P3 | Ben/Nora/Gus routine | differentiated service/delivery and authored dialogue |
| P3 | Ruth/Leon closing | two Leon visits gated by real tasks; no short timer shortcut |
| P3 | Phone and evidence presentation | SMS choices, 24 inspectables, six evidence categories |
| P4 | CCTV and outage | one live feed, archive clip, power choice and route |
| P4 | Threat and endings | fair AI, validated rescue/exit, evidence ending, retry |
| P4 | Epilogue | branching newspaper and apartment, failure without narrator |
| P5 | PSX visual direction | low-res world viewport, lighting/material consistency, original textures |
| P5 | Sound and accessibility pass | critical cues, subtitles, remapping, settings persistence |
| P5 | Optimization | measured performance, memory, ZIP budgets, render regression |
| P6 | Full playthrough QA | blind playtests, all four outcomes, save/restore and optional clues |
| P6 | Browser/itch release | reproducible Web build, live browser test, original-only asset audit |

Estimates are planning effort, not promises: P0 3–5 development days, P1 8–15, P2 4–7, P3 7–12, P4 5–8, P5 5–10, P6 3–5. Work can overlap where dependencies permit. Visual and playtest rework is not included.

## 14. QA and release gates

Existing tests must remain or be intentionally migrated when design changes. Add deterministic unit tests for chapter gates and saves; integration tests for customer paths, tasks, evidence, phone, CCTV, doors and endings; browser smoke tests for input/audio/focus and persistence. Run actual blind first-time playthroughs, record durations and blockers, and measure the defined hardware target. Confirm original-only release contents, not merely that imported assets are unused at runtime. No broken interactions, missing clues, softlocks, placeholder character animation or accidental third-party files. A successful CI export alone does not establish a finished game.

## 15. Implementation agent rules

Inspect live branch before edits; use small reviewable PRs. Do not force push or delete original source assets until replacements are validated. No paid or downloaded asset packs, no copied game dialogue, no modern UI gimmicks. Never claim tests, FPS, playtime, rendered previews or merges without evidence. Maintain this checklist alongside actual PR links. Integrate only when prerequisites and acceptance checks are satisfied.
