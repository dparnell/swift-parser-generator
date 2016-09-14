[![Codewake](https://www.codewake.com/badges/ask_question.svg)](https://www.codewake.com/p/swift-parser-generator)

swift-parser-generator
======================

This code contains an attempt to make something like the Scala parser combinators in Swift.

It has been partially successful in that it can be used to make simple parsers, but I have not as yet implemented the Packrat style parsers.

How it works
============

Using operator overloading a nested set of functions is created that forms the parser.
The functions take a parser instance and a reader object that provides the function with characters to parse.

The following parsing operations are currently supported

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

To have the parser call your code when a rule matches use the => operator.  For example:

    import SwiftParser
    class Adder : Parser {
        var stack: Int[] = []
        
        func push() {
            stack.append(self.text.toInt()!)
        }
        
        func add() {
            let left = stack.removeLast()
            let right = stack.removeLast()
            
            stack.append(left + right)
        }
        
        override func rules() {
            let number = ("0"-"9")+ => push
            let expr = (number ~ "+" ~ number) => add
            
            start_rule = expr
        }
    }

This example displays several details about how to work with the parser.  The parser is defined in a method called `rules` and it must set the `start_rule` to tell the parser where to begin.
The following code snippet is taken from one of the unit tests.  It show how to implement a parser containing  mutually recursive rules:

      override func rules() {
          start_rule = (^"primary")*!*
            
          let number = ("0"-"9")+ => push
          add_named_rule("primary",   rule: ^"secondary" ~ (("+" ~ ^"secondary" => add) | ("-" ~ ^"secondary" => sub))*)
          add_named_rule("secondary", rule: ^"tertiary" ~ (("*" ~ ^"tertiary" => mul) | ("/" ~ ^"tertiary" => div))*)
          add_named_rule("tertiary",  rule: ("(" ~ ^"primary" ~ ")") | number)
      }

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
