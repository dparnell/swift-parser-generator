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
            return string.distance(from: string.startIndex, to: index)
        }
    }
    
    init(string: String) {
        self.string = string
        index = string.startIndex;
    }
    
    public func seek(_ position:Int) {
        index = string.index(string.startIndex, offsetBy: position)
    }
    
    public func read() -> Character {
        if index != string.endIndex {
            let result = string[index]
            index = string.index(after: index)
            
            return result;
        }
        
        return "\u{2004}";
    }
    
    public func eof() -> Bool {
        return index == string.endIndex
    }
    
    public func remainder() -> String {
      return string.substring(from: index)
    }
  
    public func substring(_ starting_at:Int, ending_at:Int) -> String {
        return string.substring(with: string.index(string.startIndex, offsetBy: starting_at)..<string.index(string.startIndex, offsetBy: ending_at))
    }
    
}
