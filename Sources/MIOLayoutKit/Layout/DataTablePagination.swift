//
//  DataTablePagination.swift
//  MIOLayoutKit
//
//  Splits a DataTable that runs past the end of its page into page fragments, before
//  the pages are created. Every fragment but the last fills the rest of its page, so the
//  next one starts at the top of the next page and the page grid stays regular. Each
//  fragment repeats the header; the footers go with the last rows, or on their own page
//  (with the header) when they do not fit.
//

import Foundation

/// Container access without knowing the element type.
package protocol LayoutChildContainer: AnyObject {
    var childItems: [LayoutItem] { get }
    /// Replaces the child at `index` with `items`; false when the container cannot hold them.
    func replaceChild ( at index: Int, with items: [LayoutItem] ) -> Bool
}

extension Container: LayoutChildContainer {
    package var childItems: [LayoutItem] { children.map { $0 as LayoutItem } }

    package func replaceChild ( at index: Int, with items: [LayoutItem] ) -> Bool {
        guard index < children.count else { return false }
        var typed: [E] = []
        for item in items {
            guard let e = item as? E else { return false }
            typed.append( e )
        }
        children.remove( at: index )
        children.insert( contentsOf: typed, at: index )
        for item in typed { item.parent = self }
        return true
    }
}

extension Layout {

    /// Finds the first whole DataTable (in a vertical stack) that crosses a page boundary and
    /// replaces it with its page fragments. Returns false when there is none.
    func splitFirstCrossingDataTable ( _ context: RenderContext, pageHeight H: Float ) -> Bool {
        guard let ( parent, index, table ) = firstCrossingDataTable( in: rootItem, context: context, pageHeight: H ) else { return false }
        let fragments = pageFragments( of: table, context: context, pageHeight: H )
        if fragments.count <= 1 { return false }
        return parent.replaceChild( at: index, with: fragments )
    }

    private func firstCrossingDataTable ( in item: LayoutItem, context: RenderContext, pageHeight H: Float ) -> ( LayoutChildContainer, Int, DataTable )? {
        guard let container = item as? LayoutChildContainer else { return nil }
        for ( index, child ) in container.childItems.enumerated( ) {
            if let table = child as? DataTable, table.pageRows == nil, table.fillHeight == nil, item is VerticalStackItem {
                let top = table.absPosition( ).y
                let height = context.dataTableMetrics( table ).height( of: table )
                let pageEnd = ( ( top / H ).rounded( .down ) + 1 ) * H
                if top + height > pageEnd + 0.5 { return ( container, index, table ) }
            }
            if let found = firstCrossingDataTable( in: child, context: context, pageHeight: H ) { return found }
        }
        return nil
    }

    func pageFragments ( of table: DataTable, context: RenderContext, pageHeight H: Float ) -> [DataTable] {
        let m = context.dataTableMetrics( table )
        let top = table.absPosition( ).y
        let total = table.visibleRows.count
        let footersHeight = Float( table.footers.count ) * m.footer
        let titleHeight: Float = table.title?.isEmpty == false ? m.title : 0
        let epsilon: Float = 0.01

        var fragments: [DataTable] = []
        var space = ( ( top / H ).rounded( .down ) + 1 ) * H - top     // left on the first page
        var position = 0

        while fragments.count < 10_000 {
            let first = fragments.isEmpty
            let headerHeight = ( first ? titleHeight : 0 ) + ( table.showHeader ? m.header : 0 )
            let available = space - headerHeight
            var take = min( total - position, max( 0, Int( ( ( available + epsilon ) / m.row ).rounded( .down ) ) ) )
            // a page shorter than header + one row: still advance one row per page
            if take == 0 && !first && position < total { take = 1 }

            let lastRows = position + take == total
            let roomForFooters = available - Float( take ) * m.row + epsilon >= footersHeight

            if lastRows && roomForFooters {
                let f = table.fragment( rows: position..<total, header: table.showHeader, footers: true, fill: nil )
                if first { f.title = table.title }
                fragments.append( f )
                break
            }

            // rows (possibly none) fill the rest of this page; continue on the next one
            let f = table.fragment( rows: position..<( position + take ), header: table.showHeader && take > 0, footers: false, fill: max( 0, space - epsilon ) )
            if first { f.title = take > 0 ? table.title : nil }
            fragments.append( f )
            position += take
            space = H
        }
        return fragments
    }
}
