//
//  SwiftParserTests.swift
//  SwiftParserTests
//
//  Created by Daniel Parnell on 17/06/2014.
//  Copyright (c) 2014 Daniel Parnell. All rights reserved.
//

import XCTest
import SwiftParser

class SwiftParserTests: XCTestCase {
    
    class Calculator {
        var stack: [Double] = []
        var _negative = false
        
        var result: Double {
        get { return stack[stack.count-1] }
        }
        
        func performBinaryOperation(op: (left: Double, right: Double) -> Double) {
            var right = stack.removeLast()
            var left = stack.removeLast()
            
            stack.append(op(left: left, right: right))
        }
        
        func add() {
            performBinaryOperation({(left: Double, right: Double) -> Double in
                return left + right
                })
        }
        
        func divide() {
            performBinaryOperation({(left: Double, right: Double) -> Double in
                return left / right
                })
        }
        
        func exponent() {
            performBinaryOperation({(left: Double, right: Double) -> Double in
                return pow(left, right)
                })
        }
        
        func multiply() {
            performBinaryOperation({(left: Double, right: Double) -> Double in
                return left * right
                })
            
        }
        
        func subtract() {
            performBinaryOperation({(left: Double, right: Double) -> Double in
                return left - right
                })
            
        }
        
        func negative() {
            _negative = !_negative
        }
        
        func pushNumber(text: String) {
            var value: Double = 0
            var decimal = -1
            var counter = 0
            for ch in text.utf8 {
                if(ch == 46) {
                    decimal = counter
                } else {
                    let digit: Int = Int(ch) - 48
                    value = value * Double(10.0) + Double(digit)
                    counter = counter + 1
                }
            }
            
            if(decimal >= 0) {
                value = value / pow(10.0, Double(counter - decimal))
            }
            
            if(_negative) {
                value = -value
            }
            
            stack.append(value)
        }
        
    }
    
    class Arith: Parser {
        var calculator = Calculator()
        
        func push() {
            calculator.pushNumber(text)
        }
        
        func add() {
            calculator.add()
        }
        
        func sub() {
            calculator.subtract()
        }
        
        func mul() {
            calculator.multiply()
        }
        
        func div() {
            calculator.divide()
        }
        
        override func rules() {
            start_rule = (^"primary")*!*
            
            let number = ("0"-"9")+ => push
            add_named_rule("primary",   rule: ^"secondary" ~ (("+" ~ ^"secondary" => add) | ("-" ~ ^"secondary" => sub))*)
            add_named_rule("secondary", rule: ^"tertiary" ~ (("*" ~ ^"tertiary" => mul) | ("/" ~ ^"tertiary" => div))*)
            add_named_rule("tertiary",  rule: ("(" ~ ^"primary" ~ ")") | number)
        }
    }
    
    // A recursive parser like the following will always fail as it results in an infinite recursive loop.  Code has been added to try to catch this, but you have been warned!
    class RecursiveArith : Arith {
        override func rules() {
            start_rule = (^"term")*!*
            
            let num = ("0"-"9")+ => push
            add_named_rule("term", rule: ((^"term" ~ "+" ~ ^"fact") => add) | ((^"term" ~ "-" ~ ^"fact") => sub) | ^"fact")
            add_named_rule("fact", rule: ((^"fact" ~ "*" ~ ^"term") => mul) | ((^"fact" ~ "/" ~ ^"term") => div) | ("(" ~ ^"term" ~ ")") | num)
        }
    }

   
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testSimple() {
        let a = Arith()
        XCTAssert(a.parse("1+2"))
        XCTAssertEqual(a.calculator.result, 3)
    }

    func testComplex() {
        let a = Arith()
        XCTAssert(a.parse("6*7-3+20/2-12+(30-5)/5"))
        XCTAssertEqual(a.calculator.result, 42)
    }

    func testRecursiveSimple() {
        let a = RecursiveArith()
        XCTAssertFalse(a.parse("1+2"))
    }
    
    func testRecursiveComplex() {
        let a = RecursiveArith()
        
        XCTAssertFalse(a.parse("6*7-3+20/2-12+(30-5)/5"))
    }
    
    func testShouldNotParse() {
        let a = Arith()
        XCTAssertFalse(a.parse("1+"))
        XCTAssertFalse(a.parse("xxx"))
    }
}
