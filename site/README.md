# EGM site

The project site, published to GitHub Pages. It is plain HTML, CSS and JavaScript with no
dependencies. The skill cards are generated from each skill's `SKILL.md`, so the list cannot
drift from the plugin.

## Layout

```text
site/
  index.html           the page
  assets/site.css      styles (light and dark)
  assets/site.js       renders skill cards, copy buttons, configured links
  src/skills.json      curated per-skill display text (title, group, command, summary)
  src/site.json        site-wide settings (repo URL, install commands, copyright)
  tools/build.py       generator: validates and writes the outputs below
  data/skills.js       GENERATED, git-ignored
  autopilot/flow.html  GENERATED copy of docs/autopilot-flow.html, git-ignored
```

## Add or change a skill

1. Edit or add the skill's `skills/<name>/SKILL.md`. Its frontmatter `name` and `description`
   are what the site shows.
2. Add or update its entry in `src/skills.json`. Every `SKILL.md` must have an entry, and every
   entry must match a `SKILL.md` name. The build fails otherwise.
3. Run `python3 site/tools/build.py`.

## Preview locally

```sh
python3 site/tools/build.py
python3 -m http.server 8000 --directory site
# open http://localhost:8000
```

Opening `site/index.html` directly also works after the build step.

## Publish on GitHub Pages

1. In the repository, go to **Settings > Pages** and set **Build and deployment > Source** to
   **GitHub Actions**. This is a one-time step.
2. Push to `main`. `.github/workflows/pages.yml` builds the site and deploys it.
3. The site is at `https://<owner>.github.io/<repository>/`.

Pull requests that touch the site or a `SKILL.md` run the same validation without deploying.

Every link and asset is relative, so the site works at a project path with no changes. To
point the GitHub links at a fork, change `repo_url` in `src/site.json`.
