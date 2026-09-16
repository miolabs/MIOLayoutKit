//
//  File.swift
//  
//
//  Created by David Trallero on 22/06/2021.
//

import Foundation

public enum TextAlign: Int
{
    case left   = 0
    case center = 1
    case right  = 2
}

public enum TextWrap: Int
{
    case wrap   = 0
    case noWrap = 1
}


public class Text: LayoutItem {
    public var original_text: String
    public var text: String
    public var align: TextAlign
    public var wrap: TextWrap
    public var italic: Bool
    public var bold: Bool
    public var text_size: ItemSize
    public var formmatterType: FormatterType
    
    public init ( _ text: String, flex: Int = 0, id: String? = nil, textSize: ItemSize = .s, bold: Bool = false, italic: Bool = false, align: TextAlign = .left, wrap: TextWrap = .wrap, formatterType: FormatterType = .string ) {
        self.original_text = text
        self.text          = text
        self.text_size = textSize
        self.align = align
        self.wrap  = wrap
        self.italic = italic
        self.bold = bold
        self.formmatterType = formatterType
        super.init()
        self.flex = flex
        self.id = id
    }

    public override func clone ( ) -> Text {
        let ret = Text( original_text )
        ret.copyValues( self )
        
        return ret
    }
    
    public func copyValues (_ src: Text ) {
        original_text = src.text
        text          = src.text
        text_size     = src.text_size
        align         = src.align
        wrap          = src.wrap
        italic        = src.italic
        bold          = src.bold
        formmatterType = src.formmatterType
        super.copyValues( src as LayoutItem )
    }
    
    override func setValue(_ value: Any) throws {
        if let new_text = value as? String {
            text = new_text
        }
    }
    
    override open func shallowCopy ( ) -> LayoutItem {
        var ret = Text( text )
        copyTextValues( &ret )
        
        return ret
    }
    
    open func copyTextValues ( _ ret: inout Text ) {
        ret.copyValues( self )
        ret.text = text
        ret.align = align
        ret.wrap = wrap
        ret.italic = italic
        ret.bold = bold
        ret.text_size = text_size
        ret.formmatterType = formmatterType
    }
    
}



public class LocalizedText: Text {
    func apply_translation ( _ d: [String:String] ) {
       self.text = d[ self.original_text ] ?? self.original_text
    }
}
