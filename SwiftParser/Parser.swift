//
//  Parser.swift
//  SwiftParser
//
//  Created by Daniel Parnell on 17/06/2014.
//  Copyright (c) 2014 Daniel Parnell. All rights reserved.
//

import Foundation

typealias ParserRule = (parser: Parser, reader: Reader) -> Bool
typealias ParserAction = () -> ()

// EOF operator
operator postfix *!* {}
@postfix func *!* (rule: ParserRule) -> ParserRule {
    return {(parser: Parser, reader: Reader) -> Bool in
        return rule(parser: parser, reader: reader) && reader.eof()
    }
}

// call a named rule - this allows for cycles, so be careful!
operator prefix ^ {}
@prefix func ^(name:String) -> ParserRule {
    return {(parser: Parser, reader: Reader) -> Bool in
        if(parser.debug_rules) {
            println("named rule: \(name)")
        }
        // check to see if this would cause a recursive loop?
        if(parser.current_named_rule != name) {
            let old_named_rule = parser.current_named_rule
            let rule = parser.named_rules[name]
        
            parser.current_named_rule = name
            let result = rule!(parser: parser, reader: reader)
            parser.current_named_rule = old_named_rule
            
            if(parser.debug_rules) {
                println("\t\(result)")
            }
            return result
        }
        
        if(parser.debug_rules) {
            println("\tfalse - blocked")
        }
        return false
    }
}

// match a literal string
func literal(string:String) -> ParserRule {
    return {(parser: Parser, reader: Reader) -> Bool in
        if(parser.debug_rules) {
            println("literal '\(string)'")
        }
        let pos = reader.position
        
        for ch in string {
            let flag = ch == reader.read()
            if(parser.debug_rules) {
                println("\t\t\(ch) - \(flag)")
            }
            if !flag {
                reader.seek(pos)
                
                if(parser.debug_rules) {
                    println("\tfalse")
                }
                return false
            }
        }
        
        if(parser.debug_rules) {
            println("\ttrue")
        }
        return true
    }
}

// match a range of characters eg: "0"-"9"
@infix func - (left: Character, right: Character) -> ParserRule {
    return {(parser: Parser, reader: Reader) -> Bool in
        if(parser.debug_rules) {
            println("range [\(left)-\(right)]")
        }
        
        let pos = reader.position
        
        let lower = String(left)
        let upper = String(right)
        let ch = String(reader.read())
        let found = (lower <= ch) && (ch <= upper)
        if(parser.debug_rules) {
            println("\t\t\(ch) - \(found)")
        }
        
        if(!found) {
            reader.seek(pos)
        }
        
        return found
    }
}

// invert match
@prefix func !(rule: ParserRule) -> ParserRule {
    return {(parser: Parser, reader: Reader) -> Bool in
        return !rule(parser: parser, reader: reader)
    }
}

@prefix func !(lit: String) -> ParserRule {
    return !literal(lit)
}

// match one or more
operator postfix + {}
@postfix func + (rule: ParserRule) -> ParserRule {
    return {(parser: Parser, reader: Reader) -> Bool in
        let pos = reader.position
        var found = false
        var flag: Bool

        if(parser.debug_rules) {
            println("one or more")
        }
        do {
            flag = rule(parser: parser, reader: reader)
            found = found || flag
        } while(flag)
        
        if(!found) {
            reader.seek(pos)
        }
        
        if(parser.debug_rules) {
            println("\t\(found)")
        }
        return found
    }
}

@postfix func + (lit: String) -> ParserRule {
    return literal(lit)+
}


// match zero or more
operator postfix * {}
@postfix func * (rule: ParserRule) -> ParserRule {
    return {(parser: Parser, reader: Reader) -> Bool in
        var flag: Bool
        
        if(parser.debug_rules) {
            println("zero or more")
        }
        do {
            let pos = reader.position
            flag = rule(parser: parser, reader: reader)
            if(!flag) {
                reader.seek(pos)
            }
        } while(flag)
        
        return true
    }
}

@postfix func * (lit: String) -> ParserRule {
    return literal(lit)*
}

// optional
operator postfix /~ {}
@postfix func /~ (rule: ParserRule) -> ParserRule {
    return {(parser: Parser, reader: Reader) -> Bool in
        if(parser.debug_rules) {
            println("optionally")
        }
        let pos = reader.position
        if(!rule(parser: parser, reader: reader)) {
            reader.seek(pos)
        }
        return true
    }
}

@postfix func /~ (lit: String) -> ParserRule {
    return literal(lit)/~
}

// match either
@infix func | (left: String, right: String) -> ParserRule {
    return literal(left) | literal(right)
}

@infix func | (left: String, right: ParserRule) -> ParserRule {
    return literal(left) | right
}

@infix func | (left: ParserRule, right: String) -> ParserRule {
    return left | literal(right)
}

@infix func | (left: ParserRule, right: ParserRule) -> ParserRule {
    
    return {(parser: Parser, reader: Reader) -> Bool in
        let pos = reader.position
        var result = left(parser: parser, reader: reader)
        if(!result) {
            result = right(parser: parser, reader: reader)
        }
    
        if(!result) {
            reader.seek(pos)
        }
        
        return result
    }
}

// match all
operator infix ~ {associativity left precedence 10}
@infix func ~ (left: String, right: String) -> ParserRule {
    return literal(left) ~ literal(right)
}

@infix func ~ (left: String, right: ParserRule) -> ParserRule {
    return literal(left) ~ right
}

@infix func ~ (left: ParserRule, right: String) -> ParserRule {
    return left ~ literal(right)
}

@infix func ~ (left : ParserRule, right: ParserRule) -> ParserRule {
    return {(parser: Parser, reader: Reader) -> Bool in
        return left(parser: parser, reader: reader) && right(parser: parser, reader: reader)
    }
}

// on match
operator infix => {associativity right precedence 100}
@infix func => (rule : ParserRule, action: ParserAction) -> ParserRule {
    return {(parser: Parser, reader: Reader) -> Bool in
        let start = reader.position
        let capture_count = parser.captures.count
        
        if(rule(parser: parser, reader: reader)) {
            let capture = Parser.ParserCapture(start: start, end: reader.position, action: action)
            
            parser.captures.append(capture)
            return true
        }
        
        while(parser.captures.count > capture_count) {
            parser.captures.removeLast()
        }
        return false
    }
}

typealias ParserRuleDefinition = () -> ParserRule
operator infix <- {}
@infix func <- (left: Parser, right: ParserRuleDefinition) -> () {
    left.rule_definitions.append(right)
}

class Parser {
    struct ParserCapture {
        var start: Int
        var end: Int
        var action: ParserAction
    }
    
    var rule_definition: ParserRuleDefinition?
    var rule_definitions: ParserRuleDefinition[] = []
    var start_rule: ParserRule?
    var debug_rules = false
    var captures: ParserCapture[] = []
    var current_capture:ParserCapture?
    var current_reader:Reader?
    var named_rules: Dictionary<String,ParserRule> = Dictionary<String,ParserRule>()
    var current_named_rule = ""

    var text:String {
        get {
            if let capture = current_capture? {
                return current_reader!.substring(capture.start, ending_at: capture.end)
            }
            
            return ""
        }
    }
    
    init() {
        rules()
    }
    
    init(rule_def: () -> ParserRule) {
        rule_definition = rule_def
    }
    
    func add_named_rule(name:String, rule: ParserRule) {
        named_rules[name] = rule
    }
    
    func rules() {
        
    }
    
    func parse(string: String) -> Bool {
        if(!start_rule) {
            start_rule = rule_definition!()
        }
        
        captures.removeAll(keepCapacity: true)
        current_capture = nil
        
        let reader = StringReader(string: string)
        
        if(start_rule!(parser: self, reader: reader)) {
            current_reader = reader
            
            for capture in captures {
                current_capture = capture
                
                capture.action()
            }

            current_reader = nil
            current_capture = nil
            return true
        }
        
        return false
    }
}

