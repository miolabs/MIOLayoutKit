//
//  HTMLDataTable.swift
//  MIOLayoutHTML
//
//  HTML for DataTable: a real <table> (thead / tbody / tfoot), every value escaped.
//  `dataTableRowsHTML(_:range:)` renders a window of rows on its own, so a client that
//  shows thousands of rows can fill only the visible ones and swap them while scrolling.
//
//  Classes (style them in the page's CSS):
//    table   .data-table
//    rows    .data-row, .sub-row, .row-<color>          (<color>: red, green, yellow, grey, strong)
//    cells   .align-left / .align-center / .align-right, .zero, .cell-<color>
//    footer  .data-footer
//  Indented cells get `padding-left: <20 × level>px` (the web manager's indent).
//

import Foundation
import MIOLayoutKit

extension HTMLRender {

    public static let dataTableIndentStep = 20

    /// The whole table.
    public func dataTableHTML ( _ table: DataTable ) -> String {
        let formatter = valueFormatter
        let columns = table.visibleColumns
        var out: [String] = []

        out.append( "<table class=\"data-table\">" )
        if let title = table.title, !title.isEmpty {
            out.append( "<caption>\(HTMLRender.escape( localizedString( title ) ))</caption>" )
        }
        if table.showHeader {
            out.append( "<thead><tr>" )
            for c in columns {
                out.append( "<th class=\"align-\(alignName( c.align ))\">\(HTMLRender.escape( localizedString( c.title ) ))</th>" )
            }
            out.append( "</tr></thead>" )
        }
        out.append( "<tbody>" )
        let drawn = table.pageRows ?? 0..<table.visibleRows.count
        out.append( dataTableRowsHTML( table, range: drawn, formatter: formatter ) )
        out.append( "</tbody>" )

        if !table.footersToDraw.isEmpty {
            out.append( "<tfoot>" )
            for footer in table.footersToDraw {
                let values = table.footerValues( footer )
                out.append( "<tr class=\"data-footer\">" )
                for ( i, c ) in columns.enumerated( ) {
                    var text = formatter.string( values[ c.key ], format: c.format )
                    if i == 0, let label = footer.label, values[ c.key ] == nil { text = localizedString( label ) }
                    out.append( "<td class=\"align-\(alignName( c.align ))\">\(HTMLRender.escape( text ))</td>" )
                }
                out.append( "</tr>" )
            }
            out.append( "</tfoot>" )
        }
        out.append( "</table>" )
        return out.joined( separator: "\n" )
    }

    /// `<tr>` elements for the visible rows `range` (positions in `table.visibleRows`).
    public func dataTableRowsHTML ( _ table: DataTable, range: Range<Int>, formatter: ValueFormatter? = nil ) -> String {
        let formatter = formatter ?? valueFormatter
        let columns = table.visibleColumns
        let rows = table.visibleRows
        let bounded = range.clamped( to: 0..<rows.count )
        var out = ""
        out.reserveCapacity( bounded.count * columns.count * 48 )

        for position in bounded {
            let row = rows[ position ]
            let style = table.source.rowStyle( row: row )
            var rowClasses = [ "data-row" ]
            if style.isSubRow { rowClasses.append( "sub-row" ) }
            if let color = style.color, isReportColor( color ) { rowClasses.append( "row-\(color)" ) }
            out += "<tr class=\"\(rowClasses.joined( separator: " " ))\" data-row=\"\(row)\">"

            for c in columns {
                let ( text, cellStyle ) = table.cellText( row: row, column: c, formatter: formatter )
                var classes = [ "align-\(alignName( c.align ))" ]
                if table.isZero( row: row, column: c ) { classes.append( "zero" ) }
                if let color = cellStyle?.color, isReportColor( color ) { classes.append( "cell-\(color)" ) }
                var attributes = "class=\"\(classes.joined( separator: " " ))\""
                if let indent = cellStyle?.indentLevel, indent > 0 {
                    attributes += " style=\"padding-left: \(indent * HTMLRender.dataTableIndentStep)px\""
                }
                out += "<td \(attributes)>\(HTMLRender.escape( text ))</td>"
            }
            out += "</tr>\n"
        }
        return out
    }

    private func alignName ( _ align: TextAlign ) -> String {
        switch align {
        case .left:   return "left"
        case .center: return "center"
        case .right:  return "right"
        }
    }

    private func isReportColor ( _ color: String ) -> Bool {
        [ "red", "green", "yellow", "grey", "strong" ].contains( color )
    }
}
