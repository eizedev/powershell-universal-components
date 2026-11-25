---
description: "How a module is released: CHANGELOG and ModuleVersion, the tag <Module>-v<Version>, the release workflow that publishes to the PowerShell Gallery, and the one-time setup."
---

# Releases

Each module has its own SemVer `ModuleVersion` and `CHANGELOG.md` and is released on its own, from a
tag `<Module>-v<Version>` on `main`.

1. In the module's `CHANGELOG.md`, move the entries from `[Unreleased]` to `## [x.y.z] - YYYY-MM-DD`;
   set `ModuleVersion` in the manifest to `x.y.z`. Merge that pull request.
2. Tag after CI has passed for that commit on `main`: the release needs its green CI run and fails
   otherwise; re-run it once CI is green. Tag the merge commit:
   `git tag <Module>-vx.y.z && git push origin <Module>-vx.y.z`. A tag on a commit that is not on
   `main` stops the workflow before anything is built.
3. The workflow `release.yml` tests, builds and checks the module, then waits for approval in the
   environment `psgallery`; after it, it publishes to the PowerShell Gallery and creates the GitHub
   release with the zip, the CHANGELOG section and a link to the version's page in the gallery. For a
   component module (not a demo, not a prerelease) it also starts a discussion in Announcements.

"Run workflow" on `release.yml` with a tag name checks a release without publishing anything. That
trial run checks main membership and the CI run of the ref you choose to run it on, not of the tag
you type. A module that requires another one (a demo requires its component module) is released after
it: the gallery checks that the required version is there.

Once per repository: Settings > Environments > `psgallery` with the maintainers as required reviewers
and deployment tags `*-v*`; in that environment (never as a repository secret) the secret
`PSGALLERY_API_KEY`, a gallery key scoped to the repository's module names. A ruleset lets only
maintainers create `*-v*` tags.
