# Rootwork

> "Remain in me, and I in you. As the branch can't bear fruit by itself, unless it remains in the vine, so neither can you." John 15:4

A daily place to **pray, read, write, and remember** for born-again Christians who want their faith at the root of the day instead of in scattered places. Twenty minutes, the same six steps, every morning.

**Name:** *Rootwork* is the app and the daily practice ("did you do your rootwork?"). *Abide* is the brand promise. Ranks, badges and copy use vine and armor language.

---

## Design direction (v2, Oct 2 2026)

- **Native first.** SF Pro for UI, New York (system serif) for Scripture and your own words. System grouped backgrounds and label colors. Glass only on controls that float above content (tab bar, toolbar, buttons on the verse art), never on content cards.
- **The Trinity is the structure.** Father → Pray, Son → Read, Spirit → Write. Daily progress is three overlapping rings: gold (Father), crimson (Son, also the red letters), sky (Spirit). Steps 1 and 6 fill Pray, step 2 fills Read, steps 3–5 fill Write.
- **Tabs:** Today · Bible · Pray · Journal · Sword. "You" (streak, rank, brothers, app lock) sits in Today's toolbar.
- **Imagery:** public-domain masterworks (Rublev, Bloch, Bierstadt, Church) plus generated landscapes behind the verse of the day. Art is content and gets full bleed; it never sits behind UI as decoration.
- **Codename:** Rootwork. Final name to be decided ("Rootwork" also names hoodoo folk practice; "Abide" is taken by Guideposts).
- **Reading plan (from the walking guide):** Luke → Acts → John → Mark; then Romans, Galatians, Ephesians, Philippians, James, 1 John; then Genesis, Exodus. Alongside: one Psalm and the Proverbs chapter for the date.

## The problem (Bryan's own stack today)

| Where faith lives now | What it does well | What breaks |
|---|---|---|
| YouVersion | Morning verse push, evening streak nudge, badges, a great reader | Generic plans and courses, not *your* plan |
| Physical Bible | Highlights, tangible, Luke 10 bookmark | Not with you; nothing reminds you |
| Walking guide (Claude artifact) | Tactical verses, the plan, what you're learning | A document you have to go open |
| Slack DM to self | Fast place to write prayers | Prayers vanish into scrollback; sharing means screenshot → text Ricky |
| Live Free podcast, The Chosen | Auditory and visual ways in | Disconnected from what you read today |
| Church / elders | | Missing: no spiritual father |

Rootwork doesn't replace all of these. It becomes **the one place you go first**, and it points out to the others.

## The daily rhythm (the core loop)

Bryan's rhythm, mapped onto the armor of God (Ephesians 6), with one piece per step:

| # | Step | Armor | In the app |
|---|---|---|---|
| 1 | **Pray first.** Psalm 119:18 or the morning thanks | Shield of faith | Pick an opener prayer, say Amen |
| 2 | **Read one chapter** | Belt of truth | Reader on your plan; Listen for auditory learners |
| 3 | **Write one verse** that stood out | Sword of the Spirit | Tap it; it's saved to your Sword |
| 4 | **What it shows about God and about you** | Helmet of salvation | Two short fields |
| 5 | **One action today** (James 1:22) | Shoes of the gospel of peace | Commitment, saved as a vow |
| 6 | **Pray the verse back** | Breastplate of righteousness | Auto-drafted from your own words, then edited |

Evening: **Night watch** (give thanks, confess, lay it down). Eph 6:18: "pray in the Spirit on all occasions."

## The wedge

App locking alone is Prayer Lock's feature, and it only gets someone through the door once. The wedge is three things that work together:

1. **The Gate.** Games and social apps rest every morning until Rootwork is done. This creates the habit. (Screen Time API: FamilyControls + ManagedSettings + DeviceActivity.) Three emergency unlocks a week.
2. **The Remembrancer.** "The Holy Spirit will remind you of all that I said to you" (John 14:26). Your own prayers, vows and verses come back to you at the right moment: when you're anxious, grieving, tempted, or snarky in the morning. Nobody else has your Slack thread, and no generic Bible app knows what you vowed in August.
3. **The Sword.** Verses filed by the battle they fight (Anxiety, Grief, Temptation, Fear of man…), next to what *you* wrote when you faced it. Plus one memory verse a week.

The Gate gets you to open the app. The Remembrancer and the Sword are why you keep coming back after you stop needing the Gate.

## Gamification without legalism

- **Streaks with mercy.** If you miss one day and return the next morning, the streak holds (one mercy day per rolling week). Lamentations 3:22–23. A streak that shames you sends you away from the app.
- **Fruit** (XP): Rootwork +10, Night watch +3, sharing a prayer +2, memorizing a verse +15.
- **Ranks:** Seeker → Follower → Disciple → Laborer → Ambassador → Elder. "Elder" unlocks *becoming* a Paul to someone.
- **Badges:** Sower, First fruit, Two by two, Swordsmith, Full armor ×30, Finished Luke.

## Screens

1. **Today** shows the streak, the Rootwork card (6 steps), the armor, the Gate status, *From your own hand* (Remembrancer), the memory verse, and Night watch.
2. **Word** is a YouVersion-grade reader: big serif type, tap a verse to highlight, note, copy, share, send to Sword, or listen. It follows your plan: Luke → the other Gospels → Acts → Paul → Torah → Prophets.
3. **Thread** is your prayer book as a Messages thread. Prayer, Reflection, Confession (private, marked "brought to him · 1 John 1:9"), Vow, and Verse. Long-press to share with a brother. Seeded with your Slack prayers.
4. **Sword** has the memory verse, battles, verses, and your own words for each battle.
5. **Fellowship** has 3 brother slots (Ricky, wife…), shared prayers, a Sunday online church reminder (Live Free), companion media, and **Walk with an elder**.

## Walk with an elder (Paul & Timothy)

A matchmaking marketplace that connects younger believers with vetted older Christians for a call, a text, or a walk. It's the hardest piece to get right, so it ships **last**:
- Elder requirements: background check, pastor/church reference, safeguarding training, years walking with Christ.
- Timothy requirements: 14 days of Rootwork and an intro note before booking. First meetings happen in public places. Same-gender pairing by default. In-app messaging is logged and reportable.
- Elders set their own availability and prerequisites. Start unpaid and church-partnered. Paid models come later, if ever.

## Bible text

| Source | Notes |
|---|---|
| **YouVersion Platform** (recommended for production) | REST API plus a **Swift SDK** with SwiftUI components. 1,400+ versions including NIV. Same text Bryan reads today. |
| bible-api.com (used in prototype) | Free, no key, public-domain WEB/KJV. Fine for building. |
| API.Bible / ESV API | Alternatives; ESV is free for non-commercial use with limits. |

Read-aloud uses on-device `AVSpeechSynthesizer` now. Licensed audio Bibles can come later through the platform.

## Build plan

| Phase | Ships | Why first |
|---|---|---|
| **1 · Just for Bryan** (2–3 wks) | Rootwork flow, reader, Thread (seeded), Sword, local streaks, notifications | Use it yourself every day for a month. Iterate. |
| **2 · The Gate** | Family Controls shield + morning schedule | Requires Apple's Family Controls *distribution* entitlement. Apply early, since approval takes time. |
| **3 · Brothers** | Accounts, 3 slots, share prayers, "prayed ✓" receipts | First network effect: your brother, your wife, your mom. |
| **4 · Remembrancer v2** | On-device tagging of new entries by battle; resurfacing tuned by time of day and recent entries | Deepens the wedge. |
| **5 · Elders** | Vetting, profiles, scheduling, safety | Only after trust and moderation exist. |

## What's in this repo

- `prototype/rootwork.html` is the clickable prototype (published as an artifact). `python build.py` rebuilds it from the template plus `data/`.
- `ios/` is the native SwiftUI app (iOS 26, Liquid Glass, SwiftData). On a Mac: `brew install xcodegen && cd ios && xcodegen && open Rootwork.xcodeproj`.
  - Targets: `Rootwork` (app), `GateMonitor` (re-rests apps at 4 AM), `GateShield` (custom "Abide first." shield).
  - `ios/tools/gen_seed.py` regenerates the seed prayers and verses.

## Open questions

- The **walking guide** artifact lives in a claude.ai chat, which this session can't open. Paste it in, or republish it as a standalone artifact, and its verses and plan can become the starting Sword and reading plan.
- Should Rootwork take the place of YouVersion for reading, or hand off to it? (The prototype assumes it takes its place.)
- How sharing works: send a prayer to a brother inside the app, or also as a nice image card for iMessage?
