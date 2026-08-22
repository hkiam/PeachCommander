---
title: CSV files as a table
slug: csv-lister
group: Plugins
section: Plugins
order: 129
related: [plugins, viewing-files, log-viewer]
---

Press **F3** on a `.csv` or `.tsv` file and it opens as a real table — columns, headers, sorting and a filter — instead of as lines of text with commas in them.

It is a plugin, so you can turn it off or remove it in **Configuration ▸ Plugins…**. Without it, F3 shows the file as plain text, which is still perfectly readable for a small one.

## The delimiter is worked out, not assumed

Comma, semicolon, tab, pipe and colon are all candidates. The plugin counts each of them across the first twenty lines and picks the one that appears the same number of times on the most lines — a file whose every row has four semicolons is a semicolon file, whatever its extension says. That matters in practice: a `.csv` exported by a spreadsheet on a German system is usually semicolon-separated, and a `.tsv` is not always tab-separated.

The first line is treated as the header row and becomes the column titles.

## Sorting and filtering

Click a column header to sort by it, click again to reverse. Sorting is **numeric when both values are numbers** and alphabetical otherwise, so a column of sizes sorts 9 before 10 rather than after it.

The search field filters as you type, case-insensitively. By default it looks in every column; pick a column from the popup beside it to look only there.

## What it does not do

The parser is deliberately small, and one limit is worth knowing before it surprises you: **a delimiter inside a quoted field is still treated as a delimiter.** A row like

```
"Smith, John",42
```

becomes three cells rather than two. Surrounding quotes are removed when they wrap a whole field, but quoting is not otherwise interpreted. For a file where that matters, the built-in viewer or a spreadsheet is the better tool.

Empty lines are skipped, and there is no support for a field that spans several lines.
