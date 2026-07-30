/* download.js — point the homepage download buttons at the newest published DMG.
 *
 * Progressive enhancement. The markup in docs/content/website/index.md already
 * links to the repository's releases page, so the buttons work with JavaScript
 * disabled, on a rate-limited API, and offline. This script only *upgrades* them to
 * a direct .dmg link once it knows a published release exists.
 *
 * The page carries more than one download block (hero + download section), so
 * everything is class-based: each `[data-pc-release]` container is updated
 * independently via `.js-pc-download-btn` / `.js-pc-download-status`.
 *
 * Re-runs on every page view. MkDocs Material's `navigation.instant` swaps the
 * document body without re-executing extra_javascript, so the work is hooked to
 * Material's `document$` observable — otherwise the buttons revert to their
 * static state the first time the visitor follows an internal link. The release
 * lookup itself is cached in `releasePromise` so instant navigation does not
 * spend the anonymous API budget (60 requests/hour) again on every page.
 *
 * Release builds come from .github/workflows/release.yml. Note that workflow
 * creates the GitHub Release as a DRAFT: drafts are invisible to the anonymous
 * API, so the buttons stay in their "no build yet" state until it is published.
 */
(function () {
  "use strict";

  var releasePromise = null; // cached across instant navigations

  function fmtSize(bytes) {
    if (!bytes) return null;
    return (bytes / 1048576).toFixed(1).replace(/\.0$/, "") + " MB";
  }

  function fmtDate(iso) {
    if (!iso) return null;
    // Locale-aware but stable: the site is served in many languages.
    return new Date(iso).toLocaleDateString(document.documentElement.lang || "en", {
      year: "numeric", month: "short", day: "numeric"
    });
  }

  function getJSON(url) {
    return fetch(url, { headers: { Accept: "application/vnd.github+json" } })
      .then(function (r) {
        if (!r.ok) {
          var err = new Error("HTTP " + r.status);
          err.status = r.status;
          throw err;
        }
        return r.json();
      });
  }

  /* Prefer /releases/latest (newest stable). If there is none, fall back to the
     list and take the newest entry — that also surfaces pre-releases, which is
     what a pre-1.0 project will publish first. Drafts never appear here. */
  function findRelease(api) {
    return getJSON(api + "/latest").catch(function (err) {
      if (err.status !== 404) throw err;
      return getJSON(api + "?per_page=10").then(function (list) {
        if (!Array.isArray(list)) return null;
        for (var i = 0; i < list.length; i++) {
          if (!list[i].draft) return list[i];
        }
        return null;
      });
    });
  }

  function dmgOf(release) {
    var assets = (release && release.assets) || [];
    for (var i = 0; i < assets.length; i++) {
      if (/\.dmg$/i.test(assets[i].name)) return assets[i];
    }
    return null;
  }

  function boot() {
    // Re-query on every page view: `navigation.instant` replaces these nodes.
    var roots = document.querySelectorAll("[data-pc-release]");
    if (!roots.length) return; // not the homepage

    var repo = roots[0].getAttribute("data-pc-release");
    if (!repo) return;

    function each(selector, fn) {
      Array.prototype.forEach.call(roots, function (root) {
        Array.prototype.forEach.call(root.querySelectorAll(selector), fn);
      });
    }

    function say(text) {
      each(".js-pc-download-status", function (el) { el.textContent = text; });
    }

    function noBuild() {
      each(".js-pc-download-btn", function (btn) {
        btn.classList.add("is-unavailable");
        btn.setAttribute("aria-disabled", "true");
        btn.textContent = "No build published yet";
        // Anchor verified against the rendered README (id="user-content--installation--build").
        btn.href = "https://github.com/" + repo + "#-installation--build";
      });
      say("No release has been published yet — you can build Peach Commander from " +
          "source in a couple of minutes. This updates itself as soon as a release goes live.");
    }

    if (!releasePromise) {
      releasePromise = findRelease("https://api.github.com/repos/" + repo + "/releases");
    }

    releasePromise
      .then(function (release) {
        if (!release) return noBuild();

        var dmg = dmgOf(release);
        var version = release.tag_name || release.name || "";

        if (!dmg) {
          // A release exists but carries no DMG (source-only, or still uploading).
          each(".js-pc-download-btn", function (btn) {
            btn.href = release.html_url;
            btn.textContent = "View release " + version;
          });
          say("Release " + version + " is published, but has no disk image attached yet.");
          return;
        }

        each(".js-pc-download-btn", function (btn) {
          btn.href = dmg.browser_download_url;
          btn.textContent = "Download " + version + " for macOS";
          btn.setAttribute("download", "");
        });

        var bits = [fmtSize(dmg.size), fmtDate(release.published_at)].filter(Boolean);
        var note = "Disk image" + (bits.length ? " · " + bits.join(" · ") : "");
        if (release.prerelease) note += " · pre-release";
        say(note + ". Universal binary, requires macOS 13 or later.");
      })
      .catch(function (err) {
        // Rate limit, offline, blocked request — keep the static releases-page link.
        say("Could not reach the GitHub API (" + err.message + "). The button still " +
            "opens the releases page, where every build is listed.");
      });
  }

  /* Material exposes `document$` and emits on every instant navigation. Fall back
     to a plain DOM-ready hook so the script also works outside Material. */
  if (typeof document$ !== "undefined" && document$ && typeof document$.subscribe === "function") {
    document$.subscribe(boot);
  } else if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }
})();
