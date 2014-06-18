//
//  StringReader.swift
//  SwiftParser
//
//  Created by Daniel Parnell on 17/06/2014.
//  Copyright (c) 2014 Daniel Parnell. All rights reserved.
//

import Foundation

class StringReader : Reader {
    var string: String
    var index: String.Index
    
    var position: Int {
        get {
            return distance(string.startIndex, index)
        }
    }
    
    init(string: String) {
        self.string = string
        index = string.startIndex;
    }
    
    func seek(position:Int) {
        index = advance(string.startIndex, position)
    }
    
    func read() -> Character {
        let result = string[index]
        
        if index != string.endIndex {
            index = index.succ()
        }
        
        return result;
    }
    
    func eof() -> Bool {
        return index == string.endIndex
    }
    
    func substring(starting_at:Int, ending_at:Int) -> String {
        return string.substringWithRange(Range<String.Index>(start: advance(string.startIndex, starting_at), end:  advance(string.startIndex, ending_at)))
    }
    
}