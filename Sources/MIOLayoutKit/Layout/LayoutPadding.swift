//
//  File.swift
//  
//
//  Created by David Trallero on 30/7/21.
//

import Foundation


public class Padding: VStack<LayoutItem> {
    var padded_item: LayoutItem
    var edge_sizes: EdgeSizes
    
    public init ( _ item: LayoutItem
                , top: ItemSize = .none, right: ItemSize = .none, bottom: ItemSize = .none, left: ItemSize = .none
                , flex: Int = 0, id: String? = nil
                ) {
        self.padded_item = item
        edge_sizes = .init( top: top, right: right, bottom: bottom, left: left )
        super.init( flex, id )
        
        let hstack = HStack( 1 )
        
        if left.rawValue > 0 { hstack.add( Space( left ) ) }
        hstack.add( item )
        if right.rawValue > 0 { hstack.add( Space( right ) ) }

        if top.rawValue > 0 { add( Space( top ) ) }

        add( hstack )
        
        if bottom.rawValue > 0 { add( Space( top ) ) }
    }
    
    override open func clone ( ) -> Padding {
        let ret = Padding( padded_item.clone()
        , top: edge_sizes.top
        , right: edge_sizes.right
        , bottom: edge_sizes.bottom
        , left: edge_sizes.left
        , flex: flex
        , id: id
        )
        ret.copyValues( self )
        return ret
    }
}
