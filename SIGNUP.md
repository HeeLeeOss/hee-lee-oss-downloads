# Ask for donated AI capacity

> **Audience:** maintainers of open projects that serve the public good.
> **Summary:** add one file to your repository and contributors will work the needs you list,
> opening ordinary pull requests for you to review or close.

You do not need to move your project into Hee-Lee Oss. The opt-in is a single file.

## 1. Add the manifest

Copy [`docs/heeleeoss.example.yml`](docs/heeleeoss.example.yml) to **`.github/heeleeoss.yml`** in your
own repository and fill it in:

```yaml
version: "1"
project: your-project
beneficiary: who is actually helped when this ships
definitionOfShipped: your bar for done — merged? released? deployed?
reviewers: [your-github-handle]     # required
license: MIT
riskTier: low
needs:
  - id: docs-001
    title: Translate the getting-started guide into Spanish
    objective: Produce an accurate Spanish translation of docs/getting-started.md.
    deliverable: document
    acceptanceCriteria:
      - Reviewed by a Spanish-speaking maintainer
      - Terminology matches the existing glossary
```

Merging that file is the entire consent step. **Deleting it opts you back out**, with no notice
required.

## 2. Check it parses

```bash
npm install -g @heeleeoss/cli
hee-lee-oss signups --repos <you>/<your-repo>
```

You will see your project, its beneficiary, your reviewers, and the tasks your needs expand into.

## The three rules the file enforces, and why

1. **At least one `reviewers` entry.** A manifest with no reviewer is a wish, not a signup. We do not
   start work on a need nobody has agreed to review — an unreviewed pull request is a cost to you,
   not a gift.
2. **`riskTier: high` must set `expertReview: true`.** Health, legal and safety work needs
   credentialed sign-off before anything merges.
3. **A need may not be riskier than the manifest.** You cannot be signed up for low-risk work and
   then handed something high-risk.

## What merging does and does not do

- **Does:** let contributors pick up the needs you listed and open normal pull requests.
- **Does not:** grant any access to your repository, run anything in your CI, or start work before
  you merge.
- **Reversible:** delete the file and nothing further is picked up.

## What you can expect from every pull request

- It states up front that it was prepared with **AI assistance**, and names the agent.
- It links the issue or need it answers.
- It follows **your** conventions — your `CONTRIBUTING.md`, code style, commit format and tests.
- It is the smallest diff that does the job: no drive-by refactors, reformatting, or dependency
  bumps.
- It carries **your** licence and contribution terms. We never add Hee-Lee Oss branding, badges, or
  licence headers to your repository.
- Your tests are run and must pass. We never disable or weaken a test to get green.

## If we send you a proposal first

You may receive a small pull request from us that adds this file for you, pre-filled from issues you
have already labelled `help wanted` or `good first issue`. It changes one file and nothing else.

**Close it and we will not ask again** — we keep a permanent do-not-contact record.

We never send unsolicited work, and we never contact a project whose contributing guide declines
AI-generated or unsolicited pull requests. That check runs before every proposal.

## Which projects we can work with

The bar is **"open, and stays open"** — not a particular licence. Copyleft (AGPL, GPL, LGPL, MPL) is
welcome and gives the strongest permanence guarantee there is; permissive and open content licences
are welcome too.

We decline: repositories with no licence; source-available terms (BUSL, SSPL, Elastic Licence,
Commons Clause, non-commercial); a proprietary "enterprise" carve-out; or a Contributor Licence
Agreement that assigns rights to a company, since that permits relicensing contributions later. A CLA
held by a foundation is fine.

Questions: open an issue on [hee-lee-oss-downloads](https://github.com/HeeLeeOss/hee-lee-oss-downloads/issues).
