//
//  LayoutStackBuilder.swift
//  
//
//  Created by Javier Segura Perez on 11/7/22.
//

import Foundation

class EmptyLayoutItem : LayoutItem {}

@resultBuilder
public struct LayoutStackBuilder {
    
    public static func buildBlock(_ components: [LayoutItem]...) -> [LayoutItem] {
        return components.flatMap{ $0 } // LayoutItemGroup( components: components )
    }
    
    public static func buildExpression( _ expression:  LayoutItem  ) -> [LayoutItem] { [expression] }
    public static func buildExpression( _ expression: [LayoutItem] ) -> [LayoutItem] {  expression  }
    
    public static func buildOptional(_ components: [LayoutItem]?) -> [LayoutItem] {
        components ?? []
    }

    public static func buildEither(first components: [LayoutItem]) -> [LayoutItem] {
        components
    }
    
    
    public static func buildEither(second components: [LayoutItem]) -> [LayoutItem] {
        components
    }
}

extension Container
{
    public func border( color:String ) -> Self {
        self.fgColor( color )
        //self.style.borderColor = BorderColor(color, color, color, color)
        return self
    }

    public func border( topColor: String? = nil, rightColor: String? = nil, bottomColor: String? = nil, leftColor: String? = nil ) -> Self {
        self.style.borderColor = BorderColor(topColor, rightColor, bottomColor, leftColor)
        return self
    }

    public func border( width: Int = 0 ) -> Self {
        self.style.borderWidth = BorderWidth( width, width, width, width )
        return self
    }
    
    public func border( top: Int = 0, right:Int = 0, bottom:Int = 0, left:Int = 0 ) -> Self {
        self.style.borderWidth = BorderWidth( top, right, bottom, left )
        return self
    }
    
    public func border( radius:Int ) -> Self {
        self.style.borderRadius = radius
        return self
    }
}

extension HStack
{
    public convenience init (_ flex: Int, _ id:String? = nil, @LayoutStackBuilder _ content: ( ) -> [LayoutItem]) {
        self.init( flex, id )
        let group = content()
        // var array:[LayoutItem] = []
//        group.flatChildren( &array )
        for c in group {
            add( c as! E )
        }
    }
}

extension VStack
{
    public convenience init (_ flex: Int, _ id:String? = nil,  @LayoutStackBuilder _ content: ( ) -> [LayoutItem]) {
        self.init( flex, id )
        let group = content()
//        var array:[LayoutItem] = []
//        group.flatChildren( &array )
        for c in group {
            add( c as! E )
        }
    }
    
}

extension Text
{
    public func foregroundColor( _ hexColor:String ) -> Text {
        self.fgColor( hexColor )
        return self
    }

    public func backgroundColor( _ hexColor:String ) -> Text {
        self.bgColor( hexColor )
        return self
    }
    
    public func font( size:ItemSize ) -> Text {
        self.text_size = size
        return self
    }
    
    public func font( bold:Bool = false, italic:Bool = false ) -> Text {
        self.bold = bold
        self.italic = italic
        return self
    }

}

public class LayoutTableItem
{
    var fgColor:String? = nil
    var bgColor:String? = nil
    var style = Style()
    var items:[LayoutTableItem] = []
        
    public func border( color:String ) -> Self {
        self.style.borderColor = BorderColor(color, color, color, color)
        return self
    }

    public func border( topColor: String? = nil, rightColor: String? = nil, bottomColor: String? = nil, leftColor: String? = nil ) -> Self {
        self.style.borderColor = BorderColor(topColor, rightColor, bottomColor, leftColor)
        return self
    }

    public func border( width: Int = 0 ) -> Self {
        self.style.borderWidth = BorderWidth( width, width, width, width )
        return self
    }
    
    public func border( top: Int = 0, right:Int = 0, bottom:Int = 0, left:Int = 0 ) -> Self {
        self.style.borderWidth = BorderWidth( top, right, bottom, left )
        return self
    }
    
    public func border( radius:Int ) -> Self {
        self.style.borderRadius = radius
        return self
    }
    
    public func foregroundColor( _ hexColor:String ) -> Self {
        self.fgColor = hexColor
        return self
    }

    public func backgroundColor( _ hexColor:String ) -> Self {
        self.bgColor = hexColor
        return self
    }

}


@resultBuilder
public struct LayoutTableColumnBuilder {
    
    public static func buildBlock(_ components: TableColumn...) -> [TableColumn] {
        var columns:[TableColumn] = []
        columns.append(contentsOf: components )
        return columns
    }
}

public class TableColumn : LayoutTableItem
{
    public var title:String
    public var key:String
    public var flex:Int = 0
    public var align: TextAlign = .left
    public var wrap: TextWrap = .noWrap
    public var italic: Bool = false
    public var bold: Bool = false
    public var fontSize: ItemSize = .m
    
    public init(_ title:String, key: String, flex: Int = 0) {
        self.title = title
        self.key = key
        self.flex = flex
    }
    
    public func font( size: ItemSize ) -> Self {
        self.fontSize = size
        return self
    }
    
    public func font( bold:Bool = false, italic:Bool = false ) -> Self {
        self.bold = bold
        self.italic = italic
        return self
    }
    
    public func font( hexColor:String ) -> Self {
        
        self.italic = italic
        return self
    }

    
    public func align( _ value: TextAlign ) -> Self {
        self.align = value
        return self
    }
        
    public func wrap( _ value: TextWrap ) -> Self {
        self.wrap = value
        return self
    }
}



public class TableHeader : LayoutTableItem
{
    var columns:[TableColumn] = []

    public init( @LayoutTableColumnBuilder _ content: ( ) -> [TableColumn] ) {
        columns = content()
    }
}

public class TableFooter : LayoutTableItem
{
    public override init() {        
    }
}


@resultBuilder
public struct LayoutTableHeaderBuilder {

    public static func buildBlock(_ header: TableHeader, _ footer: TableFooter ) -> ( TableHeader, TableFooter? ) {
        return (header, footer)
    }

    public static func buildBlock(_ header: TableHeader ) -> ( TableHeader, TableFooter? ) {
        return (header, nil)
    }
}


extension Table
{
    public convenience init ( flex: Int = 0, _ id:String? = nil,  @LayoutTableHeaderBuilder _ content: ( ) -> (header: TableHeader, footer: TableFooter?) ) {
        self.init( flex, id )
        let header_footer = content()
        for c in header_footer.header.columns {
//            textSize: ItemSize = .m, bold: Bool = false, align: TextAlign = .left, wrap: TextWrap = .noWrap
            addColumn( c.key, c.title, flex: c.flex, textSize: c.fontSize, bold: c.bold, align: c.align, wrap: c.wrap, fgColor: c.fgColor, bgColor: c.bgColor)
        }
        self.header?.style = header_footer.header.style
        if header_footer.footer != nil { self.footer?.style = header_footer.footer!.style }
    }
}

