//
//  File.swift
//  
//
//  Created by David Trallero on 29/7/21.
//

import Foundation


public class Space: LayoutItem {
    public var a: ItemSize
    public var b: ItemSize
    
    public init ( _ a: ItemSize, _ b: ItemSize = .none ) {
        self.a = a
        self.b = b
        super.init( )
    }
    
    public override func clone ( ) -> Space {
        let ret = Space( a, b )
        ret.copyValues( self )
        
        return ret
    }
    
    public func copyValues (_ src: Space ) {
        a = src.a
        b = src.b
        super.copyValues( src as LayoutItem )
    }
}
