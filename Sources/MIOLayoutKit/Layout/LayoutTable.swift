//
//  File.swift
//  
//
//  Created by David Trallero on 22/06/2021.
//

import Foundation

public struct TableCol {
    var key: String
    var name: Text
    
    public init ( _ key: String, _ name: Text ) {
        self.key  = key
        self.name = name
    }
}

// INDENTATION
// indentRow( X, level )
public class Table: FooterHeaderContainer< HStack<Text>, HStack<Text> > {
    var cols_key: [String]
    var body: VStack<LayoutItem>
    var max_col: [Float]
    var max_row: [Float]
    public var border: Bool

    public init ( _ flex: Int = 0, _ id: String? = nil ) {
        cols_key = []
        body     = VStack( )
        max_col  = []
        max_row  = []
        border   = true

        super.init( header: HStack( ), footer: HStack( ) )
        self.flex = flex
        self.id = id
        body.parent = self
        hideHeader = false
        hideFooter = true
    }

    public override func clone ( ) -> Table {
        let ret = Table( flex, id )
        ret.copyValues( self )
        
        return ret
    }
    
    public func copyValues (_ src: Table ) {
        cols_key = src.cols_key
        body     = src.body.clone()
        max_col  = src.max_col
        max_row  = src.max_row
        border   = src.border
        super.copyValues( src as FooterHeaderContainer< HStack<Text>, HStack<Text> > )
    }

    public func addColumn ( _ key: String, _ name: String, flex: Int = 0, id: String? = nil, textSize: ItemSize = .m, bold: Bool = false, align: TextAlign = .left, wrap: TextWrap = .noWrap, fgColor:String? = nil, bgColor:String? = nil) {
        cols_key.append( key )
        
//        // TODO Make a theme!
//        header!.bgColor( "#EAEAFD" )
        
        let header_text = LocalizedText( name, flex: flex, id: id, textSize: textSize, bold: bold, align: align, wrap: wrap )
        if fgColor != nil {
            _ = header_text.foregroundColor( fgColor! )
        }
        header!.add( header_text )
        footer!.add( Text( "", flex: flex, id: id, textSize: textSize, bold: bold, align: align, wrap: wrap ) )
    }

    public func addRow ( _ dict: [String:Any], bold: Bool = false, italic: Bool = false, textColor:String? = nil ) {
        let table_row = HStack( )
        
        for i in cols_key.indices {
            let key = cols_key[ i ]
            let col = header!.children[ i ]
            
            let txt = Text( "\(dict[ key ] ?? "")", bold: bold, italic: italic, align: col.align, wrap: col.wrap )
            if textColor != nil { _ = txt.foregroundColor(textColor!) }
            table_row.add( txt )
        }
        
        body.add( table_row )
    }
    
    public func addFooterRow ( _ dict: [String:Any], bold: Bool = false, italic: Bool = false ) {
        hideFooter = false
        
        footer!.style.borderColor.top = "#000000"
        footer!.style.borderWidth.top = 1
        
        for i in cols_key.indices {
            let key = cols_key[ i ]
            
            footer!.children[ i ].text = "\(dict[ key ] as? String ?? "")"
        }
    }
    
    public func addRow ( _ row: HStack<LayoutItem> ) {
        body.add( row )
    }
    
    override open func meassure ( _ context: RenderContext ) {
        var sz = Size( )
        
        header!.meassure( context )
        footer!.meassure( context )
        body.meassure( context )

        var max_height: Float = 0

        for c in header!.children {
            max_col.append( c.size.width )

            if max_height < c.size.height {
                max_height = c.size.height
            }
        }
        max_row.append( max_height )

        for i in header!.children.indices {
            header!.children[ i ].size = Size( width: max_col[ i ], height: max_row[ 0 ] )
        }

        
        max_height = footer!.children.reduce( 0 ) { (max_h,c) in
            max( max_h, c.size.height )
        }
        max_row.append( max_height )

        
        for i in footer!.children.indices {
            footer!.children[ i ].size = Size( width: max_col[ i ], height: max_row[ 1 ] )
        }

        for row in body.children {
            max_height = 0
            for i in (row as! HStack).children.indices {
                let c = (row as! HStack).children[ i ]

                if max_col[ i ] < c.size.width {
                    max_col[ i ] = c.size.width
                }

                if max_height < c.size.height {
                    max_height = c.size.height
                }
            }

            max_row.append( max_height )
        }
        
        let hor_border_size = Float( cols_key.count + 1 )
        let ver_border_size = Float( 1
                                     + (hideHeader ? 0 : 1)
                                     + body.children.count
                                     + (hideFooter ? 0 : 1) )

        sz = sz.join( header!.size, SizeGrowDirection.both )
        sz = sz.join( body.size   , SizeGrowDirection.both )
        sz = sz.join( footer!.size, SizeGrowDirection.both )

            
        size = Size( width:  hor_border_size + max_col.reduce( 0 ){ sum,col in sum + col }
                   , height: ver_border_size + max_row.reduce( 0 ){ sum,row in sum + row }
                   )
    }
    
    override func setDimension(_ dim: Size) {
        for i in header!.children.indices {
            let col = header!.children[ i ]
            col.size = Size( width: max_col[ i ], height: max_row[ 0 ] )
        }
        header!.setDimension( dim )
        footer!.setDimension( dim )
        
        var body_sz = Size( )
        for row in body.children {
            var sz = Size( )
            for index in cols_key.indices {
                let col = header!.children[ index ]
                let c = (row as! HStack).children[ index ]
                c.setDimension( Size( width: col.dimensions.width, height: c.size.height))
                sz = sz.join( c.dimensions, .horizontal )
            }
            row.dimensions = sz
            body_sz = body_sz.join( row.dimensions, .vertical )
        }
        
        body.dimensions = body_sz.join( Size( width: 0
                                            , height: Float(body.children.count + 1) )
                                      , .vertical ) // border
        
        dimensions = body.dimensions
        
        if !hideHeader {
            dimensions = dimensions.join( header!.dimensions, .vertical )
        }
            
        if !hideFooter {
            dimensions = dimensions.join( footer!.dimensions, .vertical )
        }
    }
    
    override func setCoordinates(_ x: Float, _ y: Float) {
        self.x = x
        self.y = y

        var local_x: Float = 1 // 1 = border size
        var local_y: Float = 0
        
        for i in cols_key.indices {
            let col = header!.children[ i ]
            col.setCoordinates( local_x, local_y + 1 )
            col.dimensions.width += (i == 0 || i == cols_key.count - 1) ? -2 : -1
            local_x += col.dimensions.width
            local_x += 1
        }

        if !hideHeader {
            local_y += header!.dimensions.height
        }
        
        for i in body.children.indices {
            let row = body.children[ i ]
            local_y += 1 // border
            local_x  = 1 // border

            for j in (row as! HStack).children.indices {
                let col = (row as! HStack).children[ j ]
                col.setCoordinates( local_x, local_y )
                col.dimensions.width += (j == 0 || j == cols_key.count - 1) ? -2 : -1
                local_x += col.dimensions.width + 1 // border
            }
            
            local_y += row.dimensions.height
        }

        footer!.x = 0
        footer!.y = local_y + 1 // border

        local_x = 1
        for i in cols_key.indices {
            let col = footer!.children[ i ]
            col.setCoordinates( local_x, 1 )
            col.dimensions.width += (i == 0 || i == cols_key.count - 1) ? -2 : -1
            local_x += col.dimensions.width
            local_x += 1
        }
    }
    
    open override func translate_container ( _ translations: [String: String] ) {
        for child in header!.children as [LayoutItem]{
            if let text = child as? LocalizedText {
                text.apply_translation( translations )
            }
            else if let cont = child as? Container {
                cont.translate_container( translations )
            }
        }
    }

}
