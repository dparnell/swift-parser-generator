swift-parser-generator
======================

This code contains an attempt to make something like the Scala parser combinators in Swift. It has been
partially successful in that it can be used to make simple parsers. Intermediate parsing results are cached
for complex rules, so that parsing of complex expressions should still be linear-time (cf. Packrat).

How it works
============

Using operator overloading a nested set of functions is created that forms the parser. The functions take
a parser instance and a reader object that provides the function with characters to parse.

The following parsing operations are currently supported:

```swift
// "a" followed by "b"
let rule = "a" ~ "b"

// "a" followed by "b", with possible whitespace in between
// to change what is considered whitespace, change the parser.whitespace rule
let rule = "a" ~~ "b"

// at least one "a", but possibly more
let rule = "a"++

// "a" or "b"
let rule = "a" | "b"

// "a" followed by something other than "b"
let rule = "a" ~ !"b"

// "a" followed by one or more "b"
let rule = "a" ~ "b"+

// "a" followed by zero or more "b"
let rule = "a" ~ "b"*

// "a" followed by a numeric digit
let rule = "a" ~ ("0"-"9")

// "a" followed by the rule named "blah"
let rule = "a" ~ ^"blah"

// "a" optionally followed by "b"
let rule = "a" ~ "b"/~

// "a" followed by the end of input
let rule = "a"*!*

// a single "," 
let rule = %","

// regular expression: consecutive word or space characters
let rule = %!"[\\w\\s]+"
```
To have the parser call your code when a rule matches use the => operator.  For example:

```swift
import SwiftParser
class Adder : Parser {
var stack: Int[] = []

func push(_ text: String) {
    stack.append(text.toInt()!)
}

func add() {
    let left = stack.removeLast()
    let right = stack.removeLast()

    stack.append(left + right)
}

	override init() {
		super.init()

		self.grammar = Grammar { [unowned self] g in
			g["number"] = ("0"-"9")+ => { [unowned self] parser in self.push(parser.text) }
			return (^"number" ~ "+" ~ ^"number") => add
		}
	}
}
```

This example displays several details about how to work with the parser.  The parser is defined in an object called `grammar` which defines named rules as well as a start rule, to tell the parser where to begin.

The following code snippet is taken from one of the unit tests.  It show how to implement a parser containing  mutually recursive rules:

```swift
self.grammar = Grammar { [unowned self] g in
	g["number"] = ("0"-"9")+ => { [unowned self] parser in self.push(parser.text) }

	g["primary"] = ^"secondary" ~ (("+" ~ ^"secondary" => add) | ("-" ~ ^"secondary" => sub))*
	g["secondary"] = ^"tertiary" ~ (("*" ~ ^"tertiary" => mul) | ("/" ~ ^"tertiary" => div))*
	g["tertiary"] = ("(" ~ ^"primary" ~ ")") | ^"number"

	return (^"primary")*!*
}
```

### Installation

#### Swift Package Manager (SPM)
 
 You can install the driver using Swift Package Manager by adding the following line to your ```Package.swift``` as a dependency:
 
 ```
 .Package(url: "https://github.com/dparnell/swift-parser-generator.git", majorVersion: 1)
 ```
 
 To use the driver in an Xcode project, generate an Xcode project file using SPM:
 ```
 swift package generate-xcodeproj
 ```
 
 #### Manual
 
 Drag SwiftParser.xcodeproj into your own project, then add SwiftParser as dependency (build targets) and link to it.
 You should then be able to simply 'import SwiftParser' from Swift code.
