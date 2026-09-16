    import XCTest
    @testable import MIOLayoutKit

    final class MIOLayoutKitTests: XCTestCase {
        func testText ( ) throws {
            let page = A4( )
            let text = Text( "Hello World", id: "ID1" )
            let layout = Layout( page )
            
            page.add( text )
            
            XCTAssertNotNil( layout.elementsByID[ "ID1" ] )
            
            let render = HTMLRender( )
            
            layout.render( render )
            
            XCTAssertEqual( String( data: render.output( ), encoding: .utf8 ), """
<div class="page a4">
<div class="text-start text-sz-3">Hello World</div>
</div>
""" )
            
            render.reset( )
            try layout.setValue( forID: "ID1", value: "Bye bye World" )
            layout.render( render )

            XCTAssertEqual( String( data: render.output( ), encoding: .utf8 ), """
<div class="page a4">
<div class="text-start text-sz-3">Bye bye World</div>
</div>
""" )
        }
        
        func testTranslateText ( ) throws {
            let text_tr = LocalizedText( "KEY" )
            let text_tr2 = LocalizedText( "FORGOT" )
            let render = HTMLRender( [ "KEY": "Helloo" ] )

            let page = A4( )
            let layout = Layout( page )
            
            page.add( text_tr )
            page.add( text_tr2 )

            layout.render( render )
            
            XCTAssertEqual( String( data: render.output( ), encoding: .utf8 ), """
<div class="page a4">
<div class="text-start text-sz-3">Helloo</div>
<div class="text-start text-sz-3">__FORGOT__</div>
</div>
""" )
        }
        
        func testHstack ( ) throws {
            let render = HTMLRender( )
            let page   = A4( )
            let row    = HStack( )
            let layout = Layout( page )

            row.add( Text( "Hello ", id: "ID1" ) )
            row.add( Text( "Word", id: "ID2" ) )

            page.add( row )

            XCTAssertNotNil( layout.elementsByID[ "ID1" ] )
            XCTAssertNotNil( layout.elementsByID[ "ID2" ] )
            try layout.setValue( forID: "ID2", value: "World!!!" )
            
            layout.render( render )
            
            XCTAssertEqual( String( data: render.output( ), encoding: .utf8 ), """
<div class="page a4">
<div class="row">
<div class="text-start text-sz-3">Hello </div>
<div class="text-start text-sz-3">World!!!</div>
</div>
</div>
""" )
        }

        
        func testVstack ( ) throws {
            let render = HTMLRender( )
            let page   = A4( )
            let row    = VStack( )
            let layout = Layout( page )

            row.add( Text( "Hello ", id: "ID1" ) )
            row.add( Text( "World", id: "ID2" ) )

            page.add( row )
            
            layout.render( render )
            
            XCTAssertEqual( String( data: render.output( ), encoding: .utf8 ), """
<div class="page a4">
<div class="col">
<div class="text-start text-sz-3">Hello </div>
<div class="text-start text-sz-3">World</div>
</div>
</div>
""" )
        }

        
        func testImage ( ) throws {
            let render = HTMLRender( )
            let page   = A4( )
            let img    = URLImage( url: "dual-link.com/img.jpg", width: 200, height: 100 )
            let container = Container( )
            let layout = Layout( page )
            
            container.add( img )
            page.add( container )
            
            layout.render( render )
            
            XCTAssertEqual( String( data: render.output( ), encoding: .utf8 ), """
<div class="page a4">
<div>
<img src="dual-link.com/img.jpg" width="200" height="100"/>
</div>
</div>
""" )
        }
        

        func testVStackFlex3 ( ) throws {
            let render = HTMLRender( )
            let page   = A4( )
            let row    = HStack( 1 )
            let layout = Layout( page )

            row.add( LayoutItem( 1 ) )
            row.add( Text( "Hello" ) )
            row.add( LayoutItem( 2 ) )
            row.add( Text( "World" ) )
            row.add( LayoutItem( 1 ) )
            page.add( row )
            
            layout.render( render )
            
            XCTAssertEqual( String( data: render.output( ), encoding: .utf8 ), """
<div class="page a4">
<div class="row" style="flex: 1">
<div class="d-flex" style="flex: 1"></div>
<div class="text-start text-sz-3">Hello</div>
<div class="d-flex" style="flex: 2"></div>
<div class="text-start text-sz-3">World</div>
<div class="d-flex" style="flex: 1"></div>
</div>
</div>
""" )
        }
        
        func testTable ( ) throws {
            let render = HTMLRender( )
            let page   = A4( )
            let row    = HStack( 1 )
            let layout = Layout( page )
            let table  = Table( )
            
            table.addColumn( "population", "Population" )
            table.addColumn( "country", "Country" )
            
            table.addRow( [ "population": 1234  , "country": "Spain"   ] )
            table.addRow( [ "population": 12    , "country": "France"  ] )
            table.addRow( [ "population": 123456, "country": "Germany-Holland" ] )

            row.add( LayoutItem( 1 ) )
            row.add( table )
            row.add( LayoutItem( 1 ) )
            page.add( row )
            
            layout.render( render )
            
            XCTAssertEqual( String( data: render.output( ), encoding: .utf8 ), """
<div class="page a4">
<div class="row" style="flex: 1">
<div class="d-flex" style="flex: 1"></div>
<div  class="table-fixed-header border">
  <div class="table-container">
    <div class="table-header">
        <table>
            <colgroup>
<col style="width: 1px;"/>
<col style="width: 2px;"/>
            </colgroup>
            <thead class="table-thead">
                <tr>
<th class="table-cell">
<div class="text-start text-nowrap">Population</div>
</th>
<th class="table-cell">
<div class="text-start text-nowrap">Country</div>
</th>
                </tr>
            </thead>
        </table>
    </div>
    <div class="table-body">
        <table>
            <colgroup>
<col style="width: 1px;"/>
<col style="width: 2px;"/>
            </colgroup>
            <tbody class="table-tbody">
                <tr aria-hidden="true" class="table-measure-row" style="height: 0px; font-size: 0px;">
<td style="padding: 0px; border: 0px; height: 0px;"><div style="height: 0px; overflow: hidden;">&nbsp;</div></td>
<td style="padding: 0px; border: 0px; height: 0px;"><div style="height: 0px; overflow: hidden;">&nbsp;</div></td>
                </tr>
<tr data-row-key="0" class="table-row">
<td class="table-cell"><span class="table-row-indent" style="padding-left: 0px;"></span>
<div class="text-start text-nowrap text-sz-3">1234</div>
</td>
<td class="table-cell"><span class="table-row-indent" style="padding-left: 0px;"></span>
<div class="text-start text-nowrap text-sz-3">Spain</div>
</td>
</tr>
<tr data-row-key="0" class="table-row">
<td class="table-cell"><span class="table-row-indent" style="padding-left: 0px;"></span>
<div class="text-start text-nowrap text-sz-3">12</div>
</td>
<td class="table-cell"><span class="table-row-indent" style="padding-left: 0px;"></span>
<div class="text-start text-nowrap text-sz-3">France</div>
</td>
</tr>
<tr data-row-key="0" class="table-row">
<td class="table-cell"><span class="table-row-indent" style="padding-left: 0px;"></span>
<div class="text-start text-nowrap text-sz-3">123456</div>
</td>
<td class="table-cell"><span class="table-row-indent" style="padding-left: 0px;"></span>
<div class="text-start text-nowrap text-sz-3">Germany-Holland</div>
</td>
</tr>
            </tbody>
        </table>
    </div>
  </div>
</div>
<div class="d-flex" style="flex: 1"></div>
</div>
</div>
""" )
        }

        
        
        func testText_TR ( ) throws {
            let page = Page( Size( width: 80, height: 0 ) )
            let text = Text( "Hello World" )
            let layout = Layout( page )
            // Text is dimensioned to expand to use all the container (Page is VSTACK)
            page.add( text )
            
            let render = TextRender( )
            
            layout.render( render )
            
            XCTAssertEqual( String( data: render.output( ), encoding: .utf8 ), "Hello World                                                                     " )
        }

        func testHStack_TR ( ) throws {
            let render = TextRender( )
            let page   = Page( Size( width: 80, height: 0 ) )
            let row    = HStack( )
            let layout = Layout( page )

            row.add( Text( "Hello " ) )
            row.add( Text( "World" ) )
            page.add( row )
            
            layout.render( render )
            
            XCTAssertEqual( String( data: render.output( ), encoding: .utf8 ), """
Hello World
""" )
        }

        func testVStack_TR ( ) throws {
            let render = TextRender( )
            let page   = Page( Size( width: 80, height: 0 ) )
            let row    = VStack( )
            let layout = Layout( page )

            row.add( Text( "Hello", align: .right ) )
            row.add( Text( "World", align: .right ) )
            page.add( row )
            
            layout.render( render )
            
            XCTAssertEqual( String( data: render.output( ), encoding: .utf8 ), """
                                                                           Hello
                                                                           World
""" )
        }

        func testVStackFlex_TR ( ) throws {
            let render = TextRender( )
            let page   = Page( Size( width: 40, height: 0 ) )
            let row    = HStack( 1 )
            let layout = Layout( page )

            row.add( Text( "Hello" ) )
            row.add( LayoutItem( 1 ) )
            row.add( Text( "World" ) )
            page.add( row )
            
            layout.render( render )
            
            XCTAssertEqual( String( data: render.output( ), encoding: .utf8 ), """
Hello                              World
""" )
        }

        func testVStackFlex3_TR ( ) throws {
            let render = TextRender( )
            let page   = Page( Size( width: 40, height: 0 ) )
            let row    = HStack( 1 )
            let layout = Layout( page )

            row.add( LayoutItem( 1 ) )
            row.add( Text( "Hello" ) )
            row.add( LayoutItem( 2 ) )
            row.add( Text( "World" ) )
            row.add( LayoutItem( 1 ) )
            page.add( row )
            
            layout.render( render )
            
            XCTAssertEqual( String( data: render.output( ), encoding: .utf8 ), """
       Hello               World
""" )
        }

        
        func testImage_TR ( ) throws {
            let render = TextRender( )
            let page   = Page( Size( width: 40, height: 0 ) )
            let row    = HStack( 1 )
            let layout = Layout( page )

            row.add( LayoutItem( 1 ) )
            row.add( URLImage( url: "Hello", width: 20, height: 3 ) )
            row.add( LayoutItem( 1 ) )
            page.add( row )
            
            layout.render( render )
            
            XCTAssertEqual( String( data: render.output( ), encoding: .utf8 ), """
          IIIIIIIIIIIIIIIIIIII
          IIIIIIIIIIIIIIIIIIII
          IIIIIIIIIIIIIIIIIIII
""" )
        }

        
        func testTable_TR ( ) throws {
            let render = TextRender( )
            let page   = Page( Size( width: 40, height: 0 ) )
            let row    = HStack( 1 )
            let layout = Layout( page )
            let table  = Table( )
            
            table.addColumn( "population", "Population", align: .center )
            table.addColumn( "country", "Country", align: .right )
            
            table.addRow( [ "population": 1234  , "country": "Spain"   ] )
            table.addRow( [ "population": 12    , "country": "France"  ] )
            table.addRow( [ "population": 123456, "country": "Germany-Holland" ] )

            row.add( LayoutItem( 1 ) )
            row.add( table )
            row.add( LayoutItem( 1 ) )
            page.add( row )
            
            layout.render( render )
            
            XCTAssertEqual( String( data: render.output( ), encoding: .utf8 ), """
      +----------+---------------+
      |Population|        Country|
      +----------+---------------+
      |   1234   |          Spain|
      +----------+---------------+
      |    12    |         France|
      +----------+---------------+
      |  123456  |Germany-Holland|
      +----------+---------------+
""" )
        }

    func testTableFull_TR ( ) throws {
        let render = TextRender( )
        let page   = Page( Size( width: 40, height: 0 ) )
        let row    = HStack( 1 )
        let layout = Layout( page )
        let table  = Table( 1 )
        
        table.addColumn( "population", "Population", flex: 1, align: TextAlign.right )
        table.addColumn( "country", "Country", align: TextAlign.left )
        
        table.addRow( [ "population": 1234  , "country": "Spain"   ] )
        table.addRow( [ "population": 12    , "country": "France"  ] )
        table.addRow( [ "population": 123456, "country": "Germany-Holland" ] )

        row.add( table )
        page.add( row )
        
        layout.render( render )
        
        XCTAssertEqual( String( data: render.output( ), encoding: .utf8 ), """
+-------------------------+---------------+
|               Population|Country        |
+-------------------------+---------------+
|                     1234|Spain          |
+-------------------------+---------------+
|                       12|France         |
+-------------------------+---------------+
|                   123456|Germany-Holland|
+-------------------------+---------------+
""" )
        }

}
