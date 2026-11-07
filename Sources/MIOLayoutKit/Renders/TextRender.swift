//
//  TextRender.swift
//  
//
//  Created by David Trallero on 23/06/2021.
//

import Foundation

public class TextRender: RenderContext {
    var lines: [String] = []
        
    override open func renderItem ( _ item: LayoutItem ) {
        if let text = item as? Text {
            func pad ( _ length: Int ) -> String {
                return String( repeating: " ", count: max( 0, length ) )
            }

            let len   = Int( text.dimensions.width )
            let space = len - text.text.count
            var padded_text: String
            
            switch text.align {
                case .left:   padded_text = text.text + pad( space )
                case .center: padded_text = pad( space/2 ) + text.text + pad( space - space/2 )
                case .right:  padded_text = pad( space ) + text.text
            }

            x = text.x
            y = text.y
            local_write( padded_text )
        } else if let img = item as? Image {
            let line = String( repeating: "I", count: Int( img.dimensions.width ) )
            for y in 0..<Int(img.dimensions.height) {
                write( Int( img.x ), Int( img.y ) + y, line )
            }
        }
    }

    
    override open func beginContainer ( _ container: LayoutItem ) {
        super.beginContainer( container )
        guard let table = container as? Table else { return }

        // Character grid from the laid-out column widths (flex included). Table.setCoordinates
        // narrows each column for the PDF borders (2 for the outer columns, 1 for inner
        // ones); the text grid draws its own borders, so it adds that back.
        let last = table.header!.children.count - 1
        let widths = table.header!.children.enumerated( ).map { ( i, col ) in
            Int( col.dimensions.width ) + ( i == 0 || i == last ? 2 : 1 )
        }
        let left = table.x
        var line = table.y

        func cell ( _ text: String, _ width: Int, _ align: TextAlign ) -> String {
            let chars = Array( text )
            let shown = chars.count > width ? String( chars.prefix( width ) ) : text
            let space = max( 0, width - shown.count )
            switch align {
            case .left:   return shown + String( repeating: " ", count: space )
            case .center: return String( repeating: " ", count: space / 2 ) + shown + String( repeating: " ", count: space - space / 2 )
            case .right:  return String( repeating: " ", count: space ) + shown
            }
        }

        func border ( ) {
            x = left; y = line
            local_write( "+" + widths.map { String( repeating: "-", count: $0 ) }.joined( separator: "+" ) + "+" )
            line += 1
        }

        func row ( _ texts: [Text] ) {
            x = left; y = line
            var out = "|"
            for ( i, w ) in widths.enumerated( ) {
                let t = i < texts.count ? texts[ i ] : nil
                out += cell( t?.text ?? "", w, t?.align ?? .left ) + "|"
            }
            local_write( out )
            line += 1
        }

        border( )
        if !table.hideHeader {
            row( table.header!.children )
            border( )
        }
        for r in table.body.children {
            let texts = ( r as? Container<LayoutItem> )?.children.compactMap { $0 as? Text } ?? []
            row( texts )
            border( )
        }
        if !table.hideFooter {
            row( table.footer!.children )
            border( )
        }
    }

    func local_write ( _ str: String ) {
        write( Int( x ), Int( y ), str )
        x += Float( str.count )
    }
    


    func write ( _ x: Int, _ y: Int, _ str: String ) {
        while lines.count <= y { lines.append( "" ) }
        
        while lines[ y ].count < x {
            lines[ y ] += " "
        }

        let num_char_to_delete = min( str.count, lines[ y ].count - x )
        let insert_index = lines[ y ].index( lines[ y ].startIndex, offsetBy: x )

        lines[ y ].insert( contentsOf: str, at: insert_index )

        let endIndex = lines[ y ].index( insert_index, offsetBy: str.count )

        for _ in 0..<num_char_to_delete {
            lines[ y ].remove( at: endIndex )
        }
    }
    
    
    func reset ( ) {
        x = 0
        y = 0
        lines = [ "" ]
    }
    
    
    override open func beginRender ( _ root: Page ) {
        reset()
        super.beginRender( root )
    }
    
    
    override open func meassure ( _ item: LayoutItem ) -> Size {
        if let text = item as? Text {
            return Size( width: Float( text.text.count ), height: 1 )
        } else if let page = item as? Page {
            return page.size
        }

        return Size( width: 0, height: 0 )
    }
    
    override open func output ( ) -> Data {
        return lines.joined( separator: "\n" ).data( using: .utf8 )!
    }
}
