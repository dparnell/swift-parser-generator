import Foundation

public typealias ParserFunction = (_ parser: Parser, _ reader: Reader) -> Bool
public typealias ParserAction = (_ parser: Parser) throws -> ()
public typealias ParserActionWithoutParameter = () throws -> ()

/** Definition of a grammar for the parser. Can be reused between multiple parsings. */
public class Grammar {
	/** This rule determines what is seen as 'whitespace' by the '~~'  operator, which allows
	whitespace between two following items.*/
	public var whitespace: ParserRule = (" " | "\t" | "\r\n" | "\r" | "\n")*

	/** The start rule for this grammar. */
	public var startRule: ParserRule! = nil
	internal var namedRules: [String: ParserRule] = [:]

	public init() {
	}

	public init(_ creator: (Grammar) -> (ParserRule)) {
		self.startRule = creator(self)
	}

	public subscript(name: String) -> ParserRule {
		get {
			return self.namedRules[name]!
		}
		set(newValue) {
			self.namedRules[name] = newValue
		}
	}
}

open class Parser {
	public struct ParserCapture : CustomStringConvertible {
		public var start: Int
		public var end: Int
		public var action: ParserAction
		let reader: Reader

		var text: String {
			return reader.substring(start, ending_at:end)
		}

		public var description: String {
			return "[\(start),\(end):\(text)]"
		}
	}

	public var debugRules = false
	public var captures: [ParserCapture] = []
	public var currentCapture: ParserCapture?
	public var lastCapture: ParserCapture?
	public var currentReader: Reader?
	public var grammar: Grammar
	internal var matches: [ParserRule: [Int: Bool]] = [:]

	public var text: String {
		get {
			if let capture = currentCapture {
				return capture.text
			}

			return ""
		}
	}

	public init() {
		self.grammar = Grammar()
	}

	public init(grammar: Grammar) {
		self.grammar = grammar
	}

	public func parse(_ string: String) throws -> Bool {
		matches.removeAll(keepingCapacity: false)
		captures.removeAll(keepingCapacity: false)
		currentCapture = nil
		lastCapture = nil

		defer {
			currentReader = nil
			currentCapture = nil
			lastCapture = nil
			matches.removeAll(keepingCapacity: false)
			captures.removeAll(keepingCapacity:false)
		}

		let reader = StringReader(string: string)

		if(grammar.startRule!.matches(self, reader)) {
			currentReader = reader

			for capture in captures {
				lastCapture = currentCapture
				currentCapture = capture
				try capture.action(self)
			}
			return true
		}

		return false
	}

	var depth = 0

	func leave(_ name: String) {
		if(debugRules) {
			self.out("-- \(name)")
		}
		depth -= 1
	}

	func leave(_ name: String, _ res: Bool) {
		if(debugRules) {
			self.out("-- \(name):\t\(res)")
		}
		depth -= 1
	}

	func enter(_ name: String) {
		depth += 1
		if(debugRules) {
			self.out("++ \(name)")
		}
	}

	func out(_ name: String) {
		var spaces = ""
		for _ in 0..<depth-1 {
			spaces += "  "
		}
		print("\(spaces)\(name)")
	}
}

public class ParserRule: Hashable {
	internal var function: ParserFunction

	public init(_ function: @escaping ParserFunction) {
		self.function = function
	}

	public func matches(_ parser: Parser, _ reader: Reader) -> Bool {
		return self.function(parser, reader)
	}

	public var hashValue: Int {
		return ObjectIdentifier(self).hashValue
	}

	public static func ==(lhs: ParserRule, rhs: ParserRule) -> Bool {
		return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
	}
}

public final class ParserMemoizingRule: ParserRule {
	public override func matches(_ parser: Parser, _ reader: Reader) -> Bool {
		let position = reader.position
		if let m = parser.matches[self]?[position] {
			return m
		}
		let r = self.function(parser, reader)

		if parser.matches[self] == nil {
			parser.matches[self] = [position: r]
		}
		else {
			parser.matches[self]![position] = r
		}
		return r
	}
}

// EOF operator
postfix operator *!*

public postfix func *!* (rule: ParserRule) -> ParserRule {
    return ParserRule { (parser: Parser, reader: Reader) -> Bool in
        return rule.matches(parser, reader) && reader.eof()
    }
}

// call a named rule - this allows for cycles, so be careful!
prefix operator ^
public prefix func ^(name:String) -> ParserRule {
    return ParserMemoizingRule { (parser: Parser, reader: Reader) -> Bool in
		// TODO: check stack to see if this named rule is already on there to prevent loops
        parser.enter("named rule: \(name)")
		let result = parser.grammar[name].function(parser, reader)
		parser.leave("named rule: \(name)",result)
		return result
    }
}

// match a regex
#if !os(Linux)
prefix operator %!
public prefix func %!(pattern:String) -> ParserRule {
    return ParserRule { (parser: Parser, reader: Reader) -> Bool in
        parser.enter("regex '\(pattern)'")
        
        let pos = reader.position
        
        var found = true
        let remainder = reader.remainder()
        do {
            let re = try NSRegularExpression(pattern: pattern, options: [])
            let target = remainder as NSString
            let match = re.firstMatch(in: remainder, options: [], range: NSMakeRange(0, target.length))
            if let m = match {
                let res = target.substring(with: m.range)
                // reset to end of match
                reader.seek(pos + res.characters.count)
                
                parser.leave("regex", true)
                return true
            }
        } catch {
            found = false
        }
        
        if(!found) {
            reader.seek(pos)
            parser.leave("regex", false)
        }
        return false
    }
}
#endif

// match a literal string
prefix operator %
public prefix func %(lit:String) -> ParserRule {
    return literal(lit)
}

public func literal(_ string:String) -> ParserRule {
    return ParserRule { (parser: Parser, reader: Reader) -> Bool in
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
    return ParserRule { (parser: Parser, reader: Reader) -> Bool in
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
    return ParserRule { (parser: Parser, reader: Reader) -> Bool in
        return !rule.matches(parser, reader)
    }
}

public prefix func !(lit: String) -> ParserRule {
    return !literal(lit)
}

// match one or more
postfix operator +
public postfix func + (rule: ParserRule) -> ParserRule {
    return ParserRule { (parser: Parser, reader: Reader) -> Bool in
        let pos = reader.position
        var found = false
        var flag: Bool

        parser.enter("one or more")
        
        repeat {
            flag = rule.matches(parser, reader)
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
postfix operator *
public postfix func * (rule: ParserRule) -> ParserRule {
    return ParserRule { (parser: Parser, reader: Reader) -> Bool in
        var flag: Bool
        var matched = false
        parser.enter("zero or more")
        
        repeat {
            let pos = reader.position
            flag = rule.matches(parser, reader)
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
postfix operator /~
public postfix func /~ (rule: ParserRule) -> ParserRule {
    return ParserRule { (parser: Parser, reader: Reader) -> Bool in
        parser.enter("optionally")
        
        let pos = reader.position
        if(!rule.matches(parser, reader)) {
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
    return ParserMemoizingRule { (parser: Parser, reader: Reader) -> Bool in
        parser.enter("|")
        let pos = reader.position
        var result = left.matches(parser, reader)
        if(!result) {
			reader.seek(pos)
            result = right.matches(parser, reader)
        }
    
        if(!result) {
            reader.seek(pos)
        }
        
        parser.leave("|", result)
        return result
    }
}

precedencegroup MinPrecedence {
	associativity: left
	higherThan: AssignmentPrecedence
}

precedencegroup MaxPrecedence {
	associativity: left
	higherThan: MinPrecedence
}

// match all
infix operator  ~ : MinPrecedence

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
    return ParserRule { (parser: Parser, reader: Reader) -> Bool in
        parser.enter("~")
        let res = left.matches(parser, reader) && right.matches(parser, reader)
        parser.leave("~", res)
        return res
    }
}

// on match
infix operator => : MaxPrecedence

public func => (rule : ParserRule, action: @escaping ParserAction) -> ParserRule {
    return ParserRule { (parser: Parser, reader: Reader) -> Bool in
        let start = reader.position
        let capture_count = parser.captures.count
        
        parser.enter("=>")
        
        if(rule.matches(parser, reader)) {
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

public func => (rule : ParserRule, action: @escaping ParserActionWithoutParameter) -> ParserRule {
	return rule => { _ in
		try action()
	}
}

/** The ~~ operator matches two following elements, optionally with whitespace (Parser.whitespace) in between. */
infix operator  ~~ : MinPrecedence

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
	return ParserRule { (parser: Parser, reader: Reader) -> Bool in
		return left.matches(parser, reader) && parser.grammar.whitespace.matches(parser, reader) && right.matches(parser, reader)
	}
}

/** Parser rule that matches the given parser rule at least once, but possibly more */
public postfix func ++ (left: ParserRule) -> ParserRule {
	return left ~~ left*
}

