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

// "a" or "b"
let rule = "a" | "b"

