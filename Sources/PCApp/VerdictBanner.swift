// SPDX-License-Identifier: Apache-2.0
// VerdictBanner.swift - The one sentence a comparison window has to say where the reader is looking.
//
// Both compare windows had the same problem and would have had the same fix twice: the verdict lived
// in an 11 pt secondary-grey label at the bottom edge, which for "the two files are identical" is a
// sentence you have to go looking for to answer the only question the window was opened to answer.
// One type rather than a copy in each, because the copies would differ in exactly the way that
// matters — a strip that is 26 pt in one window and 24 in the other is not a defect anybody would
// fix, and a strip that forgets `isHidden` in one of them shows its text over the table.
//
// Two rules are worth knowing:
//
//   * **The height and the hidden flag travel together.** An `NSBox` does not clip its subviews on
//     the deployment target, so a 0 pt strip still *draws* its label — over whatever is beneath it.
//     Only `show(_:good:)` may touch either, which is the whole reason this is a type.
//   * **The fill is translucent and the text is `labelColor`.** That is what makes it work in all
//     four palettes without any of them knowing about it: the tint sits on the window's own
//     background, and `labelColor` is the one colour guaranteed to be readable against it.

import AppKit

final class VerdictBanner: NSBox {

    /// Tall enough for the 13 pt semibold label it holds, with the padding that keeps it a band
    /// rather than a line of text.
    private static let shownHeight: CGFloat = 26

    private let label = NSTextField(labelWithString: "")
    private var heightConstraint: NSLayoutConstraint!

    init() {
        super.init(frame: .zero)
        boxType = .custom
        borderWidth = 0
        translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        label.alignment = .center
        addSubview(label)
        // Collapsed and hidden until there is something to say, so a window that never has anything
        // to say looks exactly as it did before this existed.
        heightConstraint = heightAnchor.constraint(equalToConstant: 0)
        isHidden = true
        NSLayoutConstraint.activate([
            heightConstraint,
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Say `text`, or take the strip away when it is nil.
    ///
    /// `good` picks the tint only — green for "this is the answer you wanted", orange for "this was
    /// not a comparison". The sentence says which; the colour is never carrying the meaning alone.
    func show(_ text: String?, good: Bool = true) {
        guard let text else {
            isHidden = true
            heightConstraint.constant = 0
            return
        }
        label.stringValue = text
        fillColor = (good ? NSColor.systemGreen : NSColor.systemOrange).withAlphaComponent(0.18)
        isHidden = false
        heightConstraint.constant = Self.shownHeight
    }

    /// What the strip is saying, for the automation report — empty when it is not shown, so a report
    /// cannot say "identical" about a band nobody can see.
    var shownText: String { isHidden ? "" : label.stringValue }
}
