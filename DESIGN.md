# MIOLayoutKit — Serializable Layouts & Custom Documents

**Status:** Design approved, implementation pending
**Date:** 2026-07-24
**Scope:** MIOReportKit-Swift (→ MIOLayoutKit), DualLinkDB, new DLDocumentKit, DLTemplateServer

## Goal

Today every template (invoice, stock note, ticket, email) is compiled Swift code in
DLTemplateServer, built with this library's result-builder DSL and rendered to HTML /
text / PDF. This design adds:

1. A **serialized layout format** (versioned JSON) so layouts can be saved to files.
2. **Storage protocols** with a file implementation here and a DB implementation over
   a new DualLinkDB entity.
3. A **companion library (DLDocumentKit)** — depending on MIOLayoutKit + DualLinkDB
   only (NOT DualLinkServerKit) — so both servers and client apps can decode, fill,
   and render customizable documents (invoices, quotations, …), which the template
   server can then email.

## 1. Rename: MIOReportKit-Swift → MIOLayoutKit

Done first, before any new code lands.

- Rename GitHub repo `miolabs/MIOReportKit-Swift` → `miolabs/MIOLayoutKit`
  (GitHub redirects old URLs; history preserved).
- Package / product / target / module all become `MIOLayoutKit`
  (`import MIOLayoutKit` — no more `MIOReportKit_Swift` underscore).
- Consumers to update:
  - **DLTemplateServer** — Package.swift URL/product + import lines (~8 files).
  - **POSShared (Bar app)** — `PrinterTemplate.swift` import + xcodeproj package ref.
    (It imports both the legacy `MIOReportKit` and this lib; only this one changes.)
- Untouched legacy: `Libs/MIOReportKit` (old xcodeproj lib) and the abandoned
  `Swift-MIOReportKit` repo variant.
- Local folder rename: `~/Projects/Libs/MIOReportKit-Swift` → `MIOLayoutKit`.

## 2. Architecture

```
MIOLayoutKit  (renamed from MIOReportKit-Swift)      iOS / macOS / Linux
 ├─ Layout DSL + renderers (HTML, Text, PDF)          (unchanged)
 └─ Serialization/  ← new
     ├─ LayoutNode          versioned Codable DTO node tree
     ├─ LayoutEncoder       layout tree → JSON
     ├─ LayoutDecoder       JSON + LayoutDataProvider → layout tree
     ├─ LayoutNodeRegistry  + LayoutFragmentLibrary   (extension points)
     ├─ LayoutDataProvider  pull-based value protocol (+ DictionaryDataProvider)
     └─ LayoutTemplateStore protocol + FileLayoutTemplateStore

DLDocumentKit  ← new package (~/Projects/Libs/DLDocumentKit)   iOS / macOS / Linux
 ├─ depends: MIOLayoutKit + DualLinkDB   (NO DualLinkServerKit — apps use it too)
 ├─ EntityDataProvider + per-document subclasses (invoice, quotation, …)
 ├─ DBLayoutTemplateStore over the LayoutDocumentTemplate entity
 ├─ DocumentRenderer: templateKey + entityID → HTML/PDF Data
 └─ registers document node types & fragments (prefix "dl.")

DLTemplateServer  (thin integration)                  server only
 ├─ routes: CRUD / validate / render / send
 ├─ bridges EntityContext → DocumentEnvironment (moc, language, locale, paths)
 └─ email send via existing SwiftSMTP path in DualLinkServerKit
```

Key principle: **logic never lives in the template**. Anything computed (grouping
invoice lines by category, tax accumulation, totals) is Swift code in a data
provider. The JSON only *binds* to ready-made values. This keeps templates safe to
store per-tenant and keeps the format small.

## 3. Serialized format

One JSON document per template, rooted at a page. Example (abridged invoice):

```json
{
  "formatVersion": 1,
  "documentType": "invoice",
  "paper": "a4-portrait",
  "margins": { "top": 8, "left": 8, "right": 8, "bottom": 8 },
  "root": {
    "type": "vstack",
    "children": [
      { "type": "hstack", "flex": 1, "children": [
        { "type": "vstack", "children": [
          { "type": "localizedText", "key": "INVOICE", "textSize": "xl", "bold": true },
          { "type": "text", "value": "{{ doc.documentNumber }}", "textSize": "l", "bold": true },
          { "type": "text", "value": "{{ doc.date }}" }
        ]},
        { "type": "vstack", "ref": "dl.legalEntityBlock" }
      ]},
      { "type": "table", "rows": "doc.lines", "border": true,
        "columns": [
          { "title": "DESCRIPTION", "key": "concept",     "flex": 3 },
          { "title": "QTY",         "key": "quantity",    "align": "right" },
          { "title": "PRICE",       "key": "priceAmount", "align": "right" },
          { "title": "TOTAL",       "key": "baseAmount",  "align": "right" }
        ],
        "footerRows": [
          { "concept": "{{ 'TOTAL' | localized }}", "baseAmount": "{{ doc.totalAmount }}" }
        ]
      },
      { "type": "text", "value": "{{ company.paymentOptionsText }}",
        "visibleIf": "company.showPaymentOptionsText" }
    ]
  }
}
```

Format rules:

- **Typed nodes, not a property bag.** Each `type` maps to a Codable payload struct
  (`TextNode`, `TableNode`, …). Strict decoding errors; self-documenting for a
  future editor. Unknown `type` → decode error naming the missing type, unless a
  registry entry handles it.
- **`ref` nodes** resolve reusable fragments (company header, legal-entity block,
  address block, document footer) from `LayoutFragmentLibrary`. Built-ins are
  encoded once from the existing Swift helpers (`document_header_hstack`,
  `address_vstack`, `doc_footer_hstack`, …).
- **Style** is a nested object mirroring `Style`/`FontStyle` (border, colors,
  radius) so DSL modifiers and JSON attributes stay 1:1.
- **Sectioned tables** (invoice category groups) are a first-class node:
  `{ "type": "sectionedTable", "sections": "doc.sections", ... }` — each section
  provider vends `title` + `rows`.
- **Images** serialize as URLs / asset references only, never inline data.
- **Versioned** via `formatVersion` from day one.

### Binding grammar — deliberately tiny

| Construct        | Example                                | Semantics                                        |
|------------------|----------------------------------------|--------------------------------------------------|
| Path             | `{{ doc.documentNumber }}`             | pull `text(forPath:)` from the data provider     |
| Optional hint    | `{{ doc.date \| short }}`              | pass-through string hint; provider may ignore it |
| Collection       | `"rows": "doc.lines"`                  | `items(forPath:)` — each item is a scoped provider |
| Visibility       | `"visibleIf": "company.showX"`         | `bool(forPath:)`; node dropped before layout     |

No loops, no arithmetic, no comparisons, no nested conditionals — by design.
MIOLayoutKit never interprets hints or formats values; providers return final
display text.

## 4. Pull-based data provider

The decoder pulls values lazily as it meets dynamic nodes; static nodes never touch
the provider. After decoding, the tree is plain literal `LayoutItem`s and the
existing render pipeline runs unchanged. (Consequence: the renderers' unused
`formmatterType` machinery stays untouched — formatting is fully the provider's job.)

```swift
public protocol LayoutDataProvider: AnyObject {
    /// REQUIRED. Final, already-formatted display string for a path. nil → empty/skip.
    func text(forPath path: String, hint: String?) -> String?

    // The rest have default implementations — minimal conformance is text() only.

    /// For visibleIf. Default: false.
    func bool(forPath path: String) -> Bool
    /// For dynamic images (logo, QR): URL or raw data. Default: nil.
    func image(forPath path: String) -> LayoutImageSource?
    /// Scoped collection resolution: each item is itself a provider scoped to
    /// that element — column keys resolve against it.
    /// Default: nil → decoder falls back to FLAT INDEXED resolution (below).
    func items(forPath path: String) -> [LayoutDataProvider]?
    /// Number of elements in a collection, for flat mode.
    /// Default: nil → decoder probes row by row.
    func count(forPath path: String) -> Int?
}
```

Collections resolve in one of two modes, decided per path at decode time:

1. **Scoped mode** — `items(forPath:)` returns providers; a table row resolves
   column keys against the row's own provider; a sectioned table is
   `items("doc.sections")` → each answers `text("title")` and `items("rows")`.
   This is what `EntityDataProvider` in DLDocumentKit implements.

2. **Flat indexed mode** (fallback when `items` returns nil) — the decoder
   addresses every cell through the root provider with index-extended paths:

   ```
   doc.lines.0.concept   doc.lines.0.quantity   doc.lines.0.baseAmount
   doc.lines.1.concept   doc.lines.1.quantity   ...
   ```

   Row count: `count(forPath: "doc.lines")` if implemented; otherwise the
   decoder **probes** ascending indices and stops at the first row where every
   column path returns nil. (Convention to document for implementers: a row
   whose cells are all legitimately empty terminates probing — implement
   `count` if that case can occur.)

   **Sectioned tables in flat mode do NOT nest rows under sections.** Rows are
   one flat, globally-indexed list; sections are separate call families the
   provider can parse trivially (split on "."):

   ```
   doc.sections.0.title           ← section header
   doc.sections.0.footer.total    ← section footer cells (per column key)
   doc.rows.0.concept  doc.rows.0.quantity ...   ← global row list, in order
   doc.rows.1.concept  ...
   ```

   Section↔row association comes from consecutive counts: the decoder asks
   `count(forPath: "doc.sections")` and, per section,
   `count(forPath: "doc.sections.\(i).rows")` — section 0 owns the first c₀
   rows, section 1 the next c₁, and so on. Row paths never mention the
   section, so a provider backed by a flat line list (exactly the shape of
   today's invoice data) answers each family independently.

   Flat mode makes trivial providers trivial: a conformer with only `text()`
   backed by a lookup table — or bridged from another language/system that can
   only answer string-for-string — can drive full templates including tables.

- **`DictionaryDataProvider`** (nested `[String: Any]` of pre-formatted values)
  ships in MIOLayoutKit for tests, the validate endpoint, and editor previews;
  it answers both modes and doubles as the reference implementation.

## 5. Core API (MIOLayoutKit / Serialization)

Naming follows Swift `Codable`/`NSCoding` conventions: encode/decode. The layout
classes are NOT Swift-`Codable` themselves — only the `LayoutNode` DTOs are; the
protocol below avoids the name collision.

```swift
public final class LayoutEncoder {
    public init(registry: LayoutNodeRegistry = .standard)
    public func encode(_ page: Page, documentType: String? = nil, name: String? = nil) throws -> Data
    public func encodeItem(_ item: LayoutItem) throws -> LayoutNode
}

public final class LayoutDecoder {
    public init(registry: LayoutNodeRegistry = .standard,
                fragments: LayoutFragmentLibrary = .standard)
    public func decode(_ data: Data, provider: LayoutDataProvider? = nil) throws -> Page
    public func decodeItem(_ node: LayoutNode) throws -> LayoutItem?  // nil = hidden by visibleIf
    public private(set) var issues: [String]  // unresolved paths etc., for validate flows
}

// One entry per node type; decode looked up by nodeType, encode matchers run
// in order (subclasses registered before parents). Closure-based instead of a
// protocol so class hierarchies (LocalizedText: Text, Padding: VStack) can't
// accidentally inherit the wrong coder.
public struct LayoutNodeCoder {
    public init(nodeType: String,
                decode: @escaping (LayoutNode, LayoutDecoder) throws -> LayoutItem,
                encode: ((LayoutItem, LayoutEncoder) throws -> LayoutNode?)? = nil)
}

public protocol LayoutTemplateStore {
    func save(_ descriptor: LayoutTemplateDescriptor, body: Data) throws
    func load(key: String, language: String?) throws -> Data
    func list(documentType: String?) throws -> [LayoutTemplateDescriptor]
    func delete(key: String, language: String?) throws
}
```

`FileLayoutTemplateStore` reads/writes `.layout.json` under a root directory (in
DLTemplateServer: `documentsPath/templates/layouts/`).

### Encoder direction

`decode` is the product; `encode` is the toolchain. Encode exists to:
1. **Seed defaults** — run the existing Swift DSL templates once and dump them, so
   shipped JSON templates are pixel-identical to today's compiled ones.
2. Provide the round-trip test harness (build in code → encode → decode → render
   both → compare HTML/PDF output).
3. Support duplicate-and-customize flows later.

### Extensibility (registry contract)

```swift
LayoutNodeRegistry.standard.register(SignatureBoxNode.self)          // nodeType "dl.signatureBox"
LayoutFragmentLibrary.standard.register("dl.legalEntityBlock", json)
```

Core node types are unprefixed (`text`, `vstack`, `table`); anything registered
from outside uses a reverse prefix (`dl.`, `pos.`). Decoding a template with an
unregistered type fails loudly, naming the type — never silently.

## 6. DualLinkDB entity (model 63 → 64)

New entity **`LayoutDocumentTemplate`**, parent `DocumentTemplate` (abstract, under
`RenderTemplate` — inherits `key`, `language`, `status`, `type`, `businessArea`,
payment-options fields):

- `layoutBody: String` — the JSON template body (Postgres `text`)
- `name: String` — display name
- `documentType: String` — `invoice`, `quotation`, `deliveryNote`, … (which
  provider/context it expects)
- `formatVersion: Integer 16`
- `subject: String?` — for the email path
- `paperSize: String?`

userInfo: follow existing conventions; **`DBSyncType = device`** (like
`ArchivedInvoice`) so client apps can render offline — template rows are small.
(`Versioned = false` like `EmailTemplate`.) Regenerate classes via
`build_model.sh`; roll model 64 through consumers with the usual process.

> Open point: `DocumentTemplate` parent is the recommendation; a direct
> `RenderTemplate` subclass only wins if these layouts later also cover
> emails/tickets as a separate branch.

## 7. DLDocumentKit

New SPM package at `~/Projects/Libs/DLDocumentKit`.
Dependencies: **MIOLayoutKit + DualLinkDB only** — must build for iOS/macOS/Linux
so non-server apps (e.g. POS) can use it.

```swift
public struct DocumentEnvironment {
    public let moc: NSManagedObjectContext   // EntityContext.moc on server; app moc on device
    public let language: String
    public let locale: Locale
    public let resourcesPath: String?        // fonts for PDFRender
}

open class EntityDataProvider: LayoutDataProvider {
    public init(object: NSManagedObject, env: DocumentEnvironment)
    // Default path resolution: value(forKeyPath:) + NSAttributeDescription-driven
    // formatting (Date → locale date string; money Decimal → currency string using
    // the Company's currency; relationships descend into child providers).
    // Subclasses override only computed paths.
}

public final class InvoiceDataProvider: EntityDataProvider {
    // computed: "doc.sections" (lines grouped by categoryPath), "doc.taxLines",
    // "doc.totalAmount", ... — ported from sales_invoice_template_data.
    // + static sample(env:) provider for preview/validate.
}
```

- Company info comes from the `Company` entity in the `moc` (replaces the
  server-only `DLDB.shared.getTemplateCompanyInfo`).
- `DBLayoutTemplateStore: LayoutTemplateStore` over `LayoutDocumentTemplate`.
- `DocumentRenderer.render(templateKey:entityID:format:env:) -> Data` — load body
  from a store → decode with the document type's provider → `HTMLRender` /
  `PDFRender` (A4 margins + pagination for PDF, same as `render_layout` today).
- Email sending stays server-side; on apps the outputs are share/print/AirPrint.
  Future win: POS printer templates ride the same serialized format.

## 8. DLTemplateServer integration

New routes under the existing `/schema/:scheme` namespacing (existing compiled
templates keep working; migration is additive, template by template):

| Route | Verb | Purpose |
|---|---|---|
| `.../layout-template/:key` | POST/PUT | save/update template body → DB store |
| `.../layout-template/:key` | GET | fetch body (editor round-trip) |
| `.../layout-templates` | GET | list descriptors |
| `.../layout-template/validate` | POST | decode against the sample provider; report every unresolved path / bad node before saving |
| `.../layout-template/render/:key/:entity_type/:entity_id/:format?` | GET | render via DocumentRenderer (html/pdf) |
| `.../layout-template/send/:key/:entity_type/:entity_id` | GET/POST | render + email via existing SwiftSMTP path (async/sync like current email routes) |

Validation note: pull-based lazy resolution means a bad path only fails when hit —
the validate endpoint restores up-front safety by decoding with the sample
provider and collecting all unresolved paths.

Limits for tenant-supplied bodies (enforced in validate + save): node count cap,
image size cap, body size cap.

## 9. Build order

1. **Phase 0** — rename to MIOLayoutKit; update DLTemplateServer + POSShared; both build.
2. **Phase 1** — `Serialization/` in MIOLayoutKit: `LayoutNode`, encoder, decoder,
   registry, fragments, `LayoutDataProvider` + `DictionaryDataProvider`,
   round-trip tests. (Bulk of the design risk.)
3. **Phase 2** — `FileLayoutTemplateStore` + a hidden render route in
   DLTemplateServer to exercise end-to-end early.
4. **Phase 3** — DualLinkDB model 64: `LayoutDocumentTemplate` (sync type: device).
5. **Phase 4** — DLDocumentKit: `EntityDataProvider`, `InvoiceDataProvider` first
   (parity test vs. existing compiled invoice), `DBLayoutTemplateStore`,
   `DocumentRenderer`. Quotation second.
6. **Phase 5** — DLTemplateServer routes + seed default templates by encoding the
   existing Swift layouts.

## 10. Open decisions

- Authoring story: hand-edited JSON (validate endpoint + good decode errors are
  enough) vs. planned visual editor in the manager web app (publish a JSON-Schema,
  design preview endpoints for editor round-trips) vs. tenant self-service
  (editor + hard resource limits up front).
- Provider roster after invoice + quotation: delivery/stock notes, receipts/tickets.

## 11. Risks & gotchas

- **Expressiveness ceiling is intentional** — resist adding logic to the grammar;
  grow provider fields instead.
- Images: URL/asset refs only; `PDFRender` already fetches & caches URLs.
- Localization: `localizedText` nodes ride the existing `translations` mechanism.
- Model 64 rollout must be coordinated with other queued datamodel changes.
- `BookingTemplate.swift` in DLTemplateServer is fully commented out while routes
  still reference booking data functions — confirm those resolve elsewhere
  (unrelated to this design, noticed during exploration).
