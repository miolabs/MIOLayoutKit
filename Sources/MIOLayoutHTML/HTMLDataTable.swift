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
//    rows    .data-row, .sub-row, .link, .row-<color>   (<color>: red, green, yellow, grey, strong)
//    cells   .align-left / .align-center / .align-right, .zero, .cell-<color>
//    footer  .data-footer
//  Indented cells get `padding-left: <20 × level>px` (the web manager's indent).
//
//  Rows and footers can also be written with other markup (HTMLDataTableMarkup), e.g. the
//  web manager's CSS table of div.tr / div.td, so they drop into its existing table.
//

import Foundation
import MIOLayoutKit

/// Elements and classes for DataTable rows and footer rows.
public struct HTMLDataTableMarkup: Sendable, Equatable {
    public var rowTag: String
    public var cellTag: String
    public var rowClass: String
    public var subRowClass: String
    public var linkClass: String
    public var footerRowClass: String
    /// Added to every cell ("" for none).
    public var cellClass: String
    /// Row colours on every cell (as `cellColorPrefix + colour`) instead of `row-<colour>` on the row.
    public var rowColorsOnCells: Bool
    public var cellColorPrefix: String

    public init ( rowTag: String = "tr", cellTag: String = "td", rowClass: String = "data-row", subRowClass: String = "sub-row"
                , linkClass: String = "link", footerRowClass: String = "data-footer", cellClass: String = ""
                , rowColorsOnCells: Bool = false, cellColorPrefix: String = "cell-" ) {
        self.rowTag = rowTag
        self.cellTag = cellTag
        self.rowClass = rowClass
        self.subRowClass = subRowClass
        self.linkClass = linkClass
        self.footerRowClass = footerRowClass
        self.cellClass = cellClass
        self.rowColorsOnCells = rowColorsOnCells
        self.cellColorPrefix = cellColorPrefix
    }

    /// `<tr>` / `<td>` with the classes listed above.
    public static let table = HTMLDataTableMarkup( )

    /// The web manager's CSS table (ReportView.html): `div.tr` (`.sub`, `.footer`) and
    /// `div.td`, colours as plain classes on the cells (`.td.green`).
    public static let divTable = HTMLDataTableMarkup( rowTag: "div", cellTag: "div", rowClass: "tr", subRowClass: "sub"
                                                    , linkClass: "link", footerRowClass: "tr footer", cellClass: "td"
                                                    , rowColorsOnCells: true, cellColorPrefix: "" )
}

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

    /// The footer rows alone (totals), in `markup`.
    public func dataTableFooterRowsHTML ( _ table: DataTable, markup: HTMLDataTableMarkup = .table ) -> String {
        let formatter = valueFormatter
        let columns = table.visibleColumns
        var out = ""
        for footer in table.footersToDraw {
            let values = table.footerValues( footer )
            out += "<\(markup.rowTag) class=\"\(markup.footerRowClass)\">"
            for ( i, c ) in columns.enumerated( ) {
                var text = formatter.string( values[ c.key ], format: c.format )
                if i == 0, let label = footer.label, values[ c.key ] == nil { text = localizedString( label ) }
                var classes = ( markup.cellClass.isEmpty ? [] : [ markup.cellClass ] ) + [ "align-\(alignName( c.align ))" ]
                if c.format.type.isNumeric, let v = values[ c.key ], ValueFormatter.decimal( from: v ) == 0 { classes.append( "zero" ) }
                out += "<\(markup.cellTag) class=\"\(classes.joined( separator: " " ))\">\(HTMLRender.escape( text ))</\(markup.cellTag)>"
            }
            out += "</\(markup.rowTag)>\n"
        }
        return out
    }

    /// Row elements for the visible rows `range` (positions in `table.visibleRows`), in `markup`.
    public func dataTableRowsHTML ( _ table: DataTable, range: Range<Int>, formatter: ValueFormatter? = nil, markup: HTMLDataTableMarkup = .table ) -> String {
        let formatter = formatter ?? valueFormatter
        let columns = table.visibleColumns
        let rows = table.visibleRows
        let bounded = range.clamped( to: 0..<rows.count )
        var out = ""
        out.reserveCapacity( bounded.count * columns.count * 48 )

        // Per column, the start of the cell tag: `<td class="align-right` (+ the markup's cell class)
        let cellOpen = columns.map { c -> String in
            "<\(markup.cellTag) class=\"" + ( markup.cellClass.isEmpty ? "" : markup.cellClass + " " ) + "align-\(alignName( c.align ))"
        }
        let cellClose = "</\(markup.cellTag)>"
        let rowClose = "</\(markup.rowTag)>\n"

        for position in bounded {
            let row = rows[ position ]
            let style = table.source.rowStyle( row: row )
            out += "<"; out += markup.rowTag; out += " class=\""; out += markup.rowClass
            if style.isSubRow { out += " "; out += markup.subRowClass }
            if style.isLink { out += " "; out += markup.linkClass }
            let rowColor = style.color.flatMap { isReportColor( $0 ) ? $0 : nil }
            if let color = rowColor, !markup.rowColorsOnCells { out += " row-"; out += color }
            out += "\" data-row=\""; out += String( row ); out += "\">"

            for ( i, c ) in columns.enumerated( ) {
                let cell = table.cell( row: row, column: c, formatter: formatter )
                out += cellOpen[ i ]
                if let color = rowColor, markup.rowColorsOnCells { out += " "; out += markup.cellColorPrefix; out += color }
                if cell.isZero { out += " zero" }
                if let color = cell.style?.color, isReportColor( color ) { out += " "; out += markup.cellColorPrefix; out += color }
                out += "\""
                if let indent = cell.style?.indentLevel, indent > 0 {
                    out += " style=\"padding-left: "; out += String( indent * HTMLRender.dataTableIndentStep ); out += "px\""
                }
                out += ">"; out += HTMLRender.escape( cell.text ); out += cellClose
            }
            out += rowClose
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
