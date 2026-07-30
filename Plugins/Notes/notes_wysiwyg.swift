// notes_wysiwyg.swift — a true bidirectional WYSIWYG markdown editor for notes.
//
// The note is edited as formatted rich text (bold/italic/code, H1–H3 headings,
// bullet lists, links, inline images) and round-trips to/from markdown for
// storage. MarkdownRich converts markdown → NSAttributedString (visible styling
// via a controlled attribute model) and back; WYSIWYGEditorView hosts a rich
// NSTextView + a formatting toolbar. A controlled/normalized markdown subset is
// supported so the round-trip is stable.

import AppKit

extension NSAttributedString.Key {
    static let noteHeading = NSAttributedString.Key("noteHeading")     // Int 1...3
    static let noteCode = NSAttributedString.Key("noteCode")           // Bool
    static let noteImagePath = NSAttributedString.Key("noteImagePath") // String (attachment)
}

enum MarkdownRich {
    static let baseFont = NSFont.systemFont(ofSize: 13)
    static func headingFont(_ level: Int) -> NSFont {
        NSFont.boldSystemFont(ofSize: [22, 18, 15][max(0, min(2, level - 1))])
    }
    private static var codeFont: NSFont {
        NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    }
    private static func trait(_ font: NSFont, _ t: NSFontTraitMask) -> NSFont {
        NSFontManager.shared.convert(font, toHaveTrait: t)
    }
    private static func bulletStyle() -> NSParagraphStyle {
        let ps = NSMutableParagraphStyle()
        ps.textLists = [NSTextList(markerFormat: .disc, options: 0)]
        ps.headIndent = 16
        return ps
    }

    // MARK: markdown -> attributed

    static func toAttributed(_ markdown: String, baseDir: URL) -> NSAttributedString {
        let out = NSMutableAttributedString()
        let lines = markdown.components(separatedBy: "\n")
        for (i, line) in lines.enumerated() {
            var body = line
            var heading = 0
            var bullet = false
            let hashes = line.prefix { $0 == "#" }.count
            if (1...3).contains(hashes), Array(line).count > hashes, line[line.index(line.startIndex, offsetBy: hashes)] == " " {
                heading = hashes
                body = String(line.dropFirst(hashes + 1))
            } else if let r = line.range(of: #"^[-*]\s+"#, options: .regularExpression) {
                bullet = true
                body = String(line[r.upperBound...])
            }
            let para = parseInline(body, baseDir: baseDir)
            let full = NSRange(location: 0, length: para.length)
            if heading > 0 {
                para.addAttributes([.font: headingFont(heading), .noteHeading: heading], range: full)
            }
            if bullet {
                para.addAttribute(.paragraphStyle, value: bulletStyle(), range: full)
            }
            out.append(para)
            if i < lines.count - 1 { out.append(NSAttributedString(string: "\n")) }
        }
        out.addAttribute(.foregroundColor, value: NSColor.labelColor,
                         range: NSRange(location: 0, length: out.length))
        return out
    }

    /// One inline pattern match: kind + captured groups + range.
    private static let inline = try! NSRegularExpression(pattern:
        #"!\[([^\]]*)\]\(([^)]+)\)|\[([^\]]+)\]\(([^)]+)\)|\*\*([^*]+)\*\*|`([^`]+)`|(?:\*|_)([^*_]+)(?:\*|_)"#)

    private static func parseInline(_ text: String, baseDir: URL) -> NSMutableAttributedString {
        let result = NSMutableAttributedString()
        let ns = text as NSString
        var loc = 0
        func plain(_ s: String) { result.append(NSAttributedString(string: s, attributes: [.font: baseFont])) }
        inline.enumerateMatches(in: text, range: NSRange(location: 0, length: ns.length)) { m, _, _ in
            guard let m else { return }
            if m.range.location > loc {
                plain(ns.substring(with: NSRange(location: loc, length: m.range.location - loc)))
            }
            func grp(_ i: Int) -> String? { m.range(at: i).location != NSNotFound ? ns.substring(with: m.range(at: i)) : nil }
            if let alt = grp(1), let path = grp(2) {                    // image
                let url = path.hasPrefix("/") ? URL(fileURLWithPath: path) : baseDir.appendingPathComponent(path)
                let att = NSTextAttachment(); att.image = NSImage(contentsOf: url)
                let s = NSMutableAttributedString(attachment: att)
                s.addAttribute(.noteImagePath, value: path, range: NSRange(location: 0, length: s.length))
                _ = alt
                result.append(s)
            } else if let t = grp(3), let url = grp(4) {                // link
                result.append(NSAttributedString(string: t, attributes: [.font: baseFont, .link: url]))
            } else if let t = grp(5) {                                  // bold
                result.append(NSAttributedString(string: t, attributes: [.font: trait(baseFont, .boldFontMask)]))
            } else if let t = grp(6) {                                  // code
                result.append(NSAttributedString(string: t, attributes: [.font: codeFont, .noteCode: true]))
            } else if let t = grp(7) {                                  // italic
                result.append(NSAttributedString(string: t, attributes: [.font: trait(baseFont, .italicFontMask)]))
            }
            loc = m.range.location + m.range.length
        }
        if loc < ns.length { plain(ns.substring(from: loc)) }
        if result.length == 0 { plain("") }
        return result
    }

    // MARK: attributed -> markdown

    static func toMarkdown(_ attr: NSAttributedString) -> String {
        let ns = attr.string as NSString
        var lines: [String] = []
        var loc = 0
        for line in attr.string.components(separatedBy: "\n") {
            let len = (line as NSString).length
            lines.append(serializeParagraph(attr, NSRange(location: loc, length: len)))
            loc += len + 1
        }
        _ = ns
        return lines.joined(separator: "\n")
    }

    private static func serializeParagraph(_ attr: NSAttributedString, _ range: NSRange) -> String {
        guard range.length > 0 else { return "" }
        let heading = attr.attribute(.noteHeading, at: range.location, effectiveRange: nil) as? Int
        let ps = attr.attribute(.paragraphStyle, at: range.location, effectiveRange: nil) as? NSParagraphStyle
        let bullet = !(ps?.textLists.isEmpty ?? true)
        let isHeading = (heading ?? 0) > 0
        var inline = ""
        let s = attr.string as NSString
        attr.enumerateAttributes(in: range) { attrs, runRange, _ in
            if let path = attrs[.noteImagePath] as? String { inline += "![](\(path))"; return }
            var t = s.substring(with: runRange)
            if let url = attrs[.link] { inline += "[\(t)](\(String(describing: url)))"; return }
            if (attrs[.noteCode] as? Bool) == true { inline += "`\(t)`"; return }
            if !isHeading, let f = attrs[.font] as? NSFont {
                let tr = f.fontDescriptor.symbolicTraits
                if tr.contains(.bold) { t = "**\(t)**" }
                if tr.contains(.italic) { t = "*\(t)*" }
            }
            inline += t
        }
        if isHeading { return String(repeating: "#", count: heading!) + " " + inline }
        if bullet { return "- " + inline }
        return inline
    }
}

/// Rich text view that inserts a dropped image file as an inline attachment
/// (tagged with its stored relative path) rather than a raw file attachment.
final class RichDropTextView: NSTextView {
    var onDropImage: ((URL) -> Void)?
    private func images(_ s: NSDraggingInfo) -> [URL] {
        (s.draggingPasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] ?? [])
            .filter { imageExtensions.contains($0.pathExtension.lowercased()) }
    }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        images(sender).isEmpty ? super.draggingEntered(sender) : .copy
    }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let imgs = images(sender)
        guard !imgs.isEmpty else { return super.performDragOperation(sender) }
        imgs.forEach { onDropImage?($0) }
        return true
    }
}

/// A true WYSIWYG markdown editor: formatted rich text + a formatting toolbar,
/// round-tripping to markdown via MarkdownRich.
final class WYSIWYGEditorView: NSView {
    private let textView = RichDropTextView()
    private let key: String
    var onChange: (() -> Void)?

    init(key: String) {
        self.key = key
        super.init(frame: .zero)
        build()
    }
    required init?(coder: NSCoder) { fatalError() }

    func loadMarkdown(_ md: String) {
        textView.textStorage?.setAttributedString(MarkdownRich.toAttributed(md, baseDir: NotesStore.shared.baseDir))
        textView.typingAttributes = [.font: MarkdownRich.baseFont, .foregroundColor: NSColor.labelColor]
    }
    func markdown() -> String { MarkdownRich.toMarkdown(textView.attributedString()) }

    private func build() {
        textView.isRichText = true
        textView.allowsUndo = true
        textView.font = MarkdownRich.baseFont
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.onDropImage = { [weak self] in self?.insertImage(url: $0) }
        textView.registerForDraggedTypes([.fileURL])
        let scroll = NSScrollView()
        scroll.documentView = textView; scroll.hasVerticalScroller = true; scroll.borderType = .bezelBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let bar = NSStackView(); bar.orientation = .horizontal; bar.spacing = 4
        bar.translatesAutoresizingMaskIntoConstraints = false
        func btn(_ title: String, _ sel: Selector) -> NSButton {
            let b = NSButton(title: title, target: self, action: sel); b.bezelStyle = .rounded
            b.setContentHuggingPriority(.required, for: .horizontal); return b
        }
        bar.addArrangedSubview(btn(L("B"), #selector(bold)))       // format-button label (de: F = Fett)
        bar.addArrangedSubview(btn(L("I"), #selector(italic)))     // format-button label (de: K = Kursiv)
        bar.addArrangedSubview(btn("</>", #selector(code)))
        bar.addArrangedSubview(btn("H1", #selector(h1)))
        bar.addArrangedSubview(btn("H2", #selector(h2)))
        bar.addArrangedSubview(btn("H3", #selector(h3)))
        bar.addArrangedSubview(btn("•", #selector(bullet)))
        bar.addArrangedSubview(btn(L("Link"), #selector(link)))
        bar.addArrangedSubview(btn(L("Image"), #selector(image)))
        bar.addArrangedSubview(NSView())
        addSubview(bar); addSubview(scroll)
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            bar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            bar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            scroll.topAnchor.constraint(equalTo: bar.bottomAnchor, constant: 6),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
        ])
    }

    private var sel: NSRange { textView.selectedRange() }
    private var storage: NSTextStorage { textView.textStorage! }
    private func paragraphRange() -> NSRange { (textView.string as NSString).paragraphRange(for: sel) }
    private func edited() { textView.didChangeText(); onChange?() }

    @objc private func bold() { toggleTrait(.boldFontMask) }
    @objc private func italic() { toggleTrait(.italicFontMask) }

    private func toggleTrait(_ trait: NSFontTraitMask) {
        let range = sel
        guard range.length > 0, textView.shouldChangeText(in: range, replacementString: nil) else { return }
        let fm = NSFontManager.shared
        storage.beginEditing()
        storage.enumerateAttribute(.font, in: range) { value, r, _ in
            let f = (value as? NSFont) ?? MarkdownRich.baseFont
            let has = f.fontDescriptor.symbolicTraits.contains(trait == .boldFontMask ? .bold : .italic)
            storage.addAttribute(.font, value: has ? fm.convert(f, toNotHaveTrait: trait) : fm.convert(f, toHaveTrait: trait), range: r)
        }
        storage.endEditing()
        edited()
    }

    @objc private func code() {
        let range = sel
        guard range.length > 0, textView.shouldChangeText(in: range, replacementString: nil) else { return }
        let isCode = (storage.attribute(.noteCode, at: range.location, effectiveRange: nil) as? Bool) == true
        storage.beginEditing()
        if isCode {
            storage.removeAttribute(.noteCode, range: range)
            storage.addAttribute(.font, value: MarkdownRich.baseFont, range: range)
        } else {
            storage.addAttribute(.noteCode, value: true, range: range)
            storage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular), range: range)
        }
        storage.endEditing(); edited()
    }

    @objc private func h1() { setHeading(1) }
    @objc private func h2() { setHeading(2) }
    @objc private func h3() { setHeading(3) }

    private func setHeading(_ level: Int) {
        let range = paragraphRange()
        guard textView.shouldChangeText(in: range, replacementString: nil) else { return }
        let current = storage.attribute(.noteHeading, at: range.location, effectiveRange: nil) as? Int
        storage.beginEditing()
        if current == level {   // toggle off → body
            storage.removeAttribute(.noteHeading, range: range)
            storage.addAttribute(.font, value: MarkdownRich.baseFont, range: range)
        } else {
            storage.addAttribute(.noteHeading, value: level, range: range)
            storage.addAttribute(.font, value: MarkdownRich.headingFont(level), range: range)
        }
        storage.endEditing(); edited()
    }

    @objc private func bullet() {
        let range = paragraphRange()
        guard textView.shouldChangeText(in: range, replacementString: nil) else { return }
        let ps = storage.attribute(.paragraphStyle, at: range.location, effectiveRange: nil) as? NSParagraphStyle
        let isBullet = !(ps?.textLists.isEmpty ?? true)
        let style = NSMutableParagraphStyle()
        if !isBullet { style.textLists = [NSTextList(markerFormat: .disc, options: 0)]; style.headIndent = 16 }
        storage.beginEditing()
        storage.addAttribute(.paragraphStyle, value: style, range: range)
        storage.endEditing(); edited()
    }

    @objc private func link() {
        let range = sel
        guard range.length > 0 else { return }
        let alert = NSAlert(); alert.messageText = L("Link URL")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 22)); field.stringValue = "https://"
        alert.accessoryView = field; alert.addButton(withTitle: L("OK")); alert.addButton(withTitle: L("Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn, !field.stringValue.isEmpty,
              textView.shouldChangeText(in: range, replacementString: nil) else { return }
        storage.beginEditing()
        storage.addAttribute(.link, value: field.stringValue, range: range)
        storage.endEditing(); edited()
    }

    @objc private func image() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.image]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        insertImage(url: url)
    }

    private func insertImage(url: URL) {
        let destDir = NotesStore.shared.attachmentsDir(key)
        let dest = destDir.appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.removeItem(at: dest)
        try? FileManager.default.copyItem(at: url, to: dest)
        let rel = "attachments/\(destDir.lastPathComponent)/\(url.lastPathComponent)"
        let att = NSTextAttachment(); att.image = NSImage(contentsOf: dest)
        let s = NSMutableAttributedString(attachment: att)
        s.addAttribute(.noteImagePath, value: rel, range: NSRange(location: 0, length: s.length))
        let range = sel
        guard textView.shouldChangeText(in: range, replacementString: s.string) else { return }
        storage.replaceCharacters(in: range, with: s)
        edited()
    }
}
