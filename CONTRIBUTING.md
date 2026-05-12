# Contributing to Actor Framework

We welcome both code and non-code contributions — everything from bug reports and testing to documentation improvements and feature development.

---

## Table of Contents

- [Ways to Contribute](#-ways-to-contribute)
- [Getting Started](#-getting-started)
- [Reporting Bugs](#-reporting-bugs)
- [Suggesting Features](#-suggesting-features)
- [Joining Discussions](#-joining-discussions)
- [Testing](#-testing)
- [Contributing Code](#-contributing-code)
  - [Contributor License Agreement (CLA)](#contributor-license-agreement-cla)
  - [Development Setup](#development-setup)
  - [Branching Strategy](#branching-strategy)
  - [Standard Feature Workflow](#standard-feature-workflow)
  - [Pull Request Guidelines](#pull-request-guidelines)
- [Coding Standards](#-coding-standards)
  - [General LabVIEW (G Code) Guidelines](#general-labview-g-code-guidelines)
  - [Making Changes to G Code](#making-changes-to-g-code)
  - [Module Boundaries](#module-boundaries)
  - [VI Analyzer Tests](#vi-analyzer-tests)
  - [Mass Compilation](#mass-compilation)
- [CI/CD Pipeline](#-cicd-pipeline)
- [Review Process](#-review-process)
- [Repository Structure](#-repository-structure)
- [Governance](#-governance)
- [Communication Channels](#-communication-channels)

---

## 🤝 Ways to Contribute

You don't need to write code to make a meaningful contribution. Here are all the ways you can participate:

| Contribution | Description |
|---|---|
| **Report a bug** | Found something broken? Open a bug report issue |
| **Suggest a feature** | Have an idea? Submit a feature request or start a discussion |
| **Join discussions** | Share your expertise in GitHub Discussions or on Discord |
| **Test changes** | Install pre-release packages and validate fixes in your environment |
| **Improve documentation** | Fix typos, clarify instructions, add examples, or improve the Wiki |
| **Write code** | Fix bugs, implement features, improve performance, or submit tweaks |

---

## 🚀 Getting Started

1. **Explore the repo** — Browse the [README](https://github.com/ni/actor-framework#readme) to understand the project
2. **Check open issues** — Look at [Issues](https://github.com/ni/actor-framework/issues) for things to work on, especially those labeled [`Workflow: Open to Contribution`](https://github.com/ni/actor-framework/issues?q=is%3Aissue+state%3Aopen+label%3A%22Workflow%3A+Open+to+contribution%22)
3. **Join the conversation** — Introduce yourself on [Discord](https://discord.gg/q4d3ggrFVA) or [GitHub Discussions](https://github.com/ni/actor-framework/discussions)

### Prerequisites

- **LabVIEW** 2020 SP1 or later (32-bit or 64-bit)
- **VIPM** (VI Package Manager) for installing and building `.vip` packages
- A **GitHub account**

---

## 🐛 Reporting Bugs

If you find a bug, please [open a bug report](https://github.com/ni/actor-framework/issues/new?template=bug_report.yml):

- Use a clear, descriptive title
- Describe the steps to reproduce the issue
- Include the LabVIEW version, OS, and Actor Framework version you're using
- Attach screenshots or code snippets if applicable
- Describe what you expected to happen vs. what actually happened

---

## 💡 Suggesting Features

Have an idea for an improvement?

1. **Check existing issues and discussions** first — your idea may already be proposed
2. [Open a feature request](https://github.com/ni/actor-framework/issues/new?template=feature_request.yml) or start a [GitHub Discussion](https://github.com/ni/actor-framework/discussions)
3. Describe the problem your feature would solve, your proposed solution, and any alternatives you've considered

The Steering Committee reviews feature proposals and labels approved ones as `Workflow: Open to Contribution`.

---

## 💬 Joining Discussions

GitHub Discussions is the place for design proposals, Q&A, and community conversation:

- Share use cases and real-world experience
- Provide feedback on proposed changes
- Ask questions about the framework
- Help other community members

Visit the [Discussions tab](https://github.com/ni/actor-framework/discussions) to get started.

---

## 🧪 Testing

Testing is one of the most valuable contributions you can make:

- **Test pre-release packages** — Install `.vip` builds from [Releases](https://github.com/ni/actor-framework/releases) and validate in your projects
- **Test open PRs** — Build and install packages from contributor forks to verify fixes
- **Submit test reports** — Use the [manual test report template](https://github.com/ni/actor-framework/issues/new?template=manual-test-report.yml) to document your findings
- **Report regressions** — If something that used to work is now broken, let us know

See the [Test Actor Framework 2.0](https://github.com/ni/actor-framework/discussions/100) discussion for current testing priorities.

---

## 💻 Contributing Code

### Contributor License Agreement (CLA)

You must sign NI's Contributor License Agreement **once per GitHub account** before your code can be merged. A bot will prompt you on your first pull request; if not, NI staff will reach out directly. The CLA is required for code contributions intended to ship with LabVIEW — it is not needed for issues, discussions, or testing.

### Development Setup

1. **Fork** the [actor-framework](https://github.com/ni/actor-framework) repository to your GitHub account
2. **Clone** your fork locally
3. Install LabVIEW 2020 SP1+ and VIPM
4. If you need a self-hosted runner for CI, follow the steps in [docs/self-hosted-runner.md](https://github.com/ni/actor-framework/blob/develop/docs/self-hosted-runner.md) *(guide in progress)*

### Branching Strategy

The repository uses a three-tier branching model aligned with the LabVIEW release cycle:

```
  Your Fork                        Upstream (ni/actor-framework)
  ────────                         ────────────────────────────

  your-branch ──► PR ──►           develop  (accepts contributions year-round)
                                      │
                                      │  March & September
                                      │  (~ 3 months before LabVIEW release)
                                      ▼
                                    main  (release-ready, final artifacts built here)
                                      │
                                      ▼
                                   LabVIEW Release
```

| Branch | Purpose | Who Merges |
|---|---|---|
| **`main`** | Release branch — final VIPM artifacts and distribution packages are built from here. Only updated twice a year. | Repo Owners / NI |
| **`develop`** | Integration branch — accepts community contributions year-round. This is where your PRs should target. | Repo Owners |
| **Your fork branch** | Your working branch — create feature/bugfix branches on your fork and submit PRs to `develop`. | You |

#### Release Integration Schedule

Changes from `develop` are promoted to `main` **twice a year**, approximately three months before each LabVIEW release:

| Integration Window | LabVIEW Release | What Happens |
|---|---|---|
| **March** | Q3 release (June/July) | Feature freeze on `develop`; approved changes merged to `main`; final artifacts built and validated |
| **September** | Q1 release (next year) | Feature freeze on `develop`; approved changes merged to `main`; final artifacts built and validated |

> **What this means for contributors:** You can submit PRs to `develop` at any time. Your changes will be reviewed, merged into `develop`, and then included in the next integration window when `develop` is promoted to `main`.

### Standard Feature Workflow

1. **Find or create an issue**
   - Check for issues labeled [`Workflow: Open to Contribution`](https://github.com/ni/actor-framework/issues?q=is%3Aissue+state%3Aopen+label%3A%22Workflow%3A+Open+to+contribution%22)
   - Or discuss your idea on [Discord](https://discord.gg/q4d3ggrFVA) / [GitHub Discussions](https://github.com/ni/actor-framework/discussions) first

2. **Get assigned**
   - Comment on the issue to let repo owners know you'd like to work on it
   - A repo owner will assign you and NI creates a feature branch in the upstream repo

3. **Develop**
   - Implement your changes on the `develop` branch of your fork
   - Follow the [coding standards](#coding-standards) below

4. **Build**
   - Build a VI Package using the [PowerShell build tool](https://github.com/ni/actor-framework/tree/develop/Tooling)
   - CI will also build a `.vip` and post it as a pre-release on your fork's Releases page
   - Note: the package from your fork will show your fork owner's name instead of "NI"

5. **Test**
   - Install the pre-release package in LabVIEW and verify your changes
   - Run existing unit tests to check for regressions
   - Document your test results

6. **Submit a Pull Request**
   - Open a PR targeting the **feature branch** in the upstream repo (not `main` or `develop` directly)
   - Fill out the PR template completely (see [PR Guidelines](#pull-request-guidelines))
   - Sign the CLA if prompted

7. **Review & iterate**
   - Repo owners and the Steering Committee review, test, and may request changes
   - Address feedback and push updates to your branch

8. **Merge & release**
   - After approval, your PR is merged into `develop`
   - During the next integration window (March or September), approved changes in `develop` are promoted to `main`
   - Final artifacts are built from `main` and ship in the corresponding LabVIEW release

### Pull Request Guidelines

Every PR must include:

- **Linked GitHub Issue** — reference the issue number
- **Summary of changes** — what was added, modified, or fixed
- **Reason for change** — the problem or need being addressed
- **Testing evidence** — manual and/or automated test results
- **Visual aids** — screenshots or diagrams if applicable

Use the appropriate PR template:

| Template | Use When |
|---|---|
| `bug_fix.md` | Fixing a bug |
| `feature_request.md` | Adding a new feature |
| `documentation.md` | Documentation-only changes |
| `infrastructure_change.md` | CI, build, or tooling changes |
| `empty_pull_request.md` | Anything that doesn't fit the above |

**PR Checklist** (from the template):
- [ ] Changes are based on the appropriate NI-repo feature branch
- [ ] PR targets the correct feature branch
- [ ] Built a VI Package using the PowerShell build tool
- [ ] Installed and tested the VI Package locally
- [ ] NI has your CLA on file

---

## 📐 Coding Standards

### General LabVIEW (G Code) Guidelines

- Follow **NI LabVIEW style guidelines** and Actor Framework design patterns
- Keep block diagrams **clean and readable** — use proper wire routing, avoid overlapping wires, and maintain left-to-right data flow
- Use **descriptive VI and class names** — names should clearly communicate purpose (e.g., `Send Message.vi`, `Handle Reply.vi`)
- Add **inline documentation** — use free labels and VI descriptions to explain non-obvious logic
- Keep VIs **small and focused** — each VI should do one thing well
- Use **type definitions** for clusters and enums that may change — this ensures updates propagate automatically
- Avoid **global variables and shared state** — prefer message-based decoupling between actors
- Ensure **deterministic actor lifecycle behavior** — actors must start up and shut down predictably
- Enforce **explicit message interfaces** — avoid circular actor dependencies
- Use **LabVIEW 2020 SP1** as the minimum save version to ensure backward compatibility

### Making Changes to G Code

Since LabVIEW code is graphical (G code), the workflow differs from text-based languages:

1. **Open the project** — Load the relevant `.lvproj` file in LabVIEW:
   - `Core/Actor Framework Core.lvproj` — for core framework changes
   - `Tooling/CI CD.lvproj` — for build and test tooling changes

2. **Locate the VI** — Navigate the project tree to find the VI you need to modify. The core framework lives under:
   - `Core/ActorFramework/` — main Actor Framework library
   - `Core/AFDebug/` — debug and trace utilities
   - `Core/Testing/` — test support VIs
   - `Core/Menus/` — LabVIEW menu integrations
   - `Core/Install Support/` — install-time utilities

3. **Edit the block diagram** — Make your changes following the style guidelines above

4. **Save for the correct LabVIEW version** — Always save VIs in a format compatible with LabVIEW 2020 SP1+

5. **Test locally** — Build and install the package using the PowerShell build tool in `Tooling/deployment/` before submitting a PR

> **Important:** LabVIEW files are binary, so standard text-based diffs don't work. Use clear PR descriptions and screenshots/visual aids to help reviewers understand your changes.

### Module Boundaries

Keep a clear separation between modules:

| Module | Location | Purpose |
|---|---|---|
| **Core** | `Core/ActorFramework/` | Core Actor Framework library — actors, messages, enqueuer |
| **Debug** | `Core/AFDebug/` | DETT tracing and debug utilities |
| **Testing** | `Core/Testing/` | Test support VIs (Launch Actor, Init Actor Queues, etc.) |
| **Menus** | `Core/Menus/` | LabVIEW palette and menu integration |
| **Tooling** | `Tooling/` | Build scripts, unit test runners, deployment utilities |
| **Providers** | `Providers/` | Extension providers |
| **Documentation** | `Documentation/` & `docs/` | Guides and documentation |

> ⚠️ Do not introduce cross-module dependencies without approval from the Steering Committee.

### VI Analyzer Tests

The CI pipeline runs **VI Analyzer (VIA)** tests on every PR to enforce code quality standards. The configuration is defined in `.github/via_config/Actor_Framework.viancfg`.

**How VI Analyzer runs in CI:**

- VI Analyzer runs in a **Docker container** with LabVIEW (Linux) via the `ni/open-source/via-lv-docker@actions` GitHub Action
- It analyzes **only the files changed in your PR** by comparing against the base branch (`develop`)
- On manual dispatch, it can analyze the full codebase using the `.viancfg` configuration
- Results are uploaded as an **artifact** (`vi-analyzer-report.htm`) you can download and review

**What VI Analyzer checks (typical rules):**

- Block diagram cleanliness and style compliance
- Proper error handling (unwired error clusters, missing error cases)
- Unused code (dead code, unreachable frames)
- Naming conventions for controls, indicators, and VIs
- Performance issues (unnecessary coercions, inefficient patterns)
- Documentation completeness (VI descriptions, connector pane usage)

**Running VI Analyzer locally before submitting a PR:**

1. Open LabVIEW and go to **Tools → VI Analyzer → Analyze VIs...**
2. Load the configuration file: `.github/via_config/Actor_Framework.viancfg`
3. Select the VIs you've modified
4. Run the analysis and fix any reported issues
5. Re-run until your VIs pass cleanly

> **Tip:** Running VI Analyzer locally before pushing saves CI time and avoids review delays. Fix all warnings and errors before submitting your PR.

### Mass Compilation

The CI pipeline also performs a **mass compilation** step to verify that all Actor Framework VIs compile successfully in a clean LabVIEW environment:

- A distribution artifact is built and overlaid into a LabVIEW Docker container
- `vi.lib/ActorFramework` is mass compiled using LabVIEW CLI
- Any compilation errors will fail the pipeline

This ensures your changes don't break the build for other users.

---

## ⚙️ CI/CD Pipeline

The repository uses GitHub Actions for continuous integration:

| Workflow | Purpose |
|---|---|
| `ci.yml` | Runs on PRs — validates builds and tests |
| `build-vi-package.yml` | Builds the VIPM package |
| `run-unit-tests.yml` | Executes unit tests |
| `run-via-tests.yml` | Runs VI Analyzer tests |
| `release.yml` | Creates tagged releases |
| `create-distribution-artifact.yml` | Generates distribution artifacts for LabVIEW integration |

> Your PR must pass **all CI checks** before it can be reviewed and merged.

---

## 📋 Review Process

Pull Requests are reviewed by repo owners and the Steering Committee:

- **Initial review** within 5–10 business days
- **Follow-up reviews** within 3–5 business days after revisions
- Once approved, PRs are merged promptly and queued for the next release cycle

---

## 📂 Repository Structure

```
actor-framework/
├── .github/              # CI workflows, issue & PR templates
│   ├── ISSUE_TEMPLATE/   # Bug report, feature request, manual test report
│   ├── PULL_REQUEST_TEMPLATE/  # PR templates by type
│   ├── via_config/       # VI Analyzer configuration
│   └── workflows/        # GitHub Actions CI/CD pipelines
├── Builds/               # VIPM package build configuration
├── Core/                 # Core Actor Framework libraries
├── Documentation/        # Framework documentation
├── Providers/            # Extension providers
├── Tooling/              # Developer tooling and build utilities (PowerShell)
├── docs/                 # Additional guides (e.g., self-hosted runner setup)
├── pipeline/             # Release pipeline scripts
├── reports/              # Community metrics and reports
├── LICENSE.txt           # MIT License
└── README.md             # Project overview and getting started
```

---

## 🏛️ Governance

Actor Framework is maintained under an open-governance model:

- **Technical Steering Committee (SteerCo)** — NI staff and community architects who oversee the roadmap, review architectural changes, and approve feature directions
- **Repo Owners** — Handle code review, CI validation, merge approvals, and release tagging
- **NI** retains final decision authority for major direction and architecture changes

---

## 📡 Communication Channels

| Channel | Purpose |
|---|---|
| [GitHub Issues](https://github.com/ni/actor-framework/issues) | Bug reports and feature requests |
| [GitHub Discussions](https://github.com/ni/actor-framework/discussions) | Design proposals, Q&A, community conversation |
| [Discord](https://discord.gg/q4d3ggrFVA) | Real-time community collaboration |

---

## License

Actor Framework is licensed under the [MIT License](https://github.com/ni/actor-framework/blob/develop/LICENSE.txt). By contributing, you agree to license your work under these terms so NI and the LabVIEW community can incorporate it into future LabVIEW distributions.
