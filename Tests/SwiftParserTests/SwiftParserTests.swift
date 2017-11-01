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

		func performBinaryOperation(_ op: (_ left: Double, _ right: Double) -> Double) {
			let right = stack.removeLast()
			let left = stack.removeLast()

			stack.append(op(left, right))
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

		func pushNumber(_ text: String) {
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

		func push(_ text: String) {
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

		override init() {
			super.init()

			self.grammar = Grammar { [unowned self] g in
				g["number"] = ("0"-"9")+ => { [unowned self] parser in self.push(parser.text) }

				g["primary"] = ^"secondary" ~ (("+" ~ ^"secondary" => add) | ("-" ~ ^"secondary" => sub))*
				g["secondary"] = ^"tertiary" ~ (("*" ~ ^"tertiary" => mul) | ("/" ~ ^"tertiary" => div))*
				g["tertiary"] = ("(" ~ ^"primary" ~ ")") | ^"number"

				return (^"primary")*!*
			}
		}
	}

	func testSimple() {
		let a = Arith()
		XCTAssert(try a.parse("1+2"))
		XCTAssertEqual(a.calculator.result, 3)
	}

	func testComplex() {
		let a = Arith()
		XCTAssert(try a.parse("6*7-3+20/2-12+(30-5)/5"))
		XCTAssertEqual(a.calculator.result, 42)
	}

	func testShouldNotParse() {
		let a = Arith()
		XCTAssertFalse(try a.parse("1+"))
		XCTAssertFalse(try a.parse("xxx"))
	}
}
