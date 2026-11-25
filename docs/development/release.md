---
description: "The maintainers' checklist for a module release: the release pull request, a walk through the docs, the tag, the approval for the PowerShell Gallery, the GitHub release and the checks before a release is complete; and the one-time setup."
---

# Releases

Only maintainers release. This page is their checklist. Each module has its own SemVer
`ModuleVersion` and `CHANGELOG.md` and is released on its own, from a tag `<Module>-v<Version>` on
`main`. A module that requires another one (a showcase app requires its component module) is
released after it: the gallery checks that the required version is there.

## Each release

### 1. The release pull request

- In the module's `CHANGELOG.md`, move the entries from `[Unreleased]` to `## [x.y.z] - YYYY-MM-DD`.
  Pick the version by [Versioning](../versioning.md). A prerelease (`x.y.z-rc1`) also sets
  `Prerelease` in the manifest's `PSData`.
- Set `ModuleVersion` in the module's manifest to `x.y.z`. The release stops when the tag, the
  manifest or the CHANGELOG section disagree.
- For a showcase app that uses something new of its component module, raise the minimum version in
  its `RequiredModules`, and release the component module first.
- Update [Upgrading](../upgrading.md). `tests/js/upgrading.test.js` checks it against the changelogs:
    - A new minor version with breaks: move the module's entries from "In the next release" into a
      section of their own for that version, in place of the module's section for the minor before.
    - A new minor version without breaks: remove the module's section for the minor before.
    - A patch release: nothing moves.
- Merge the pull request.

### 2. Walk through the docs with the built module

Build the module from the merge commit (`./build/Build-Module.ps1`, or the zip of a
[trial run](#trial-run)) and install it on a PSU instance. Follow
[Getting started](../getting-started.md) and the module's overview page as written. Fix what does not
run before you tag: a published version cannot be changed.

### 3. Tag

Wait until CI has passed for the merge commit on `main`. The release needs that green CI run and
fails otherwise; re-run it once CI is green. Then tag the merge commit:

```bash
git tag <Module>-vx.y.z && git push origin <Module>-vx.y.z
```

A tag on a commit that is not on `main` stops the workflow before anything is built.

### 4. Approve the publication

`release.yml` tests, builds and checks the module, then waits for approval in the environment
`psgallery`. Approve it there. It then publishes the module to the PowerShell Gallery.

After the gallery, the workflow creates the GitHub release with the zip, the CHANGELOG section and a
link to the version's page in the gallery. For a component module (not a showcase app, not a
prerelease) it also starts a discussion in Announcements. When a step fails, re-run the failed jobs:
each step skips what already exists.

### 5. Before the release is complete

- Check that the version is in the gallery and that the GitHub release and its announcement are there.
- **Look at the entry pages in light and dark**: the README, the docs start page and the module
  overview, of this repository and of [pivotkit](https://github.com/eizedev/pivotkit), whose docs the
  pivot pages hand readers over to. Each image must show, in the theme it was made for. A problem
  here is fixed in the docs, or with a patch release.

## Trial run

"Run workflow" on `release.yml` with a tag name checks a release without publishing anything. That
trial run checks main membership and the CI run of the ref you choose to run it on, not of the tag
you type.

## One-time setup

Once per repository: Settings > Environments > `psgallery` with the maintainers as required reviewers
and deployment tags `*-v*`; in that environment (never as a repository secret) the secret
`PSGALLERY_API_KEY`, a gallery key scoped to the repository's module names. A ruleset lets only
maintainers create `*-v*` tags.
