import Foundation
import ImageIO

struct ImageMetadata: Equatable {
    let sections: [MetadataSection]

    var isEmpty: Bool {
        sections.isEmpty
    }
}

struct MetadataSection: Identifiable, Equatable {
    let title: String
    let items: [MetadataItem]

    var id: String { title }
}

struct MetadataItem: Equatable {
    let key: String
    let value: String
}

enum ImageMetadataLoader {
    static func load(from url: URL) -> ImageMetadata {
        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else {
            return ImageMetadata(sections: [])
        }

        var sections: [MetadataSection] = []

        if let exifSection = makeEXIFSection(properties: properties) {
            sections.append(exifSection)
        }

        if let iptc = properties[kCGImagePropertyIPTCDictionary] as? [CFString: Any],
           let section = makeSection(title: "IPTC", dictionary: iptc, preferredKeys: [
                kCGImagePropertyIPTCObjectName,
                kCGImagePropertyIPTCCaptionAbstract,
                kCGImagePropertyIPTCByline,
                kCGImagePropertyIPTCCopyrightNotice,
                kCGImagePropertyIPTCKeywords,
                kCGImagePropertyIPTCCity,
                kCGImagePropertyIPTCSubLocation,
                kCGImagePropertyIPTCProvinceState,
                kCGImagePropertyIPTCCountryPrimaryLocationName
           ]) {
            sections.append(section)
        }

        if let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any],
           let section = makeGPSSection(dictionary: gps) {
            sections.append(section)
        }

        if let xmpSection = makeXMPSection(source: source) {
            sections.append(xmpSection)
        }

        return ImageMetadata(sections: sections)
    }

    private static func makeEXIFSection(properties: [CFString: Any]) -> MetadataSection? {
        var combined: [CFString: Any] = [:]

        if let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
            combined.merge(tiff) { current, _ in current }
        }

        if let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            combined.merge(exif) { current, _ in current }
        }

        if let exifAux = properties[kCGImagePropertyExifAuxDictionary] as? [CFString: Any] {
            combined.merge(exifAux) { current, _ in current }
        }

        guard !combined.isEmpty else { return nil }

        return makeSection(title: "EXIF", dictionary: combined, preferredKeys: [
            kCGImagePropertyTIFFMake,
            kCGImagePropertyTIFFModel,
            kCGImagePropertyTIFFSoftware,
            kCGImagePropertyExifDateTimeOriginal,
            kCGImagePropertyExifExposureTime,
            kCGImagePropertyExifFNumber,
            kCGImagePropertyExifISOSpeedRatings,
            kCGImagePropertyExifFocalLength,
            kCGImagePropertyExifLensModel,
            kCGImagePropertyExifPixelXDimension,
            kCGImagePropertyExifPixelYDimension
        ])
    }

    private static func makeGPSSection(dictionary: [CFString: Any]) -> MetadataSection? {
        var items: [MetadataItem] = []
        var consumed = Set<CFString>()

        if
            let latitude = dictionary[kCGImagePropertyGPSLatitude] as? NSNumber,
            let latitudeRef = stringValue(dictionary[kCGImagePropertyGPSLatitudeRef]),
            let longitude = dictionary[kCGImagePropertyGPSLongitude] as? NSNumber,
            let longitudeRef = stringValue(dictionary[kCGImagePropertyGPSLongitudeRef])
        {
            items.append(MetadataItem(key: "Coordinates", value: "\(formatCoordinate(latitude.doubleValue, ref: latitudeRef)), \(formatCoordinate(longitude.doubleValue, ref: longitudeRef))"))
            consumed.formUnion([
                kCGImagePropertyGPSLatitude,
                kCGImagePropertyGPSLatitudeRef,
                kCGImagePropertyGPSLongitude,
                kCGImagePropertyGPSLongitudeRef
            ])
        }

        if let altitude = dictionary[kCGImagePropertyGPSAltitude] {
            items.append(MetadataItem(key: displayName(for: kCGImagePropertyGPSAltitude), value: formattedValue(altitude)))
            consumed.insert(kCGImagePropertyGPSAltitude)
        }

        if let dateStamp = stringValue(dictionary[kCGImagePropertyGPSDateStamp]) {
            let timeStamp = stringValue(dictionary[kCGImagePropertyGPSTimeStamp]).map { " \($0)" } ?? ""
            items.append(MetadataItem(key: "Timestamp", value: dateStamp + timeStamp))
            consumed.formUnion([kCGImagePropertyGPSDateStamp, kCGImagePropertyGPSTimeStamp])
        }

        let remainder = remainingItems(in: dictionary, excluding: consumed)
        items.append(contentsOf: remainder)

        return items.isEmpty ? nil : MetadataSection(title: "GPS", items: items)
    }

    private static func makeXMPSection(source: CGImageSource) -> MetadataSection? {
        guard
            let metadata = CGImageSourceCopyMetadataAtIndex(source, 0, nil),
            let tags = CGImageMetadataCopyTags(metadata) as? [CGImageMetadataTag]
        else {
            return nil
        }

        let items = tags.compactMap { tag -> MetadataItem? in
            guard
                let name = CGImageMetadataTagCopyName(tag) as String?,
                let value = CGImageMetadataTagCopyValue(tag)
            else {
                return nil
            }

            let prefix = (CGImageMetadataTagCopyPrefix(tag) as String?)?.lowercased()
            let namespace = (CGImageMetadataTagCopyNamespace(tag) as String?)?.lowercased()
            let keyPrefix = prefix?.isEmpty == false ? prefix! : namespace
            let key = keyPrefix.map { "\($0):\(name)" } ?? name

            return MetadataItem(key: key, value: formattedValue(value))
        }
        .sorted { lhs, rhs in
            lhs.key.localizedCaseInsensitiveCompare(rhs.key) == .orderedAscending
        }

        return items.isEmpty ? nil : MetadataSection(title: "XMP", items: items)
    }

    private static func makeSection(
        title: String,
        dictionary: [CFString: Any],
        preferredKeys: [CFString]
    ) -> MetadataSection? {
        var items: [MetadataItem] = []
        var consumed = Set<CFString>()

        for key in preferredKeys {
            guard let value = dictionary[key] else { continue }

            items.append(MetadataItem(
                key: displayName(for: key),
                value: formattedValue(value)
            ))
            consumed.insert(key)
        }

        items.append(contentsOf: remainingItems(in: dictionary, excluding: consumed))
        return items.isEmpty ? nil : MetadataSection(title: title, items: items)
    }

    private static func remainingItems(in dictionary: [CFString: Any], excluding excludedKeys: Set<CFString>) -> [MetadataItem] {
        dictionary
            .filter { !excludedKeys.contains($0.key) }
            .map { key, value in
                MetadataItem(key: displayName(for: key), value: formattedValue(value))
            }
            .sorted { lhs, rhs in
                lhs.key.localizedCaseInsensitiveCompare(rhs.key) == .orderedAscending
            }
    }

    private static func displayName(for key: CFString) -> String {
        let rawKey = key as String

        let knownNames: [String: String] = [
            kCGImagePropertyTIFFMake as String: "Camera Make",
            kCGImagePropertyTIFFModel as String: "Camera Model",
            kCGImagePropertyTIFFSoftware as String: "Software",
            kCGImagePropertyExifDateTimeOriginal as String: "Date Taken",
            kCGImagePropertyExifExposureTime as String: "Exposure",
            kCGImagePropertyExifFNumber as String: "Aperture",
            kCGImagePropertyExifISOSpeedRatings as String: "ISO",
            kCGImagePropertyExifFocalLength as String: "Focal Length",
            kCGImagePropertyExifLensModel as String: "Lens",
            kCGImagePropertyExifPixelXDimension as String: "Width",
            kCGImagePropertyExifPixelYDimension as String: "Height",
            kCGImagePropertyIPTCObjectName as String: "Title",
            kCGImagePropertyIPTCCaptionAbstract as String: "Description",
            kCGImagePropertyIPTCByline as String: "Author",
            kCGImagePropertyIPTCCopyrightNotice as String: "Copyright",
            kCGImagePropertyIPTCKeywords as String: "Keywords",
            kCGImagePropertyIPTCCity as String: "City",
            kCGImagePropertyIPTCSubLocation as String: "Location",
            kCGImagePropertyIPTCProvinceState as String: "State",
            kCGImagePropertyIPTCCountryPrimaryLocationName as String: "Country",
            kCGImagePropertyGPSAltitude as String: "Altitude",
            kCGImagePropertyGPSDateStamp as String: "Date",
            kCGImagePropertyGPSTimeStamp as String: "Time"
        ]

        if let knownName = knownNames[rawKey] {
            return knownName
        }

        let trimmed = rawKey
            .replacingOccurrences(of: "{", with: "")
            .replacingOccurrences(of: "}", with: "")
            .split(separator: ":")
            .last
            .map(String.init) ?? rawKey

        return separatedWords(from: trimmed)
    }

    private static func separatedWords(from rawKey: String) -> String {
        let withSpaces = rawKey.unicodeScalars.reduce(into: "") { partial, scalar in
            let character = Character(scalar)
            if scalar.properties.isUppercase, !partial.isEmpty {
                partial.append(" ")
            }
            partial.append(character)
        }

        return withSpaces.replacingOccurrences(of: "_", with: " ")
    }

    private static func formattedValue(_ value: Any) -> String {
        switch value {
        case let number as NSNumber:
            return formattedNumber(number)
        case let string as String:
            return string
        case let values as [Any]:
            return values.map(formattedValue).joined(separator: ", ")
        case let dictionary as [CFString: Any]:
            return dictionary
                .sorted { ($0.key as String) < ($1.key as String) }
                .map { "\(displayName(for: $0.key)): \(formattedValue($0.value))" }
                .joined(separator: ", ")
        case let dictionary as [String: Any]:
            return dictionary
                .sorted { $0.key < $1.key }
                .map { "\(separatedWords(from: $0.key)): \(formattedValue($0.value))" }
                .joined(separator: ", ")
        default:
            return String(describing: value)
        }
    }

    private static func formattedNumber(_ number: NSNumber) -> String {
        if CFGetTypeID(number) == CFBooleanGetTypeID() {
            return number.boolValue ? "Yes" : "No"
        }

        if number.doubleValue.rounded() == number.doubleValue {
            return String(Int(number.doubleValue))
        }

        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 4
        formatter.minimumFractionDigits = 0
        formatter.minimumIntegerDigits = 1
        return formatter.string(from: number) ?? number.stringValue
    }

    private static func stringValue(_ value: Any?) -> String? {
        guard let value else { return nil }
        let string = formattedValue(value)
        return string.isEmpty ? nil : string
    }

    private static func formatCoordinate(_ value: Double, ref: String) -> String {
        String(format: "%.6f° %@", value, ref)
    }
}
