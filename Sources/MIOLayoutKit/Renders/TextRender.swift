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

    
    override open func beginContainer ( _ container: Container<LayoutItem> ) {
        if let table = container as? Table {
            func draw_border ( ) {
                x = table.x
                local_write( "+" )
                for col in table.header!.children {
                    local_write( String( repeating: "-", count: Int( col.dimensions.width ) ) )
                    local_write( "+" )
                }
                x = table.x
                y += 1
            }
            
            x = table.x
            y = table.y
            
            draw_border( )
            local_write( "|" )
            
            for i in table.cols_key.indices {
                let col = table.header!.children[ i ]
                renderItem( col )
                local_write( "|" )
            }
            
            for i in table.body.children.indices {
                let row = table.body.children[ i ]
                y += row.dimensions.height
                draw_border( )
                local_write( "|" )
                for j in (row as! HStack).children.indices {
                    let col = (row as! HStack).children[ j ] as! Text
                    renderItem( col )
                    local_write( "|" )
                }
            }
            
            y += table.body.children.last?.dimensions.height ?? 0
            draw_border( )
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
