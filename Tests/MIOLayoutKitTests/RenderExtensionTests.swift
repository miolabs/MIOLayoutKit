//
//  RenderExtensionTests.swift
//  MIOLayoutKitTests
//
//  Custom node handlers (LayoutRenderHandlers) and the value formatter.
//

import XCTest
@testable import MIOLayoutKit
@testable import MIOLayoutHTML
@testable import MIOLayoutText

/// A node type defined outside MIOLayoutKit, like DLDocumentKit's "dl.signatureBox".
final class SignatureBox: LayoutItem {
    var signer: String
    init(_ signer: String) { self.signer = signer; super.init() }
}

/// A custom container that draws its own frame around its children.
final class FramedBox: VStack<LayoutItem> {}

final class RenderExtensionTests: XCTestCase {

    /// Foundation uses no-break / narrow no-break spaces ("12,50\u{00A0}€", "11:30\u{202F}PM").
    private func plain(_ s: String) -> String {
        s.replacingOccurrences(of: "\u{00A0}", with: " ").replacingOccurrences(of: "\u{202F}", with: " ")
    }

    private func page(_ items: LayoutItem...) -> Page {
        let p = A4()
        for i in items { p.add(i) }
        return p
    }

    private func html(_ page: Page, _ handlers: LayoutRenderHandlers) -> (String, HTMLRender) {
        let r = HTMLRender()
        r.renderHandlers = handlers
        Layout(page).render(r)
        return (String(data: r.output(), encoding: .utf8)!, r)
    }

    // MARK: - Handlers

    func test_customLeaf_renderedByHandler() {
        let handlers = LayoutRenderHandlers()
        handlers.register(SignatureBox.self, renderer: HTMLRender.self) { box, html in
            html.appendRaw("<div class=\"signature\">\(HTMLRender.escape(box.signer))</div>")
        }

        let (out, render) = html(page(Text("Total"), SignatureBox("Ana & Co")), handlers)

        XCTAssertTrue(out.contains("<div class=\"signature\">Ana &amp; Co</div>"), out)
        XCTAssertTrue(out.contains(">Total</div>"), out)
        XCTAssertEqual(render.issues, [])
    }

    func test_customLeaf_withoutHandler_isReportedAndDrawnPlain() {
        let (out, render) = html(page(SignatureBox("Ana")), LayoutRenderHandlers())

        XCTAssertTrue(out.contains("<div class=\"d-flex\"></div>"), out)   // as before: a plain item
        XCTAssertEqual(render.issues.count, 1)
        XCTAssertTrue(render.issues[0].contains("SignatureBox"), render.issues[0])
    }

    func test_builtInTypes_areNeverReported() {
        let table = Table()
        table.addColumn("a", "A")
        table.addRow(["a": "1"])
        let (_, render) = html(page(Text("x"), Space(.m, .m), LayoutItem(1), table), LayoutRenderHandlers())

        XCTAssertEqual(render.issues, [])
    }

    func test_handlerForBaseRendererClass_servesEveryRenderer() {
        let handlers = LayoutRenderHandlers()
        handlers.register(SignatureBox.self, renderer: RenderContext.self) { box, ctx in
            if let html = ctx as? HTMLRender { html.appendRaw("<sig>\(box.signer)</sig>") }
            if let text = ctx as? TextRender { text.write(text: "SIGNED " + box.signer, x: 0, y: 0) }
        }

        let (out, _) = html(page(SignatureBox("Ana")), handlers)
        XCTAssertTrue(out.contains("<sig>Ana</sig>"), out)

        let text = TextRender()
        text.renderHandlers = handlers
        Layout(Page(Size(width: 40, height: 0))).render(text)   // empty page: begins the render
        let p = Page(Size(width: 40, height: 0))
        p.add(SignatureBox("Ana"))
        let t2 = TextRender()
        t2.renderHandlers = handlers
        Layout(p).render(t2)
        XCTAssertEqual(String(data: t2.output(), encoding: .utf8), "SIGNED Ana")
    }

    func test_handlerForCustomBaseClass_servesSubclasses_specificWins() {
        class CustomBase: LayoutItem {}
        final class Special: CustomBase {}
        final class Other: CustomBase {}
        let handlers = LayoutRenderHandlers()
        handlers.register(CustomBase.self, renderer: HTMLRender.self) { _, html in html.appendRaw("<base/>") }
        handlers.register(Special.self, renderer: HTMLRender.self) { _, html in html.appendRaw("<special/>") }

        let (out, render) = html(page(Special(), Other()), handlers)

        XCTAssertTrue(out.contains("<special/>\n<base/>"), out)
        XCTAssertEqual(render.issues, [])
    }

    func test_handlerForLayoutItem_doesNotTakeOverBuiltInTypes() {
        let handlers = LayoutRenderHandlers()
        handlers.register(LayoutItem.self, renderer: HTMLRender.self) { _, html in html.appendRaw("<spacer/>") }

        let (out, _) = html(page(Text("kept"), LayoutItem(1)), handlers)

        XCTAssertTrue(out.hasPrefix("<div class=\"page a4\">"), out)    // the page still renders
        XCTAssertTrue(out.contains(">kept</div>"), out)
        XCTAssertTrue(out.contains("<spacer/>"), out)                   // the plain LayoutItem itself
    }

    func test_measureHandler_setsTheItemSize() {
        let handlers = LayoutRenderHandlers()
        handlers.register(SignatureBox.self, renderer: TextRender.self,
                          measure: { _, _ in Size(width: 12, height: 3) },
                          render: { _, _ in })
        let box = SignatureBox("Ana")
        let render = TextRender()
        render.renderHandlers = handlers

        box.meassure(render)

        XCTAssertEqual(box.size.width, 12)
        XCTAssertEqual(box.size.height, 3)
    }

    func test_customContainer_handlerDrawsItsChildren() {
        let handlers = LayoutRenderHandlers()
        handlers.register(FramedBox.self, renderer: HTMLRender.self) { box, html in
            html.appendRaw("<fieldset>")
            for child in box.children { child.render(html) }
            html.appendRaw("</fieldset>")
        }
        let framed = FramedBox()
        framed.add(Text("inside"))

        let (out, render) = html(page(framed), handlers)

        XCTAssertTrue(out.contains("<fieldset>\n<div class=\"text-start text-sz-3\">inside</div>\n</fieldset>"), out)
        XCTAssertEqual(render.issues, [])
        XCTAssertEqual(render.containerStack.count, 1)   // the handler replaced begin/end: still balanced
    }

    // MARK: - Value formatter

    func test_valueFormatter_numericTypes_enUS() {
        let f = ValueFormatter(locale: Locale(identifier: "en_US"))
        let v = Decimal(string: "1234.5678")!
        XCTAssertEqual(plain(f.string(v, format: ValueFormat(.number))), "1,234.568")
        XCTAssertEqual(plain(f.string(v, format: ValueFormat(.integer))), "1,235")
        XCTAssertEqual(plain(f.string(v, format: ValueFormat(.currency))), "$1,234.57")
        XCTAssertEqual(plain(f.string(v, format: ValueFormat(.longCurrency))), "$1,234.5678")
        XCTAssertEqual(plain(f.string(Decimal(string: "15.879912")!, format: ValueFormat(.percentage))), "15.8799%")
        XCTAssertEqual(plain(f.string(Decimal(string: "15.8")!, format: ValueFormat(.percentage))), "15.80%")
    }

    func test_valueFormatter_esES_matchesTheServerFormatting() {
        let f = ValueFormatter(locale: Locale(identifier: "es_ES"))
        // Foundation (ICU) does not group four-digit numbers in Spanish
        XCTAssertEqual(plain(f.string(Decimal(string: "1234.5")!, format: ValueFormat(.currency))), "1234,50 €")
        XCTAssertEqual(plain(f.string(Decimal(string: "12345.5")!, format: ValueFormat(.currency))), "12.345,50 €")
        XCTAssertEqual(plain(f.string(Decimal(string: "0.125")!, format: ValueFormat(.number))), "0,125")
    }

    func test_valueFormatter_acceptsTheRawTypesReportsSend() {
        let f = ValueFormatter(locale: Locale(identifier: "en_US"))
        let currency = ValueFormat(typeName: "currency")
        XCTAssertEqual(plain(f.string(108.0, format: currency)), "$108.00")          // Double from JSON
        XCTAssertEqual(plain(f.string(42, format: currency)), "$42.00")              // Int
        XCTAssertEqual(plain(f.string("98.18", format: currency)), "$98.18")         // numeric string
        XCTAssertEqual(plain(f.string(NSDecimalNumber(string: "0.1"), format: currency)), "$0.10")
        XCTAssertEqual(plain(f.string(nil, format: currency)), "")
        XCTAssertEqual(plain(f.string("n/a", format: currency)), "n/a")              // unreadable: shown as is
        XCTAssertEqual(ValueFormat(typeName: "unknown-type").type, .string)
    }

    func test_valueFormatter_datesAreWallTime() {
        let madrid = TimeZone(identifier: "Europe/Madrid")!
        let f = ValueFormatter(locale: Locale(identifier: "en_US_POSIX"), timeZone: madrid)
        // "2026-03-29 02:30" does not exist in Madrid (DST); use an ordinary time
        XCTAssertEqual(plain(f.string("2026-01-31 23:30:00", format: ValueFormat(.date))), "1/31/26")
        XCTAssertEqual(plain(f.string("2026-01-31 23:30:00", format: ValueFormat(.time))), "11:30 PM")
        XCTAssertEqual(plain(f.string("2026-01-31", format: ValueFormat(.dateTime))), "1/31/26, 12:00 AM")
        XCTAssertEqual(plain(f.string("not a date", format: ValueFormat(.date))), "not a date")
    }

    func test_valueFormatter_localizedString() {
        let f = ValueFormatter(locale: Locale(identifier: "es_ES"), translations: ["TOTAL": "Total"])
        XCTAssertEqual(plain(f.string("TOTAL", format: ValueFormat(.localizedString))), "Total")
        XCTAssertEqual(plain(f.string("OTHER", format: ValueFormat(.localizedString))), "OTHER")
    }
}
