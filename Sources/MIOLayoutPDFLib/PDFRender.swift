//
//  PDFRender.swift
//
//  Created by Jorge Barbero on 13/6/23.
//

#if PDFLib && canImport(PDFLib_Swift)
/// The PDF renderer of this module. MIOLayoutCoreGraphics declares the same name on iOS.
public typealias PDFRender = PDFRender_PDFLib
#endif
