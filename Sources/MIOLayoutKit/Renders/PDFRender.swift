//
//  PDFRender.swift
//  
//
//  Created by Jorge Barbero on 13/6/23.
//

import Foundation

#if os(iOS)
public typealias PDFRender = PDFRender_CoreGraphics
#else
public typealias PDFRender = PDFRender_PDFLib
#endif
