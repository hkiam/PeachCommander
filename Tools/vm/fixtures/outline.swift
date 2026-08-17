// SPDX-License-Identifier: Apache-2.0
// A fixture for the Swift symbol outline (F-405). Every shape the scanner is expected to find is here
// once: a protocol with a requirement, a type with an init and methods, an extension, an enum, an actor,
// a typealias and a file-scope function. The comment and the string below are the negative cases —
// neither `class Commented` nor `struct InAString` may appear in the outline.

import Foundation

// class Commented

public protocol Greeter {
    func greet(_ name: String) -> String
}

public struct Machine: Greeter {
    let id: Int
    public init(id: Int) { self.id = id }
    public func greet(_ name: String) -> String { "hi \(name)" }
    private func secret() { print("struct InAString") }
}

extension Machine: CustomStringConvertible {
    public var description: String { "Machine(\(id))" }
    func describeTwice() -> String { description + description }
}

enum Mode { case fast, slow }

actor Counter {
    private var value = 0
    func bump() { value += 1 }
}

typealias Handler = (Int) -> Void

func topLevel() {}
