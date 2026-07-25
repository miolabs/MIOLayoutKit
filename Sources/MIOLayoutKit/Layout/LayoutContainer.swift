//
//  File.swift
//  
//
//  Created by David Trallero on 22/06/2021.
//

import Foundation


public class Container< E: LayoutItem >: LayoutItem {
    var children: [E]
    public var delegate: AddProtocol?
    var growDirection: SizeGrowDirection
    
    public override init ( _ flex: Int = 0, _ id: String? = nil ) {
        children = []
        self.delegate = nil
        self.growDirection = .both
        
        super.init( flex, id )
    }
    
    public override func clone ( ) -> Container< E > {
        let ret = Container< E >( flex, id )
        ret.copyValues( self )
        
        return ret
    }
    
    public func copyValues(_ src: Container<E> ) {
        delegate = src.delegate
        growDirection = src.growDirection
        children = src.children.map{ $0.clone( ) as! E }
        super.copyValues( src as LayoutItem )
    }
    
    public func add ( _ item: E ) {
        children.append( item )
        
        item.parent = self
        if delegate != nil {
            item.notifyAdded( delegate! )
        }
    }

    override func notifyAdded ( _ delegate: AddProtocol ) {
        self.delegate = delegate

        for child in children {
            child.notifyAdded( delegate )
        }
    }
    
    override open func meassure ( _ context: RenderContext )
    {
        var dim = Size( )
        
        for c in children {
            c.meassure( context )
            dim = dim.join( c.size, growDirection )
        }

        size = dim
    }
    
    override func setDimension(_ dim: Size) {
        super.setDimension( flex == 0 ? size : dim )
        
        for c in children { c.setDimension( dimensions ) }
    }
    
    override func setCoordinates ( _ x: Float, _ y: Float ) {
        for c in children { c.setCoordinates( x, y ) }
    }
    
    override func render ( _ context: RenderContext ) {
        context.beginContainer( self as! Container<LayoutItem>)
          for c in children { c.render( context ) }
        context.endContainer( self as! Container<LayoutItem> )
    }
    
    open func translate_container ( _ translations: [String: String] ) {
        for child in children {
            if let text = child as? LocalizedText {
                text.apply_translation( translations )
            }
            else if let cont = child as? Container {
                cont.translate_container( translations )
            }
        }
    }
}

public class FooterHeaderContainer< H:LayoutItem, F: LayoutItem> : VStack<LayoutItem> {
    var header: H?
    var footer: F?
    public var hideHeader: Bool
    public var hideFooter: Bool

    init ( header: H? = nil, footer: F? = nil ) {
        self.header = header
        self.footer = footer

        self.hideHeader = false
        self.hideFooter = false

        super.init()

        self.header?.parent = self
        self.footer?.parent = self        
    }

    public override func clone ( ) -> FooterHeaderContainer< H, F > {
        let ret = FooterHeaderContainer( header: header?.clone() as? H
                                       , footer: footer?.clone() as? F )
        ret.copyValues( self )
        
        return ret
    }
    
    public func copyValues (_ src: FooterHeaderContainer< H, F > ) {
        hideFooter = src.hideFooter
        hideHeader = src.hideHeader
        super.copyValues( src as VStack<LayoutItem> )
    }
}

