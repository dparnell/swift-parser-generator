//
//  Reader.swift
//  SwiftParser
//
//  Created by Daniel Parnell on 17/06/2014.
//  Copyright (c) 2014 Daniel Parnell. All rights reserved.
//

import Foundation

public protocol Reader {
    var position: Int { get }
    
    func seek(_ position: Int)
    func read() -> Character
    func substring(_ starting_at:Int, ending_at:Int) -> String
    func eof() -> Bool
    func remainder() -> String
}
