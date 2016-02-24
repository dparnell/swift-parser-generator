//
//  Parser.swift
//  SwiftParser
//
//  Created by Daniel Parnell on 17/06/2014.
//  Copyright (c) 2014 Daniel Parnell. All rights reserved.
//

import Foundation

public typealias ParserRule = (parser: Parser, reader: Reader) -> Bool
public typealias ParserAction = () -> ()

// EOF operator
postfix operator *!* {}
public postfix func *!* (rule: ParserRule) -> ParserRule {
    return {(parser: Parser, reader: Reader) -> Bool in
        return rule(parser: parser, reader: reader) && reader.eof()
    }
}

// call a named rule - this allows for cycles, so be careful!
prefix operator ^ {}
public prefix func ^(name:String) -> ParserRule {
    return {(parser: Parser, reader: Reader) -> Bool in
        parser.enter("named rule: \(name)")
        
        // check to see if this would cause a recursive loop?
        if(parser.current_named_rule != name) {
            let old_named_rule = parser.current_named_rule
            let rule = parser.named_rules[name]
        
            parser.current_named_rule = name
            let result = rule!(parser: parser, reader: reader)
            parser.current_named_rule = old_named_rule
            
            parser.leave("named rule: \(name)",result)
            return result
        }
        
        parser.leave("named rule: - blocked", false)
        return false
    }
}

// match a regex
prefix operator %! {}
public prefix func %!(pattern:String) -> ParserRule {
    return {(parser: Parser, reader: Reader) -> Bool in
        parser.enter("regex '\(pattern)'")
        
        let pos = reader.position
        
        var found = true
        let remainder = reader.remainder()
        do {
            let re = try NSRegularExpression(pattern: pattern, options: [])
            let target = remainder as NSString
            let match = re.firstMatchInString(remainder, options: [], range: NSMakeRange(0, target.length))
            if let m = match {
                let res = target.substringWithRange(m.range)
                // reset to end of match
                reader.seek(pos + res.characters.count)
                
                parser.leave("regex", true)
                return true
            }
        } catch _ as NSError {
            found = false
        }
        
        if(!found) {
            reader.seek(pos)
            parser.leave("regex", false)
        }
        return false
    }
}

// match a literal string
prefix operator % {}
public prefix func %(lit:String) -> ParserRule {
    return literal(lit)
}

public func literal(string:String) -> ParserRule {
    return {(parser: Parser, reader: Reader) -> Bool in
        parser.enter("literal '\(string)'")
        
        let pos = reader.position
        
        for ch in string.characters {
            let flag = ch == reader.read()
            if !flag {
                reader.seek(pos)
                
                parser.leave("literal", false)
                return false
            }
        }
        
        parser.leave("literal", true)
        return true
    }
}

// match a range of characters eg: "0"-"9"
public func - (left: Character, right: Character) -> ParserRule {
    return {(parser: Parser, reader: Reader) -> Bool in
        parser.enter("range [\(left)-\(right)]")
        
        let pos = reader.position
        
        let lower = String(left)
        let upper = String(right)
        let ch = String(reader.read())
        let found = (lower <= ch) && (ch <= upper)
        parser.leave("range \t\t\(ch)", found)
        
        if(!found) {
            reader.seek(pos)
        }
        
        return found
    }
}

// invert match
public prefix func !(rule: ParserRule) -> ParserRule {
    return {(parser: Parser, reader: Reader) -> Bool in
        return !rule(parser: parser, reader: reader)
    }
}

public prefix func !(lit: String) -> ParserRule {
    return !literal(lit)
}

// match one or more
postfix operator + {}
public postfix func + (rule: ParserRule) -> ParserRule {
    return {(parser: Parser, reader: Reader) -> Bool in
        let pos = reader.position
        var found = false
        var flag: Bool

        parser.enter("one or more")
        
        repeat {
            flag = rule(parser: parser, reader: reader)
            found = found || flag
        } while(flag)
        
        if(!found) {
            reader.seek(pos)
        }
        
        parser.leave("one or more", found)
        return found
    }
}

public postfix func + (lit: String) -> ParserRule {
    return literal(lit)+
}


// match zero or more
postfix operator * {}
public postfix func * (rule: ParserRule) -> ParserRule {
    return {(parser: Parser, reader: Reader) -> Bool in
        var flag: Bool
        var matched = false
        parser.enter("zero or more")
        
        repeat {
            let pos = reader.position
            flag = rule(parser: parser, reader: reader)
            if(!flag) {
                reader.seek(pos)
            } else {
                matched = true
            }
        } while(flag)
        
        parser.leave("zero or more", matched)
        return true
    }
}

public postfix func * (lit: String) -> ParserRule {
    return literal(lit)*
}

// optional
postfix operator /~ {}
public postfix func /~ (rule: ParserRule) -> ParserRule {
    return {(parser: Parser, reader: Reader) -> Bool in
        parser.enter("optionally")
        
        let pos = reader.position
        if(!rule(parser: parser, reader: reader)) {
            reader.seek(pos)
        }

        parser.leave("optionally", true)
        return true
    }
}

public postfix func /~ (lit: String) -> ParserRule {
    return literal(lit)/~
}

// match either
public func | (left: String, right: String) -> ParserRule {
    return literal(left) | literal(right)
}

public func | (left: String, right: ParserRule) -> ParserRule {
    return literal(left) | right
}

public func | (left: ParserRule, right: String) -> ParserRule {
    return left | literal(right)
}

public func | (left: ParserRule, right: ParserRule) -> ParserRule {
    return {(parser: Parser, reader: Reader) -> Bool in
        parser.enter("|")
        let pos = reader.position
        var result = left(parser: parser, reader: reader)
        if(!result) {
			reader.seek(pos)
            result = right(parser: parser, reader: reader)
        }
    
        if(!result) {
            reader.seek(pos)
        }
        
        parser.leave("|", result)
        return result
    }
}

// match all
infix operator  ~ {associativity left precedence 10}
public func ~ (left: String, right: String) -> ParserRule {
    return literal(left) ~ literal(right)
}

public func ~ (left: String, right: ParserRule) -> ParserRule {
    return literal(left) ~ right
}

public func ~ (left: ParserRule, right: String) -> ParserRule {
    return left ~ literal(right)
}

public func ~ (left : ParserRule, right: ParserRule) -> ParserRule {
    return {(parser: Parser, reader: Reader) -> Bool in
        parser.enter("~")
        let res = left(parser: parser, reader: reader) && right(parser: parser, reader: reader)
        parser.leave("~", res)
        return res
    }
}

// on match
infix operator => {associativity right precedence 100}
public func => (rule : ParserRule, action: ParserAction) -> ParserRule {
    return {(parser: Parser, reader: Reader) -> Bool in
        let start = reader.position
        let capture_count = parser.captures.count
        
        parser.enter("=>")
        
        if(rule(parser: parser, reader: reader)) {
            let capture = Parser.ParserCapture(start: start, end: reader.position, action: action, reader: reader)
            
            parser.captures.append(capture)
            parser.leave("=>", true)
            return true
        }
        
        while(parser.captures.count > capture_count) {
            parser.captures.removeLast()
        }
        parser.leave("=>", false)
        return false
    }
}

/** The ~~ operator matches two following elements, optionally with whitespace (Parser.whitespace) in between. */
infix operator  ~~ {associativity left precedence 10}
public func ~~ (left: String, right: String) -> ParserRule {
	return literal(left) ~~ literal(right)
}

public func ~~ (left: String, right: ParserRule) -> ParserRule {
	return literal(left) ~~ right
}

public func ~~ (left: ParserRule, right: String) -> ParserRule {
	return left ~~ literal(right)
}

public func ~~ (left : ParserRule, right: ParserRule) -> ParserRule {
	return {(parser: Parser, reader: Reader) -> Bool in
		return left(parser: parser, reader: reader) && parser.whitespace(parser: parser, reader: reader) && right(parser: parser, reader: reader)
	}
}

public typealias ParserRuleDefinition = () -> ParserRule
infix operator <- {}
public func <- (left: Parser, right: ParserRuleDefinition) -> () {
    left.rule_definitions.append(right)
}

public class Parser {
    public struct ParserCapture : CustomStringConvertible {
        public var start: Int
        public var end: Int
        public var action: ParserAction
        let reader:Reader

		var text: String {
            return reader.substring(start, ending_at:end)
        }

        public var description: String {
            return "[\(start),\(end):\(text)]"
        }
    }
    
    public var rule_definition: ParserRuleDefinition?
    public var rule_definitions: [ParserRuleDefinition] = []
    public var start_rule: ParserRule?
    public var debug_rules = false

    public var captures: [ParserCapture] = []
    public var current_capture:ParserCapture?
    public var last_capture:ParserCapture?
    public var current_reader:Reader?

	var named_rules: Dictionary<String,ParserRule> = Dictionary<String,ParserRule>()
    var current_named_rule = ""

	/** This rule determines what is seen as 'whitespace' by the '~~'  operator, which allows whitespace between two
	 following items.*/
	public var whitespace: ParserRule = (" " | "\t" | "\r\n" | "\r" | "\n")*

    public var text:String {
        get {
            if let capture = current_capture {
                return capture.text
            }
            
            return ""
        }
    }
    
    public init() {
        rules()
    }
    
    public init(rule_def: () -> ParserRule) {
        rule_definition = rule_def
    }
    
    public func add_named_rule(name:String, rule: ParserRule) {
        named_rules[name] = rule
    }
    
    public func rules() {
        
    }
    
    public func parse(string: String) -> Bool {
        if(start_rule == nil) {
            start_rule = rule_definition!()
        }
        
        captures.removeAll(keepCapacity: true)
        current_capture = nil
        last_capture = nil
        
        let reader = StringReader(string: string)
        
        if(start_rule!(parser: self, reader: reader)) {
            current_reader = reader
            
            for capture in captures {
                last_capture = current_capture
                current_capture = capture
                capture.action()
            }

            current_reader = nil
            current_capture = nil
            last_capture = nil
            return true
        }
        
        return false
    }
    
    var depth = 0
    func leave(name:String) {
        if(debug_rules) {
            self.out("-- \(name)")
        }
        depth--
    }
    func leave(name:String, _ res:Bool) {
        if(debug_rules) {
            self.out("-- \(name):\t\(res)")
        }
        depth--
    }
    func enter(name:String) {
        depth++
        if(debug_rules) {
            self.out("++ \(name)")
        }
    }
    func out(name:String) {
        var spaces = ""
        for _ in 0..<depth-1 {
            spaces += "  "
        }
        print("\(spaces)\(name)")
    }
    
}

