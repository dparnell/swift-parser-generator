//
//  StringReader.swift
//  SwiftParser
//
//  Created by Daniel Parnell on 17/06/2014.
//  Copyright (c) 2014 Daniel Parnell. All rights reserved.
//

import Foundation

public class StringReader : Reader {
    var string: String
    var index: String.Index
    
    public var position: Int {
        get {
            return string.startIndex.distanceTo(index)
        }
    }
    
    init(string: String) {
        self.string = string
        index = string.startIndex;
    }
    
    public func seek(position:Int) {
        index = string.startIndex.advancedBy(position)
    }
    
    public func read() -> Character {
        if index != string.endIndex {
            let result = string[index]
            index = index.successor()
            
            return result;
        }
        
        return "\u{2004}";
    }
    
    public func eof() -> Bool {
        return index == string.endIndex
    }
    
    public func substring(starting_at:Int, ending_at:Int) -> String {
        return string.substringWithRange(Range<String.Index>(start: string.startIndex.advancedBy(starting_at), end:  string.startIndex.advancedBy(ending_at)))
    }
    
}