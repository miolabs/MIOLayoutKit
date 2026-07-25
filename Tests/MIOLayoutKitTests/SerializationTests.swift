import XCTest
@testable import MIOLayoutKit

final class SerializationTests: XCTestCase {

    // MARK: - Helpers

    func renderHTML ( _ page: Page, translations: [String:String] = [:] ) -> String {
        let render = HTMLRender( translations )
        let layout = Layout( page )
        layout.render( render )
        return String( data: render.output(), encoding: .utf8 ) ?? ""
    }

    func renderText ( _ page: Page ) -> String {
        let render = TextRender()
        let layout = Layout( page )
        layout.render( render )
        return String( data: render.output(), encoding: .utf8 ) ?? ""
    }

    func decodePage ( _ json: String, provider: LayoutDataProvider? = nil, decoder: LayoutDecoder = LayoutDecoder() ) throws -> Page {
        try decoder.decode( json.data( using: .utf8 )!, provider: provider )
    }

    /// A provider that only implements text(forPath:) — forces flat indexed
    /// resolution. Backed by a flat [path: value] dictionary.
    final class FlatTextProvider: LayoutDataProvider {
        let values: [String:String]
        let counts: [String:Int]

        init ( _ values: [String:String], counts: [String:Int] = [:] ) {
            self.values = values
            self.counts = counts
        }

        func text ( forPath path: String, hint: String? ) -> String? { values[ path ] }
        func count ( forPath path: String ) -> Int? { counts[ path ] }
    }

    // MARK: - Round trip

    /// Rendering mutates layout state (Table measurement accumulates), so
    /// every render in the round-trip comparison gets a fresh tree.
    func makeSamplePage ( ) -> Page {
        let page = A4.portrait()

        let table = Table()
        table.addColumn( "product", "PRODUCT", flex: 3 )
        table.addColumn( "qty", "QTY", align: .right )
        table.addColumn( "total", "TOTAL", align: .right )
        table.addRow( [ "product": "Water", "qty": "2", "total": "4,00" ] )
        table.addRow( [ "product": "Wine",  "qty": "1", "total": "12,50" ] )
        table.addFooterRow( [ "product": "TOTAL", "total": "16,50" ] )

        let root = VStack<LayoutItem>( 1 ) {
            HStack<LayoutItem>( 1 ) {
                Text( "INVOICE", textSize: .xl, bold: true )
                LayoutItem( 1 )
                LocalizedText( "DATE", textSize: .s, italic: true, align: .right )
            }
            Space( .m )
            Padding( Text( "Some notes", align: .center ), top: .s, left: .m )
            URLImage( url: "https://dual-link.com/logo.png", width: 120, height: 40 )
            table
        }
        root.style.bgColor = "#F0F0F0"
        page.add( root )
        return page
    }

    func testRoundTripStaticLayout ( ) throws {
        let data = try LayoutEncoder().encode( makeSamplePage(), documentType: "test", name: "Round trip" )

        let decoder = LayoutDecoder()
        XCTAssertEqual( renderHTML( makeSamplePage() ), renderHTML( try decoder.decode( data ) ) )
        XCTAssertEqual( renderText( makeSamplePage() ), renderText( try decoder.decode( data ) ) )
        XCTAssertEqual( decoder.issues, [] )

        // A round-tripped document re-encodes identically (stable format)
        let reencoded = try LayoutEncoder().encode( try decoder.decode( data ), documentType: "test", name: "Round trip" )
        XCTAssertEqual( String( data: data, encoding: .utf8 ), String( data: reencoded, encoding: .utf8 ) )
    }

    // MARK: - Bindings

    func testTextBindings ( ) throws {
        let json = """
        {
          "formatVersion": 1,
          "root": { "type": "vstack", "children": [
            { "type": "text", "value": "{{ doc.number }}", "bold": true },
            { "type": "text", "value": "Customer: {{ doc.customer.name }}" },
            { "type": "text", "value": "{{ doc.date | short }}" }
          ]}
        }
        """

        let provider = DictionaryDataProvider( [
            "doc": [ "number": "INV-042"
                   , "customer": [ "name": "Acme SL" ]
                   , "date": "25/07/26" ] as [String:Any]
        ] )

        let decoder = LayoutDecoder()
        let page = try decodePage( json, provider: provider, decoder: decoder )
        let html = renderHTML( page )

        XCTAssertTrue( html.contains( "INV-042" ) )
        XCTAssertTrue( html.contains( "Customer: Acme SL" ) )
        XCTAssertTrue( html.contains( "25/07/26" ) )
        XCTAssertEqual( decoder.issues, [] )
    }

    func testUnresolvedBindingIsReportedAsIssue ( ) throws {
        let json = """
        {
          "formatVersion": 1,
          "root": { "type": "text", "value": "{{ doc.missing }}" }
        }
        """

        let decoder = LayoutDecoder()
        _ = try decodePage( json, provider: DictionaryDataProvider( [:] ), decoder: decoder )

        XCTAssertEqual( decoder.issues, [ "unresolved 'doc.missing'" ] )
    }

    func testVisibleIf ( ) throws {
        let json = """
        {
          "formatVersion": 1,
          "root": { "type": "vstack", "children": [
            { "type": "text", "value": "always" },
            { "type": "text", "value": "sometimes", "visibleIf": "flags.show" }
          ]}
        }
        """

        let hidden = try decodePage( json, provider: DictionaryDataProvider( [ "flags": [ "show": false ] ] ) )
        XCTAssertFalse( renderHTML( hidden ).contains( "sometimes" ) )

        let shown = try decodePage( json, provider: DictionaryDataProvider( [ "flags": [ "show": true ] ] ) )
        XCTAssertTrue( renderHTML( shown ).contains( "sometimes" ) )
    }

    func testLocalizedLiteralBecomesLocalizedText ( ) throws {
        let json = """
        {
          "formatVersion": 1,
          "root": { "type": "text", "value": "{{ 'TOTAL' | localized }}" }
        }
        """

        let page = try decodePage( json, provider: DictionaryDataProvider( [:] ) )
        let html = renderHTML( page, translations: [ "TOTAL": "Total general" ] )

        XCTAssertTrue( html.contains( "Total general" ) )
    }

    // MARK: - Tables

    let tableTemplate = """
    {
      "formatVersion": 1,
      "root": { "type": "table",
        "rows": "doc.lines",
        "columns": [
          { "title": "PRODUCT", "key": "product", "flex": 3 },
          { "title": "QTY", "key": "qty", "align": "right" },
          { "title": "TOTAL", "key": "total", "align": "right" }
        ],
        "footerRows": [ { "product": "{{ 'TOTAL' }}", "total": "{{ doc.total }}" } ]
      }
    }
    """

    func testTableScopedRows ( ) throws {
        let provider = DictionaryDataProvider( [
            "doc": [ "total": "16,50"
                   , "lines": [ [ "product": "Water", "qty": "2", "total": "4,00" ]
                              , [ "product": "Wine",  "qty": "1", "total": "12,50" ] ] ] as [String:Any]
        ] )

        let decoder = LayoutDecoder()
        let page = try decodePage( tableTemplate, provider: provider, decoder: decoder )
        let table = firstTable( page )

        let html = renderHTML( page )
        XCTAssertTrue( html.contains( "Water" ) )
        XCTAssertTrue( html.contains( "Wine" ) )

        // Footers only render in PDF today, so assert the decoded state
        XCTAssertEqual( table?.hideFooter, false )
        XCTAssertEqual( table?.footer?.children.map { $0.text }, [ "TOTAL", "", "16,50" ] )
        XCTAssertEqual( decoder.issues, [] )
    }

    func firstTable ( _ item: LayoutItem ) -> Table? {
        if let table = item as? Table { return table }
        if let container = item as? Container<LayoutItem> {
            for child in container.children {
                if let table = firstTable( child ) { return table }
            }
        }
        return nil
    }

    func testTableFlatRowsWithCount ( ) throws {
        let provider = FlatTextProvider( [ "doc.lines.0.product": "Water", "doc.lines.0.qty": "2", "doc.lines.0.total": "4,00"
                                         , "doc.lines.1.product": "Wine",  "doc.lines.1.qty": "1", "doc.lines.1.total": "12,50"
                                         , "doc.total": "16,50" ]
                                        , counts: [ "doc.lines": 2 ] )

        let page = try decodePage( tableTemplate, provider: provider )
        let html = renderHTML( page )

        XCTAssertTrue( html.contains( "Water" ) )
        XCTAssertTrue( html.contains( "Wine" ) )
        XCTAssertEqual( firstTable( page )?.footer?.children.map { $0.text }, [ "TOTAL", "", "16,50" ] )
    }

    func testTableFlatRowsWithProbing ( ) throws {
        let provider = FlatTextProvider( [ "doc.lines.0.product": "Water", "doc.lines.0.qty": "2", "doc.lines.0.total": "4,00"
                                         , "doc.lines.1.product": "Wine",  "doc.lines.1.qty": "1", "doc.lines.1.total": "12,50"
                                         , "doc.total": "16,50" ] )

        let page = try decodePage( tableTemplate, provider: provider )
        let text = renderText( page )

        XCTAssertTrue( text.contains( "Water" ) )
        XCTAssertTrue( text.contains( "Wine" ) )
        XCTAssertFalse( text.contains( "doc.lines.2" ) )
    }

    let sectionedTemplate = """
    {
      "formatVersion": 1,
      "root": { "type": "sectionedTable",
        "sections": "doc.sections",
        "rows": "doc.rows",
        "columns": [
          { "title": "PRODUCT", "key": "product", "flex": 3 },
          { "title": "TOTAL", "key": "total", "align": "right" }
        ]
      }
    }
    """

    func testSectionedTableScoped ( ) throws {
        let provider = DictionaryDataProvider( [
            "doc": [ "sections": [
                [ "title": "Drinks"
                , "rows": [ [ "product": "Water", "total": "4,00" ], [ "product": "Wine", "total": "12,50" ] ]
                , "footer": [ "total": "16,50" ] ] as [String:Any],
                [ "title": "Food"
                , "rows": [ [ "product": "Bread", "total": "1,00" ] ] ] as [String:Any]
            ] ] as [String:Any]
        ] )

        let page = try decodePage( sectionedTemplate, provider: provider )
        let text = renderText( page )

        XCTAssertTrue( text.contains( "Drinks" ) )
        XCTAssertTrue( text.contains( "Water" ) )
        XCTAssertTrue( text.contains( "16,50" ) )
        XCTAssertTrue( text.contains( "Food" ) )
        XCTAssertTrue( text.contains( "Bread" ) )

        if let drinks = text.range( of: "Drinks" ), let food = text.range( of: "Food" ), let bread = text.range( of: "Bread" ) {
            XCTAssertTrue( drinks.lowerBound < food.lowerBound )
            XCTAssertTrue( food.lowerBound < bread.lowerBound )
        }
    }

    func testSectionedTableFlat ( ) throws {
        let provider = FlatTextProvider( [ "doc.sections.0.title": "Drinks"
                                         , "doc.sections.0.footer.total": "16,50"
                                         , "doc.sections.1.title": "Food"
                                         , "doc.rows.0.product": "Water", "doc.rows.0.total": "4,00"
                                         , "doc.rows.1.product": "Wine",  "doc.rows.1.total": "12,50"
                                         , "doc.rows.2.product": "Bread", "doc.rows.2.total": "1,00" ]
                                        , counts: [ "doc.sections": 2
                                                  , "doc.sections.0.rows": 2
                                                  , "doc.sections.1.rows": 1 ] )

        let page = try decodePage( sectionedTemplate, provider: provider )
        let text = renderText( page )

        XCTAssertTrue( text.contains( "Drinks" ) )
        XCTAssertTrue( text.contains( "16,50" ) )
        XCTAssertTrue( text.contains( "Food" ) )
        XCTAssertTrue( text.contains( "Bread" ) )

        if let food = text.range( of: "Food" ), let bread = text.range( of: "Bread" ), let wine = text.range( of: "Wine" ) {
            XCTAssertTrue( wine.lowerBound < food.lowerBound )
            XCTAssertTrue( food.lowerBound < bread.lowerBound )
        }
    }

    // MARK: - Fragments

    func testFragmentRef ( ) throws {
        let fragments = LayoutFragmentLibrary()
        fragments.register( "test.header", node: LayoutNode( type: "text"
                                                           , properties: [ "value": "Fragment header", "bold": true ] ) )

        let json = """
        {
          "formatVersion": 1,
          "root": { "type": "vstack", "children": [
            { "type": "vstack", "ref": "test.header" },
            { "type": "text", "value": "body" }
          ]}
        }
        """

        let decoder = LayoutDecoder( fragments: fragments )
        let page = try decodePage( json, decoder: decoder )

        XCTAssertTrue( renderHTML( page ).contains( "Fragment header" ) )
    }

    func testUnknownFragmentThrows ( ) throws {
        let json = """
        { "formatVersion": 1, "root": { "type": "vstack", "ref": "test.nope" } }
        """

        XCTAssertThrowsError( try decodePage( json, decoder: LayoutDecoder( fragments: LayoutFragmentLibrary() ) ) ) { error in
            guard case LayoutSerializationError.unknownFragment( let name ) = error else {
                return XCTFail( "unexpected error: \(error)" )
            }
            XCTAssertEqual( name, "test.nope" )
        }
    }

    func testUnknownNodeTypeThrows ( ) throws {
        let json = """
        { "formatVersion": 1, "root": { "type": "hologram" } }
        """

        XCTAssertThrowsError( try decodePage( json ) ) { error in
            guard case LayoutSerializationError.unknownNodeType( let type ) = error else {
                return XCTFail( "unexpected error: \(error)" )
            }
            XCTAssertEqual( type, "hologram" )
        }
    }

    // MARK: - Custom node registration

    func testCustomNodeType ( ) throws {
        let registry = LayoutNodeRegistry()
        registry.register( LayoutNodeCoder( nodeType: "test.stamp"
                                          , decode: { _, _ in Text( "STAMPED" ) } ) )

        let json = """
        { "formatVersion": 1, "root": { "type": "test.stamp" } }
        """

        let page = try decodePage( json, decoder: LayoutDecoder( registry: registry ) )
        XCTAssertTrue( renderHTML( page ).contains( "STAMPED" ) )
    }

    // MARK: - File store

    func testFileTemplateStore ( ) throws {
        let root = NSTemporaryDirectory() + "/layout-store-tests-" + UUID().uuidString
        defer { try? FileManager.default.removeItem( atPath: root ) }

        let store = try FileLayoutTemplateStore( rootPath: root )

        let body = """
        { "formatVersion": 1, "documentType": "invoice", "name": "Default invoice",
          "root": { "type": "text", "value": "hello" } }
        """.data( using: .utf8 )!

        try store.save( LayoutTemplateDescriptor( key: "invoice-default", documentType: "invoice" ), body: body )
        try store.save( LayoutTemplateDescriptor( key: "invoice-default", language: "es", documentType: "invoice" ), body: body )

        XCTAssertEqual( try store.load( key: "invoice-default", language: nil ), body )
        XCTAssertEqual( try store.load( key: "invoice-default", language: "es" ), body )
        // Language fallback to the neutral file
        XCTAssertEqual( try store.load( key: "invoice-default", language: "fr" ), body )

        let all = try store.list( documentType: nil )
        XCTAssertEqual( all.count, 2 )
        XCTAssertEqual( all.first?.key, "invoice-default" )
        XCTAssertEqual( all.first?.documentType, "invoice" )
        XCTAssertEqual( all.first?.name, "Default invoice" )

        XCTAssertEqual( try store.list( documentType: "quotation" ).count, 0 )

        try store.delete( key: "invoice-default", language: "es" )
        XCTAssertEqual( try store.list( documentType: nil ).count, 1 )

        XCTAssertThrowsError( try store.load( key: "missing", language: nil ) )

        // Garbage bodies are rejected on save
        XCTAssertThrowsError( try store.save( LayoutTemplateDescriptor( key: "bad" ), body: Data( "nope".utf8 ) ) )
    }

    // MARK: - Document validation

    func testNewerFormatVersionIsRejected ( ) throws {
        let json = """
        { "formatVersion": 999, "root": { "type": "text", "value": "x" } }
        """

        XCTAssertThrowsError( try decodePage( json ) )
    }
}
