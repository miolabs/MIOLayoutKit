//
//  HTMLRender.swift
//  
//
//  Created by David Trallero on 23/06/2021.
//

import Foundation

public class HTMLRender: RenderContext {
    var m_output: [String] = []
    var m_output_stack: [[String]] = []
    
    func push_output ( ) {
        m_output_stack.append( m_output )
        m_output = []
    }
    
    func pop_output ( ) -> String {
        let ret = m_output.joined(separator: "\n")
        
        m_output = m_output_stack.last!
        
        return ret
    }
    

    override open func renderItem ( _ item: LayoutItem ) {
        var styles: [String] = itemStyles( item )

        if let text = item as? Text {
            var classes: [String] = []
            
            func align_classname ( ) -> String {
              return text.align == .left   ? "start"
                   : text.align == .center ? "center"
                   : text.align == .right  ? "end"
                   :                         "start"
            }
            
            classes.append( "text-\(align_classname())" )
            
            if text.wrap == .noWrap { classes.append( "text-nowrap" ) }
            if text.bold            { classes.append( "fw-bold"     ) }
            if text.italic          { classes.append( "fst-italic"  ) }
            
            if text.text_size != .m { classes.append( "text-sz-\(text.text_size.rawValue)" ) }
            
            m_output.append( "<div\(renderClasses(classes))\(renderStyles( styles ))>\(text.text)</div>")
        } else if let img = item as? URLImage {
            m_output.append( "<img src=\"\(img.url)\" width=\"\(Int(img.dimensions.width))\" height=\"\(Int(img.dimensions.height))\"/>")
        } else if let spc = item as? Space {
            styles.append( "width:\(Int(spc.size.width))px" )
            styles.append( "height:\(Int(spc.size.height))px" )
            
            m_output.append( "<div\(renderStyles( styles ))></div>" )
        } else {
            m_output.append( "<div class=\"d-flex\"\(renderStyles( styles ))></div>" )
        }
    }
    
    func reset ( ) {
        m_output = []
    }
    
    override open func output() -> Data {
        return m_output.joined(separator: "\n").data( using: .utf8 )!
    }
    
    
    override open func beginContainer ( _ container: Container<LayoutItem> ) {
        var styles: [String] = itemStyles( container )
        
        if container is A4 {
            m_output.append( "<div class=\"page a4\"\(renderStyles( styles ))>" )
        } else if let page = container as? Page {
            if page.size.width  > 0 { styles.append( "width: \(Int(page.size.width))px" ) }
            if page.size.height > 0 { styles.append( "height: \(Int(page.size.height))px" ) }
            
            m_output.append( "<div class=\"page\"\(renderStyles( styles ))>" )
        } else if let table = container as? Table {
            let header = table.header!.children
            let COLS = header.map{ "<col style=\"width: \(Int($0.dimensions.width))px;\"/>" }.joined(separator: "\n")
            
            push_output()
            for h in header {
                m_output.append( "<th class=\"table-cell\">" )
                h.render( self )
                m_output.append( "</th>" )
            }
            let HEADER = pop_output()
            
            let HIDDEN_ROW = header.map{ _ in "<td style=\"padding: 0px; border: 0px; height: 0px;\"><div style=\"height: 0px; overflow: hidden;\">&nbsp;</div></td>" }.joined(separator: "\n")
            
            push_output()
            
            for row in table.body.children {
                m_output.append( "<tr data-row-key=\"0\" class=\"table-row\">" )
                for col in (row as! HStack).children {
                    m_output.append( "<td class=\"table-cell\"><span class=\"table-row-indent\" style=\"padding-left: 0px;\"></span>" )
                    
                    col.render( self )
                    
                    m_output.append( "</td>" )
                
                }
                
                m_output.append( "</tr>" )
            }
            
            let DATA = pop_output()
            var classes = ["table-fixed-header"]
            
            if table.border { classes.append( "border" ) }
            if table.hideHeader { classes.append( "hide-header" ) }
            
            let table = """
<div \(renderClasses( classes ))\(renderStyles( styles ))>
  <div class="table-container">
    <div class="table-header">
        <table>
            <colgroup>
{{COLS}}
            </colgroup>
            <thead class="table-thead">
                <tr>
{{HEADER}}
                </tr>
            </thead>
        </table>
    </div>
    <div class="table-body">
        <table>
            <colgroup>
{{COLS}}
            </colgroup>
            <tbody class="table-tbody">
                <tr aria-hidden="true" class="table-measure-row" style="height: 0px; font-size: 0px;">
{{HIDDEN_ROW}}
                </tr>
{{DATA}}
            </tbody>
        </table>
    </div>
  </div>
"""
            m_output.append(
                table.replacingOccurrences(of: "{{COLS}}", with: COLS )
                     .replacingOccurrences(of: "{{HEADER}}", with: HEADER )
                     .replacingOccurrences(of: "{{HIDDEN_ROW}}", with: HIDDEN_ROW )
                     .replacingOccurrences(of: "{{DATA}}", with: DATA )
                )
        } else if container is HStack {
            m_output.append( "<div class=\"row\"\(renderStyles( styles ))>" )
        } else if container is VStack {
            m_output.append( "<div class=\"col\"\(renderStyles( styles ))>" )
        } else {
            m_output.append( "<div\(renderStyles( styles ))>" )
        }
        super.beginContainer( container )
    }
    
    open func itemStyles ( _ item: LayoutItem ) -> [String] {
        var styles: [String] = []
        
        if item.flex > 0 { styles.append( "flex: \(item.flex)" ) }
        if item.style.borderRadius > 0 { styles.append( "border-radius: \(item.style.borderRadius)px" ) }
        if item.style.bgColor != nil { styles.append( "background-color: \(item.style.bgColor!)") }
        if item.style.fgColor != nil { styles.append( "color: \(item.style.fgColor!)") }

        return styles
    }
    
    
    open func renderStyles ( _ styles: [String] ) -> String {
        return styles.count > 0 ?
                 " style=\"\(styles.joined(separator: ";"))\""
               : ""
    }
    
    
    open func renderClasses ( _ classes: [String] ) -> String {
        return classes.count > 0 ?
                 " class=\"\(classes.joined(separator: " "))\""
               : ""
    }

    
    override open func endContainer ( _ container: Container<LayoutItem> ) {
        m_output.append( "</div>" )
        super.endContainer( container )
    }
    
    override open func meassure ( _ item: LayoutItem ) -> Size {
        if let text = item as? Text {
            return Size( width: Float( text.text.count ) * Float(8) / Float(60),  height: 1 )
        } else if let page = item as? Page {
            return page.size
        } else if let spc = item as? Space {
            return Size( width: Float( spc.a.rawValue * 5 )
                       , height: Float( spc.b.rawValue * 5 ) )
        }
            
        return super.meassure( item )
    }
}
