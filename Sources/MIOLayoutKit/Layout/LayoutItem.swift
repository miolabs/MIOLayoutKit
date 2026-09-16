//
//  File.swift
//  
//
//  Created by David Trallero on 22/06/2021.
//

import Foundation


public protocol AddProtocol {
    func onItemAdded ( _ idem: LayoutItem )
}


open class LayoutItem {
    var include_in_pages: IncludeInPage = .here
    var parent:LayoutItem?
    var id: String?
    var flex: Int
    var x: Float
    var y: Float
    var size: Size
    var dimensions: Size
    var is_unbreakable: Bool
    public var style: Style
    
    public init ( _ flex: Int = 0, _ id: String? = nil ) {
        self.id = id
        self.flex = flex
        self.x = 0
        self.y = 0
        self.dimensions = Size( )
        self.size = Size( )
        self.style = Style( )
        self.is_unbreakable = false
    }
    
    open func unbreakable ( ) -> LayoutItem {
        is_unbreakable = true
        return self
    }
    
    open func clone ( ) -> LayoutItem {
        // LayoutItem is so simple that clone is like a shallowCopy
        return shallowCopy( )
    }
    
    open func shallowCopy ( ) -> LayoutItem {
        let ret = LayoutItem( flex, id )
        ret.copyValues( self )
        
        return ret
    }
    
    open func copyValues ( _ src: LayoutItem ) {
        flex = src.flex
        id = src.id
        x = src.x
        y = src.y
        dimensions = src.dimensions
        size = src.size
        parent = src.parent
        include_in_pages = src.include_in_pages
        is_unbreakable = src.is_unbreakable
        
        style.copyValues( src.style )
    }
    
    @discardableResult
    public func bgColor ( _ bg: String ) -> LayoutItem {
        style.bgColor = bg
        return self
    }
        
    @discardableResult
    public func fgColor ( _ fg: String ) -> LayoutItem {
        style.fgColor = fg
        return self
    }
        
    func setValue ( _ value: Any ) throws { }
    
    open func meassure ( _ context: RenderContext ) {
        self.size = context.meassure( self )
    }

    func setDimension ( _ dim: Size ) {
        // TODO: Decide how to resize de image
        // - mantain aspect ratio:
        //   - cover
        //   - contain
        // - else:
        //   - resize
        dimensions = dim
    }
    
    func setCoordinates ( _ x: Float, _ y: Float ) {
        self.x = x
        self.y = y
    }
    
    func render ( _ context: RenderContext ) {
        context.renderItem( self )
    }
    
    func notifyAdded ( _ delegate: AddProtocol ) {
        delegate.onItemAdded( self )
    }
    
    func absPosition() -> (x:Float, y:Float) {
        var abs_x = x
        var abs_y = y
        var p = parent
        
        while (p != nil) {
            abs_x += p!.x
            abs_y += p!.y
            p = p!.parent
        }
        
        return (x:abs_x, y: abs_y)
    }
    
}


