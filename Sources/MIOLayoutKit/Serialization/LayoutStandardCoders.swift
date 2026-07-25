//
//  LayoutStandardCoders.swift
//  MIOLayoutKit
//
//  Node coders for the core layout types. Encode matchers run in the order
//  listed in `all`, so subclasses appear before their parents (LocalizedText
//  before Text, Padding/Table before the generic stacks).
//

import Foundation


enum LayoutStandardCoders {

    static let all: [LayoutNodeCoder] = [ image, localizedText, text, space, padding, sectionedTable, table, hstack, vstack, item ]

    // MARK: - Text

    static let text = LayoutNodeCoder(
        nodeType: "text",
        decode: { node, decoder in
            let raw = try node.string( "value" )

            // A whole-value quoted binding with the `localized` hint decodes
            // to a LocalizedText so the render translation pass applies.
            if let key = localizedLiteral( raw ) {
                return try makeText( LocalizedText( key ), node )
            }

            return try makeText( Text( decoder.resolveText( raw ) ), node )
        },
        encode: { item, _ in
            guard let text = item as? Text, !( text is LocalizedText ) else { return nil }
            var node = LayoutNode( type: "text", properties: [ "value": .string( text.text ) ] )
            encodeTextStyle( text, &node )
            return node
        }
    )

    static let localizedText = LayoutNodeCoder(
        nodeType: "localizedText",
        decode: { node, decoder in
            try makeText( LocalizedText( node.string( "key" ) ), node )
        },
        encode: { item, _ in
            guard let text = item as? LocalizedText else { return nil }
            var node = LayoutNode( type: "localizedText", properties: [ "key": .string( text.original_text ) ] )
            encodeTextStyle( text, &node )
            return node
        }
    )

    static func makeText ( _ text: Text, _ node: LayoutNode ) throws -> Text {
        text.text_size = try node.itemSize( "textSize", default: .s )
        text.bold      = node.bool( "bold", default: false )
        text.italic    = node.bool( "italic", default: false )
        text.align     = try node.textAlign( "align", default: .left )
        text.wrap      = try node.textWrap( "wrap", default: .wrap )
        return text
    }

    static func encodeTextStyle ( _ text: Text, _ node: inout LayoutNode ) {
        if text.text_size != .s   { node.properties[ "textSize" ] = .string( text.text_size.name ) }
        if text.bold              { node.properties[ "bold" ]     = .bool( true ) }
        if text.italic            { node.properties[ "italic" ]   = .bool( true ) }
        if text.align != .left    { node.properties[ "align" ]    = .string( text.align.name ) }
        if text.wrap  != .wrap    { node.properties[ "wrap" ]     = .string( text.wrap.name ) }
    }

    /// Matches a value that is exactly one `{{ 'KEY' | localized }}` binding.
    static func localizedLiteral ( _ value: String ) -> String? {
        let trimmed = value.trimmingCharacters( in: .whitespaces )
        guard trimmed.hasPrefix( "{{" ) && trimmed.hasSuffix( "}}" ) else { return nil }

        let expression = String( trimmed.dropFirst( 2 ).dropLast( 2 ) )
        guard let pipe = expression.range( of: "|" ) else { return nil }

        let hint = expression[ pipe.upperBound... ].trimmingCharacters( in: .whitespaces )
        guard hint == "localized" else { return nil }

        let path = expression[ ..<pipe.lowerBound ].trimmingCharacters( in: .whitespaces )
        guard path.hasPrefix( "'" ) && path.hasSuffix( "'" ) && path.count >= 2 else { return nil }

        return String( path.dropFirst().dropLast() )
    }

    // MARK: - Stacks

    static let hstack = LayoutNodeCoder(
        nodeType: "hstack",
        decode: { node, decoder in
            let stack = HStack<LayoutItem>()
            for child in node.children {
                if let item = try decoder.decodeItem( child ) { stack.add( item ) }
            }
            return stack
        },
        encode: { item, encoder in
            guard let container = item as? Container<LayoutItem>, !( item is Page ) else { return nil }
            let type = container.growDirection == .horizontal ? "hstack" : "vstack"
            var node = LayoutNode( type: type )
            node.children = try container.children.map { try encoder.encodeItem( $0 ) }
            return node
        }
    )

    static let vstack = LayoutNodeCoder(
        nodeType: "vstack",
        decode: { node, decoder in
            let stack = VStack<LayoutItem>()
            for child in node.children {
                if let item = try decoder.decodeItem( child ) { stack.add( item ) }
            }
            return stack
        },
        encode: nil  // the hstack coder encodes both directions
    )

    // MARK: - Space / generic item

    static let space = LayoutNodeCoder(
        nodeType: "space",
        decode: { node, _ in
            Space( try node.itemSize( "a", default: .none ), try node.itemSize( "b", default: .none ) )
        },
        encode: { item, _ in
            guard let space = item as? Space else { return nil }
            var node = LayoutNode( type: "space" )
            if space.a != .none { node.properties[ "a" ] = .string( space.a.name ) }
            if space.b != .none { node.properties[ "b" ] = .string( space.b.name ) }
            return node
        }
    )

    /// Plain LayoutItem: an empty box, typically used as a flexible spacer.
    static let item = LayoutNodeCoder(
        nodeType: "item",
        decode: { _, _ in LayoutItem() },
        encode: { item, _ in
            guard type( of: item ) == LayoutItem.self || item is EmptyLayoutItem else { return nil }
            return LayoutNode( type: "item" )
        }
    )

    // MARK: - Padding

    static let padding = LayoutNodeCoder(
        nodeType: "padding",
        decode: { node, decoder in
            guard let child_node = try node.nodeIfPresent( "child" ) else {
                throw LayoutSerializationError.missingProperty( "child", nodeType: "padding" )
            }
            let child = try decoder.decodeItem( child_node ) ?? LayoutItem()

            return Padding( child
                          , top:    try node.itemSize( "top",    default: .none )
                          , right:  try node.itemSize( "right",  default: .none )
                          , bottom: try node.itemSize( "bottom", default: .none )
                          , left:   try node.itemSize( "left",   default: .none ) )
        },
        encode: { item, encoder in
            guard let pad = item as? Padding else { return nil }
            var node = LayoutNode( type: "padding" )

            let child = try encoder.encodeItem( pad.padded_item )
            node.properties[ "child" ] = try child.asValue()

            if pad.edge_sizes.top    != .none { node.properties[ "top"    ] = .string( pad.edge_sizes.top.name ) }
            if pad.edge_sizes.right  != .none { node.properties[ "right"  ] = .string( pad.edge_sizes.right.name ) }
            if pad.edge_sizes.bottom != .none { node.properties[ "bottom" ] = .string( pad.edge_sizes.bottom.name ) }
            if pad.edge_sizes.left   != .none { node.properties[ "left"   ] = .string( pad.edge_sizes.left.name ) }
            return node
        }
    )

    // MARK: - Image

    static let image = LayoutNodeCoder(
        nodeType: "image",
        decode: { node, decoder in
            let width  = try node.float( "width" )
            let height = try node.float( "height" )
            let align  = try node.imageAlign( "align", default: .center )

            let image: Image

            if let url = node.stringIfPresent( "url" ) {
                image = URLImage( url: decoder.resolveText( url ), width: width, height: height )
            }
            else if let path = node.stringIfPresent( "path" ) {
                switch decoder.provider?.image( forPath: path ) {
                case .url( let url ):   image = URLImage( url: url, width: width, height: height )
                case .data( let data ): image = Image( data: data, width: width, height: height )
                case nil:
                    decoder.recordIssue( "unresolved image '\(path)'" )
                    image = Image( data: nil, width: width, height: height )
                }
            }
            else if let base64 = node.stringIfPresent( "data" ) {
                guard let data = Data( base64Encoded: base64 ) else {
                    throw LayoutSerializationError.invalidProperty( "data", nodeType: "image", expected: "base64 string" )
                }
                image = Image( data: data, width: width, height: height )
            }
            else {
                image = Image( data: nil, width: width, height: height )
            }

            return image.align( align )
        },
        encode: { item, _ in
            guard let image = item as? Image else { return nil }
            var node = LayoutNode( type: "image" )
            node.properties[ "width" ]  = .double( Double( image.imgSize.width ) )
            node.properties[ "height" ] = .double( Double( image.imgSize.height ) )
            if image.align != .center { node.properties[ "align" ] = .string( image.align.name ) }

            if let url_image = image as? URLImage {
                node.properties[ "url" ] = .string( url_image.url )
            }
            else if let data = image.data {
                node.properties[ "data" ] = .string( data.base64EncodedString() )
            }
            return node
        }
    )

    // MARK: - Table

    struct ColumnSpec {
        var title: String
        var key: String
        var flex: Int
        var textSize: ItemSize
        var bold: Bool
        var align: TextAlign
        var wrap: TextWrap
        var fgColor: String?
        var hint: String?
    }

    static func columnSpecs ( _ node: LayoutNode ) throws -> [ColumnSpec] {
        guard let raw = node.arrayIfPresent( "columns" ) else {
            throw LayoutSerializationError.missingProperty( "columns", nodeType: node.type )
        }

        return try raw.map { value in
            guard let obj = value.objectValue else {
                throw LayoutSerializationError.invalidProperty( "columns", nodeType: node.type, expected: "array of column objects" )
            }
            let col = LayoutNode( type: node.type, properties: obj )
            return ColumnSpec( title:    try col.string( "title" )
                             , key:      try col.string( "key" )
                             , flex:     col.int( "flex", default: 0 )
                             , textSize: try col.itemSize( "textSize", default: .m )
                             , bold:     col.bool( "bold", default: false )
                             , align:    try col.textAlign( "align", default: .left )
                             , wrap:     try col.textWrap( "wrap", default: .noWrap )
                             , fgColor:  col.stringIfPresent( "fgColor" )
                             , hint:     col.stringIfPresent( "hint" ) )
        }
    }

    static func makeTable ( _ node: LayoutNode, _ columns: [ColumnSpec] ) -> Table {
        let table = Table()
        table.border = node.bool( "border", default: true )

        for col in columns {
            table.addColumn( col.key, col.title, flex: col.flex, textSize: col.textSize
                           , bold: col.bold, align: col.align, wrap: col.wrap, fgColor: col.fgColor )
        }
        return table
    }

    static func rowDict ( _ handle: LayoutDecoder.RowHandle, _ columns: [ColumnSpec] ) -> [String:Any] {
        var dict: [String:Any] = [:]
        for col in columns {
            if let value = handle.text( col.key, col.hint ) { dict[ col.key ] = value }
        }
        return dict
    }

    static func addSectionTitle ( _ table: Table, _ title: String, columnCount: Int ) {
        let row = HStack<LayoutItem>()
        row.add( Text( title, bold: true ) )
        for _ in 1 ..< max( 1, columnCount ) { row.add( Text( "" ) ) }
        table.addRow( row )
    }

    static let table = LayoutNodeCoder(
        nodeType: "table",
        decode: { node, decoder in
            let columns = try columnSpecs( node )
            let table = makeTable( node, columns )
            let keys = columns.map { $0.key }

            if let rows_path = node.stringIfPresent( "rows" ) {
                for handle in decoder.rows( at: rows_path, probeKeys: keys ) {
                    table.addRow( rowDict( handle, columns ) )
                }
            }

            if let static_rows = node.arrayIfPresent( "staticRows" ) {
                for value in static_rows {
                    guard let obj = value.objectValue else {
                        throw LayoutSerializationError.invalidProperty( "staticRows", nodeType: "table", expected: "array of objects" )
                    }
                    var dict: [String:Any] = [:]
                    for ( key, cell ) in obj {
                        if let s = cell.stringValue { dict[ key ] = decoder.resolveText( s ) }
                    }
                    table.addRow( dict )
                }
            }

            if let footer_rows = node.arrayIfPresent( "footerRows" ) {
                for value in footer_rows {
                    guard let obj = value.objectValue else {
                        throw LayoutSerializationError.invalidProperty( "footerRows", nodeType: "table", expected: "array of objects" )
                    }
                    var dict: [String:Any] = [:]
                    for ( key, cell ) in obj {
                        if let s = cell.stringValue { dict[ key ] = decoder.resolveText( s ) }
                    }
                    table.addFooterRow( dict, bold: node.bool( "footerBold", default: false ) )
                }
            }

            return table
        },
        encode: { item, _ in
            guard let table = item as? Table else { return nil }
            var node = LayoutNode( type: "table" )

            if !table.border { node.properties[ "border" ] = .bool( false ) }

            var columns: [LayoutNodeValue] = []
            for ( index, key ) in table.cols_key.enumerated() {
                let header_text = table.header!.children[ index ]
                var col: [String:LayoutNodeValue] = [ "title": .string( header_text.original_text )
                                                    , "key":   .string( key ) ]
                if header_text.flex != 0          { col[ "flex" ]     = .int( header_text.flex ) }
                if header_text.text_size != .m    { col[ "textSize" ] = .string( header_text.text_size.name ) }
                if header_text.bold               { col[ "bold" ]     = .bool( true ) }
                if header_text.align != .left     { col[ "align" ]    = .string( header_text.align.name ) }
                if header_text.wrap  != .noWrap   { col[ "wrap" ]     = .string( header_text.wrap.name ) }
                if let fg = header_text.style.fgColor { col[ "fgColor" ] = .string( fg ) }
                columns.append( .object( col ) )
            }
            node.properties[ "columns" ] = .array( columns )

            var static_rows: [LayoutNodeValue] = []
            for row in table.body.children {
                guard let cells = tableRowCells( row ) else { continue }
                var obj: [String:LayoutNodeValue] = [:]
                for ( index, key ) in table.cols_key.enumerated() where index < cells.count {
                    obj[ key ] = .string( cells[ index ]?.text ?? "" )
                }
                static_rows.append( .object( obj ) )
            }
            if !static_rows.isEmpty { node.properties[ "staticRows" ] = .array( static_rows ) }

            if !table.hideFooter {
                var obj: [String:LayoutNodeValue] = [:]
                for ( index, key ) in table.cols_key.enumerated() where index < table.footer!.children.count {
                    let value = table.footer!.children[ index ].text
                    if !value.isEmpty { obj[ key ] = .string( value ) }
                }
                if !obj.isEmpty { node.properties[ "footerRows" ] = .array( [ .object( obj ) ] ) }
            }

            return node
        }
    )

    static func tableRowCells ( _ row: LayoutItem ) -> [Text?]? {
        if let typed = row as? Container<Text> { return typed.children }
        if let generic = row as? Container<LayoutItem> { return generic.children.map { $0 as? Text } }
        return nil
    }

    // MARK: - Sectioned table

    /// Rows grouped in titled sections. Scoped mode: `sections` resolves via
    /// items(forPath:); each section provider answers "title", "rows" and
    /// "footer.<key>". Flat mode: sections are `<sections>.<i>.title` /
    /// `<sections>.<i>.footer.<key>`, and rows come from one globally-indexed
    /// list at the separate `rows` path, consumed in per-section counts
    /// (`<sections>.<i>.rows`).
    static let sectionedTable = LayoutNodeCoder(
        nodeType: "sectionedTable",
        decode: { node, decoder in
            let columns = try columnSpecs( node )
            let table = makeTable( node, columns )
            let keys = columns.map { $0.key }
            let sections_path = try node.string( "sections" )

            guard let provider = decoder.provider else {
                decoder.recordIssue( "unresolved sections '\(sections_path)': no data provider" )
                return table
            }

            func addFooter ( _ text: ( String ) -> String? ) {
                var dict: [String:Any] = [:]
                for col in columns {
                    if let value = text( col.key ) { dict[ col.key ] = value }
                }
                if !dict.isEmpty { table.addRow( dict, bold: true ) }
            }

            if let sections = provider.items( forPath: sections_path ) {
                for section in sections {
                    let title = section.text( forPath: "title", hint: nil ) ?? ""
                    addSectionTitle( table, title, columnCount: columns.count )

                    for handle in decoder.rows( at: "rows", probeKeys: keys, provider: section ) {
                        table.addRow( rowDict( handle, columns ) )
                    }

                    addFooter { key in section.text( forPath: "footer.\(key)", hint: nil ) }
                }
            }
            else {
                guard let rows_path = node.stringIfPresent( "rows" ) else {
                    throw LayoutSerializationError.missingProperty( "rows", nodeType: "sectionedTable" )
                }

                var section_count = provider.count( forPath: sections_path )
                if section_count == nil {
                    var probed = 0
                    while probed < decoder.maxProbedRows
                        , provider.text( forPath: "\(sections_path).\(probed).title", hint: nil ) != nil {
                        probed += 1
                    }
                    section_count = probed
                }

                var row_index = 0
                for section in 0 ..< section_count! {
                    let base = "\(sections_path).\(section)"
                    let title = provider.text( forPath: "\(base).title", hint: nil ) ?? ""
                    addSectionTitle( table, title, columnCount: columns.count )

                    guard let row_count = provider.count( forPath: "\(base).rows" ) else {
                        decoder.recordIssue( "sectionedTable: missing count for '\(base).rows' in flat mode" )
                        continue
                    }

                    for _ in 0 ..< row_count {
                        var dict: [String:Any] = [:]
                        for col in columns {
                            if let value = provider.text( forPath: "\(rows_path).\(row_index).\(col.key)", hint: col.hint ) {
                                dict[ col.key ] = value
                            }
                        }
                        table.addRow( dict )
                        row_index += 1
                    }

                    addFooter { key in provider.text( forPath: "\(base).footer.\(key)", hint: nil ) }
                }
            }

            return table
        },
        encode: nil
    )
}


extension LayoutNode {
    func asValue ( ) throws -> LayoutNodeValue {
        var obj = properties
        obj[ "type" ] = .string( type )
        if !children.isEmpty {
            obj[ "children" ] = .array( try children.map { try $0.asValue() } )
        }
        return .object( obj )
    }
}


extension LayoutDecoder {
    func rows ( at path: String, probeKeys: [String], provider: LayoutDataProvider ) -> [RowHandle] {
        var collected: [String] = []
        let result = LayoutDecoder.rows( at: path, probeKeys: probeKeys, provider: provider
                                       , maxProbedRows: maxProbedRows, issues: &collected )
        for issue in collected { recordIssue( issue ) }
        return result
    }
}
