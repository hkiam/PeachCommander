---
title: Privacy policy
slug: privacy
description: What this website and the Peach Commander application do with your data. Short version, almost nothing.
group: Legal
section: legal
order: 20
---

# Privacy policy

Last updated: TODO-FILL: Datum

This policy covers two separate things: this website, and the Peach Commander application you download from it. Neither of them has an account system, and neither sends your usage anywhere.

## Controller

TODO-FILL: Vor- und Nachname
TODO-FILL: Straße und Hausnummer
TODO-FILL: Postleitzahl und Ort
Deutschland

E-Mail: TODO-FILL: Kontakt-E-Mail-Adresse

## The website

### Hosting

This site is published through GitHub Pages, a service of GitHub, Inc., 88 Colin P. Kelly Jr. Street, San Francisco, CA 94107, USA. When you open a page, your browser necessarily sends your IP address, the requested URL, the referring page and your user agent to GitHub's servers, where they may be processed in server logs for security and operational purposes. This happens before any content of mine runs, and I have no access to those logs and receive no reports from them.

Legal basis: Art. 6(1)(f) GDPR, the legitimate interest in providing a website at all. Data transfer to the USA is covered by GitHub's own safeguards; see the GitHub Privacy Statement at <https://docs.github.com/site-policy/privacy-policies/github-privacy-statement> and the GitHub Pages data collection notice at <https://docs.github.com/pages/getting-started-with-github-pages/what-is-github-pages#data-collection>.

### No analytics, no cookies, no fonts from elsewhere

This site sets no cookies, uses no analytics or tracking service, embeds no advertising, and loads no web fonts or scripts from third-party content delivery networks. Everything the pages need is served from the site itself. Nothing is stored on your device beyond your browser's ordinary cache, and no profile of you is built.

### The download button

The download button on the home page asks the public GitHub API (`api.github.com`) for the newest release, so that the version shown is always current. That request is made by your browser and therefore reveals your IP address to GitHub in the same way as loading the page does. No parameters identifying you are attached, and the answer is not stored. If you prefer to avoid it, use the release page on GitHub directly.

### Downloads

The application itself is served from GitHub Releases. Downloading it is a request to GitHub and is logged by GitHub under the terms linked above.

## The application

Peach Commander runs on your Mac. It has no account, no licence server and no update check that reports to me.

- **No telemetry.** The app collects no usage statistics and sends no analytics anywhere.
- **Passwords and keys** that you choose to save, for FTP, FTPS, SFTP, SMB, WebDAV or an encrypted archive, are written to the macOS Keychain and never in plain text into the app's own configuration files.
- **Crash reports stay on your Mac.** If the app quits unexpectedly, macOS writes a report to your own diagnostics folder. The app offers to help you file a bug report, but nothing is transmitted automatically and no third-party crash reporting service is involved.
- **Network connections happen only where you point them.** FTP, FTPS, SFTP, SMB and WebDAV connect to the servers you enter. The Docker plugin talks to your local Docker socket. The Amazon S3 plugin talks to the endpoint and bucket you configure, with credentials you supply. No connection is made to any server of mine, because there is none.
- **The optional MCP server** is local only, switched off by default, and can be protected with a token.

### The AI plugins

The AI plugins ship switched off. If you never enable them, nothing about them runs.

- **AI On-Device** uses Apple Intelligence and runs on your Mac. Nothing leaves the device.
- **AI Assistant**, the chat half, uses a cloud model only if you configure one yourself under Settings, AI, by entering an OpenAI-compatible endpoint, a model name and an API key. The key is stored in the macOS Keychain. In that case the content you send to the assistant, which can include file contents and file names, is transmitted to the provider you chose, and that provider's own privacy policy applies to it. I am not a party to that connection, I receive nothing from it, and no endpoint is preconfigured.

## If you contact me

If you write to me by e-mail or open an issue on GitHub, I process what you send in order to answer it. E-mail is processed on the basis of Art. 6(1)(b) or (f) GDPR. GitHub issues are public by nature and are processed by GitHub under its own terms. I keep correspondence only as long as it is needed to deal with the matter.

## Your rights

Under the GDPR you have the right to information about the personal data concerning you (Art. 15), to rectification (Art. 16), to erasure (Art. 17), to restriction of processing (Art. 18), to data portability (Art. 20) and to object to processing based on legitimate interests (Art. 21). You may also lodge a complaint with a supervisory authority, in Germany usually the data protection authority of the federal state in which you live.

Since I operate no account system and receive no logs, the practical answer to a request about the website is usually that I hold nothing about you. Requests concerning the server logs of this site have to be addressed to GitHub.

## Changes

If the site or the app starts doing something this page does not describe, this page changes first. The date at the top says when it was last touched.
