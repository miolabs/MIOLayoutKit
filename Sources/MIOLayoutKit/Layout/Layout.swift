//
//  File.swift
//  
//
//  Created by David Trallero on 22/06/2021.
//

import Foundation

public class Layout: AddProtocol {
    var elementsByID: [String:LayoutItem]
    var rootItem: Page
    
    public init ( _ root: Page ) {
        elementsByID = [:]
        rootItem = root
        root.delegate = self
    }
    
    public func onItemAdded ( _ item: LayoutItem ) {
        if item.id != nil {
            elementsByID[ item.id! ] = item
        }
    }
    
    public func setValue( forID: String, value: Any ) throws { // Text, Image
        if let item = elementsByID[ forID ] {
            try item.setValue( value )
        }
    }

    
    public func render ( _ context: RenderContext, withPagination page: Page? = nil, end: Bool = true ) {
        // In case page is the rootItem, its dimensions will change
        let original_page_dimensions = page?.dimensions
        
        context.translate_container( rootItem )
        
        if !context.hasBegan() {
            context.beginRender( rootItem )
        }
        
            rootItem.meassure( context )
            // This triggers resizing in children that has flex
            rootItem.setDimension( rootItem.dimensions )
            context.currentPage = page
            //let coords = context.beginCoords()
            let coords = Vector2D(x: 0.0, y: 0.0)
            rootItem.setCoordinates( coords.x, coords.y )
        
            if page != nil {
                page!.dimensions = original_page_dimensions!
                
                let pages = createPages( page! )
                
                for p in pages {
                    context.beginPage( p )
                    p.render( context )
                    context.endPage( p )
                }
            } else {
                rootItem.render( context )
            }
        
        if end {
            context.endRender( )
        }
    }
    
    
    public func createPages ( _ page: Page ) -> [Page] {
        var flat_items: [LayoutItem] = []
        
        flat_items_rec( rootItem, &flat_items )
        
        // have to make unbreakable first
        // bubble sort to make unbreakable first
        var j = 0
        for i in 0..<flat_items.count {
            let item = flat_items[ i ]
            
            if item.is_unbreakable {
                flat_items.remove(at: i)
                flat_items.insert( item, at: j)
                j = j + 1
            }
        }
        
        var ret: [Page] = [ page.newPage( 0 ) ]

        func page_for_offset ( _ item: LayoutItem, start: Bool ) -> Int {
            let y = start ? item.y : item.y + item.dimensions.height
            
            while ( (-ret.last!.y + ret.last!.dimensions.height) < y ) {
                let new_page = page.newPage( ret.count )
                new_page.y = Float(-ret.count) * page.dimensions.height
                
                if item.is_unbreakable && start == false {
                    new_page.y = -item.y
                }
                
                // CASE: the page cuts a line by half. We want the whole new line to start
                // in the new page only
              //  if abs(new_page.y + y) < 40 {
                //    new_page.y = -y
               // }
                
                ret.append( new_page )
            }
            
            var i = ret.count - 1
            
            while ( -ret[ i ].y > y ) {
                i = i - 1
            }

            return i
        }
        
        for item in flat_items {
            let start_page = page_for_offset( item, start: true  )
            let end_page   = page_for_offset( item, start: false )
            
            for i in start_page ... end_page {
                ret[ i ].add( item.clone( ) )
            }
        }
        
        return ret
//
//        var offset_y: Float = 0
//        var queue: [LayoutItem] = [ rootItem ]
//        var cur_page: Page!
//        var cur_page_item: LayoutItem
//
//        func new_page ( ) {
//            cur_page = page.createPage( ret.count )
//
//            ret.append( cur_page )
//        }
//
//        new_page()
//
//        repeat {
//            let item = queue.popFirst()
//
//            if let container = item as? Container {
//                queue.append( contentsOf: container.children )
//            } else {
//                let pos = item.absPosition( )
//
//                if pos.y + offset_y + pos.dimensions.height > cur_page.dimensions.height {
//                    new_page()
//                    // TODO: add all the item from item -> root that appear in this page
//                }
//                cur_page_item.shallowClone( item )
//                cur_page.children.append( cur_page_item )
//            }
//        } while item != nil
    }
    
    func flat_items_rec ( _ item: LayoutItem, _ flat_items: inout [LayoutItem] ) {
        let shallow_copy = item.shallowCopy( )
        let pos = item.absPosition()
        shallow_copy.x = pos.x
        shallow_copy.y = pos.y
        
        flat_items.append( shallow_copy )
        
        if let table = item as? Table {
            if !table.hideHeader {
                flat_items_rec( table.header!, &flat_items )
            }
            
            if !table.hideFooter {
                flat_items_rec( table.footer!, &flat_items )
            }
            
            flat_items_rec( table.body, &flat_items )
        } else if let container = item as? Container {
            for c in container.children {
                flat_items_rec( c, &flat_items )
            }
        } else if let container = item as? Container<Text> {
            for c in container.children {
                flat_items_rec( c, &flat_items )
            }
        } else if let container = item as? Container<LayoutItem> {
            for c in container.children {
                flat_items_rec( c, &flat_items )
            }
        }
    }

//    func create_pages_rec ( _ item: LayoutItem
//                          , _ parent: LayoutContainer?
//                          , _ page: Page
//                          , _ offset_y: Float
//                          , _ ret: inout [Page] ) {
//        let pos = item.absPosition( )
//        var i: Int
//
//        for ( i = ret.count - 1 ; i > 0 && -ret[ i ].y < pos.y ; i = i - 1 ) {
//
//        }
//
//        var cur_page = ret[ i ]
//
//        if let container = item as? Container {
//            let next_parent = container.shallowClone( )
//
//            cur_page.children.append( next_parent )
//
//            for next_item in container.children {
//                create_pages_rec( next_item, next_parent, page, offset_y, &ret )
//            }
//        } else {
//
//            if pos.y + offset_y + pos.dimensions.height > cur_page.dimensions.height {
//                if i == ret.count - 1 {
//                    cur_page = page.createPage( ret.count )
//                    cur_page.y = -pos.y
//                    // TODO: add all the item from item -> root that appear in this page
//                    ret.append( cur_page )
//                }
//            }
//            cur_page_item.shallowClone( item )
//            cur_page.children.append( cur_page_item )
//        }
//
//    }
}
