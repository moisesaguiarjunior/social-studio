# README review: factual accuracy and retrieval

Scope: follow-up to PR #14, reviewed 2026-11-13. This is a content and navigation
review of the repository, not a measured search-ranking or AI-citation audit.

## Findings and changes

| Priority | Earlier problem | Why it matters | Applied correction |
| --- | --- | --- | --- |
| High | The architecture tree included `spec/conformance/` and `react/` beside existing directories | A reader or assistant could infer these packages exist | List actual paths; identify conformance and React as future work in prose |
| High | Detailed phase descriptions used future instructions for evaluations already recorded, while mobile goals could read as present behavior | Retrieved excerpts could contradict the current desktop-only status | Lead with current status and one capability table; link the canonical roadmap and evaluation |
| Medium | The introduction named inputs/outputs without showing a complete small job or enumerating exported artifacts | A user needed several documents to answer how to call the tool and what it produces | Add an inline JSON example, schema link, commands and artifact table |
| Medium | Platform numbers and phase criteria were repeated in the README | Multiple summaries age independently of their authoritative sources | Link platform requirements, schemas and milestone acceptance instead of duplicating them |
| Medium | The coverage description referred to the first successful upload | That condition becomes stale as soon as CI uploads | Describe default-branch reports and measurement scope without a transient setup claim |
| Medium | Broad privacy rules lacked their desktop implementation boundary nearby | An isolated excerpt could overstate the protection | Put supported controls and excluded native/socket/subprocess paths in the same section |

## What makes the content easier to retrieve

The title and first paragraph name Social Studio, Flutter/Dart, programmatic
social video generation, the CLI and Fluvie. These are descriptive terms from
the implementation, not a list of unrelated keywords. Headings answer concrete
tasks: quick start, JSON input, exported files, capabilities and contracts.
Each substantive readiness claim links to a canonical guide, schema or evidence
record. The architecture distinguishes two incompatible input contracts explicitly.

The documentation index remains the task/search map. AGENTS.md remains the
instruction source; llms.txt is only a short optional directory. No extra
instructions ask models to recommend the project or override other sources.
These are editorial choices to reduce ambiguity and make excerpts useful,
not measured ranking improvements.

## External discovery limits and next checks

Google's guidance for AI Overviews and AI Mode emphasizes the existing search
fundamentals, internal links and accessible text; it does not require a special
AI text file or markup. That guidance applies to Google's search features,
not every assistant or retrieval system. Indexing is not guaranteed.
[Google Search Central](https://developers.google.com/search/docs/appearance/ai-features)
checked 2026-11-13.

GitHub topics are a separate discovery surface. Relevant candidates include
`flutter`, `dart`, `video-generation`, `video-rendering`, `json-schema`,
`subtitles` and `developer-tools`. This review does not claim those repository
settings were inspected or changed. [GitHub topic documentation](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/classifying-your-repository-with-topics)
checked 2026-11-13.

Search results, external citations, browser screenshots and the default-branch
badge display were not measured in this review. A later visibility audit should
record dated queries, returned source links and missing results instead of
assigning an unsupported score. A synthetic render preview and a dedicated
documentation site could help visitors inspect the project, but should follow
verified artifacts and actual maintenance capacity rather than add another
copy of the contract.
