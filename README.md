[![Discord](https://img.shields.io/discord/1319915996789739540?label=chat&logo=discord&style=flat)](https://discord.gg/q4d3ggrFVA)
![Coding hours](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/ni/actor-framework/metrics/badge.json)

# 🧩 Actor Framework





> **Actor Framework 2.0.0.18  ·  Released 24 Apr 2025**\
> *Back-ported from LabVIEW 2024 Q3 for LabVIEW 2020 or later*

## ✨ What’s New

| #  | Feature                                                                                                                                                                   | Why it matters                                                                                                 |
| -- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
|  1 | **AF Debug.lvlib merged into Actor Framework.lvlib** — DETT tracing is now encapsulated in `DETT Format.lvclass` implementing `Trace Format.lvclass`.                     | Consolidates debug utilities into a single library and makes it easier to extend trace formats.                |
|  2 | **`Generate Trace.vi`**\*\* loads trace formats dynamically\*\* (defaults to `DETT Format.lvclass`; override via `AFDebugTraceFormat` INI token).                         | Plug-in architecture lets you swap in custom trace sinks without recompiling the framework.                    |
|  3 | **Automatic actor registration** — `Actor.vi` no longer sends *Register Actor Msg*; registration is performed inside `Actor Core.vi` just before message handling begins. | Removes boilerplate and speeds up actor startup.                                                               |
|  4 | **`Stop Autostop Nested Actors.vi`** (protected)                                                                                                                          | Gives parent actors a “rogue-child panic button” to halt all autostop children while the parent keeps running. |
|  5 | **Testing Support Palette** — Adds `Launch Actor.vi`, `Init Actor Queues FOR TESTING ONLY.vi`, and `Test Launch for Nested Actor Without Caller.vi`.                      | Enables fast, headless unit testing of actors in CI pipelines.                                                 |
|  6 | **Enqueuer / Last-Ack controls & constants now on palettes**                                                                                                              | Makes common datatype constants drag-and-drop accessible in development.                                       |
|  7 | **Improved PPL build experience** — Specialty messages (Batch, Reply, Report Error, Self-Addressed) are now inside libraries; legacy copies are deprecated.               | Simplifies PPL builds and avoids duplicate symbol errors.                                                      |

*For  expanded notes, and a list of breaking changes, see the full [2.0.0.18 release page](https://github.com/ni/actor-framework/releases/tag/v2.0.0.18).*

---

## Overview

Actor Framework (AF) is NI’s reference implementation of the Actor Model in LabVIEW. It enables large-scale, message-oriented applications with asynchronous actors that can be launched, monitored, and shut down predictably. This repo is the **canonical upstream** for AF beginning with v2.x and is maintained under the MIT license.

- **Primary LabVIEW target:** 2020 SP1 or later (32- & 64-bit)
- **Package format:** VIPM (`.vip`) built by GitHub Actions for every merge to `main` and tagged release.

---

## Getting Started

1. **Install the latest package** from the [Releases](https://github.com/ni/actor-framework/releases) page or drag-and-drop the `.vip` onto VIPM.
2. Open `Examples/Actor Framework/` in LabVIEW to explore sample projects.
3. For IDE palette integration, restart LabVIEW after installation.

---

## Contributing

We welcome both code and non-code contributions — bug fixes, performance tweaks, documentation, testing, and discussion.

### Ways to Help

- **Report a bug** — Found something broken? [Open an issue](https://github.com/ni/actor-framework/issues/new?template=bug_report.yml)
- **Suggest a feature** — Have an idea? [Submit a feature request](https://github.com/ni/actor-framework/issues/new?template=feature_request.yml) or start a [Discussion](https://github.com/ni/actor-framework/discussions)
- **Join discussions** — Share your expertise in [GitHub Discussions](https://github.com/ni/actor-framework/discussions) or on [Discord](https://discord.gg/q4d3ggrFVA)
- **Test changes** — Install pre-release packages and [report your findings](https://github.com/ni/actor-framework/discussions/100)
- **Improve documentation** — Fix typos, clarify instructions, or update the Wiki
- **Write code** — Fix bugs, implement features, or improve performance

All code contributors must sign NI's **Contributor License Agreement (CLA)** once per GitHub account — a bot will prompt you on your first pull request.

👉 **See [`CONTRIBUTING.md`](CONTRIBUTING.md) for the full contribution guide**, including branching strategy, coding standards, VI Analyzer requirements, and the step-by-step PR workflow.

---

## Governance & Communication & Communication

Actor Framework follows the same open-governance model as the LabVIEW Icon Editor:

- **Technical Steering Committee (SteerCo):** NI staff & community architects oversee roadmap and reviews.  
- **BDFL:** NI retains final decision power for major direction changes.  
- **Discord:** Join the **NI Open Source Discord** for real-time chat.

---

## License

This project is licensed under the **MIT License**. By contributing, you agree to license your work under these terms so NI and the LabVIEW community can incorporate it into future LabVIEW distributions.

---

## Acknowledgements

We thank the LabVIEW community & the contributors who made Actor Framework 2.0 possible. Special thanks to @niACS, @CaseyZS, for leading the 2024 Q3 back-port initiative.

---
