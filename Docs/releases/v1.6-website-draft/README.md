# v1.6 website release draft

Prepared 2026-09-08 from the local GameKitWebsite checkout. This patch is intentionally unapplied and unpublished while app release verification remains open.

It updates index, about, press, updates and the shared version config to the eleven-game roster. Existing screenshot alt text continues describing the ten-game screenshot actually shown. No Math Crossword screenshot is invented.

At release, verify the release month, run `git apply --check` against the then-current website checkout, apply this patch, and visually check the pages before committing/pushing the website. The draft HTML and embedded JSON-LD were parsed during preparation; browser layout still needs checking after application.
