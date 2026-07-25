//
//  LayoutPage.swift
//  
//
//  Created by David Trallero on 22/06/2021.
//

import Foundation

public class Page: FooterHeaderContainer<LayoutItem, LayoutItem>
{
    public var page_num: Int
    public var margins: Margin
    
    public init ( _ size: Size, _ num: Int = 0 ) {
        self.page_num = num
        self.margins = Margin( )
        super.init()
        self.size = size
        self.dimensions = size
    }
    
    public override func clone ( ) -> Page {
        let ret = Page( size, page_num )
        ret.copyValues( self )
        
        return ret
    }
    
    public func copyValues (_ src: Page ) {
        page_num = src.page_num
        margins = src.margins
        super.copyValues( src as FooterHeaderContainer<LayoutItem, LayoutItem> )
    }
    
    override open func meassure ( _ context: RenderContext )
    {
        // DO NOT modify the size of a page, as renders treat them in special way
        let initial_size = size
        
        super.meassure( context )
        
        size = initial_size
    }
    
    open func setMargins( _ margins: Margin ) {
        self.margins = margins
        self.dimensions = Size( width: self.size.width - margins.left - margins.right
                              , height: self.size.height - margins.top - margins.bottom )
    }
    
    open func newPage ( _ pageNumber: Int ) -> Page {
        let ret = Page( size )
        ret.setMargins( margins )
        
        if header != nil && should_include( pageNumber, header!.include_in_pages ) {
            ret.header = self.header
        }

        if footer != nil && should_include( pageNumber, footer!.include_in_pages ) {
            ret.footer = self.footer
        }
        
        return ret
    }
} // even / odd header
// render => is first child of page


public class A4: Page {
    // TODO: find a way to subclass or extend from other renders
    public static var portraitSize = Size( width: 595, height: 842 )
    public static var landscapeSize = Size( width: 842, height: 595 )
    
    public static func portrait() -> A4 { return A4( A4.portraitSize ) }
    public static func lanscape() -> A4 { return A4( A4.landscapeSize ) }
    
    public convenience init ( ) { self.init( A4.portraitSize ) }
    

}
