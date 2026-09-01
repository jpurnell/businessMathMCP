//
//  extensionFormatted.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/19/25.
//

import Foundation
import SwiftMCPServer

extension BinaryFloatingPoint {
	/// The value as a currency string, in the given ISO code.
	public func currency(_ currency: String = "usd") -> String {
		let code = currency.uppercased()
		let value = Double(self)
		
		if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *) {
				// Use modern FormatStyle on newer OSes
			return value.formatted(.currency(code: code).presentation(.narrow))
		} else {
				// Fallback for older OSes (iOS 14, macOS 11, etc.)
			let formatter = NumberFormatter()
			formatter.numberStyle = .currency
			formatter.currencyCode = code
				// NumberFormatter has no direct “narrow” presentation; this is a reasonable approximation.
			return formatter.string(from: NSNumber(value: value)) ?? String(value)
		}
	}
	
		/// Renders the value with a fixed number of fraction digits.
		///
		/// This replaces `String(format: "%.Nf", …)`, which bridges to the C
		/// `printf` ABI: argument types are checked only at runtime, and a
		/// specifier mismatch is a crash rather than a compile error.
		///
		/// The style deliberately pins the POSIX locale and disables grouping,
		/// because that is what `printf` did. Formatting with the *current*
		/// locale would emit `12,34` in much of the world and insert grouping
		/// separators into numbers that callers parse.
	func digits(_ digitCount: Int) -> String {
		let value = Double(self)
			// printf renders these as "nan" and "inf"; neither is a quantity, and
			// an MCP client reading a tool result cannot tell them from a figure.
		guard value.isFinite else { return Self.nonFiniteDescription }
		let places = max(0, digitCount)
		return value.formatted(
			.number
				.precision(.fractionLength(places))
				.grouping(.never)
				.locale(Locale(identifier: "en_US_POSIX"))
		)
	}

		/// Rendered in place of a value that is not a real number.
	static var nonFiniteDescription: String { "n/a" }

		/// Renders the value with a fixed number of fraction digits, followed by
		/// a percent sign. Replaces `String(format: "%.Nf%%", …)`.
	func percentDigits(_ digitCount: Int) -> String {
		let value = Double(self)
		guard value.isFinite else { return Self.nonFiniteDescription }
		return digits(digitCount) + "%"
	}
}
