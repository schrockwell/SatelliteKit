/*╔══════════════════════════════════════════════════════════════════════════════════════════════════╗
  ║ Elements.swift                                                                            SatKit ║
  ║ Created by Gavin Eadie on May24/17         Copyright © 2017-20 Gavin Eadie. All rights reserved. ║
  ║──────────────────────────────────────────────────────────────────────────────────────────────────║
  ╚══════════════════════════════════════════════════════════════════════════════════════════════════╝*/

import Foundation

// swiftlint:disable force_try
// swiftlint:disable identifier_name
// swiftlint:disable function_body_length

@available(*, deprecated, renamed: "Elements")
public typealias TLE = Elements

enum SatKitError: Error {
    case TLE(String)
    case SGP(String)
}

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ The TLE struct .. Decodable for JSON usage ..                                                    ┃
  ┃                                                                                                  ┃
  ┃                                                               MemoryLayout<TLE>.size = 200 bytes ┃
  ┃                                                                                                  ┃
  ┃ Information derived directly from the Two Line Elements ..                                       ┃
  ┃                                          .. then un'Kozai'd for mean motion and semi major axis. ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
public struct Elements: Codable {

    public let commonName: String                       // line zero name (if any) [eg: ISS (ZARYA)]
    public let noradIndex: UInt                         // The satellite number [eg: 25544]
    public let launchName: String                       // International designation [eg: 1998-067A]

    public let t₀: Double                               // the TLE t=0 time (days from 1950)
    public let e₀: Double                               // TLE .. eccentricity
    public let i₀: Double                               // TLE .. inclination (rad).
    public let ω₀: Double                               // Argument of perigee (rad).
    public let Ω₀: Double                               // Right Ascension of the Ascending node (rad).
    public let M₀: Double                               // Mean anomaly (rad).
    public var n₀: Double = 0.0                         // Mean motion (rads/min)  << [un'Kozai'd]
    public var a₀: Double = 0.0                         // semi-major axis (Eᵣ)    << [un'Kozai'd]

    public let ephemType: Int                           // Type of ephemeris.
    public let tleClass: String                         // Classification (U for unclassified).
    public let tleNumber: Int                           // Element number.
    public let revNumber: Int                           // Revolution number at epoch.

    internal let dragCoeff: Double                      // Ballistic coefficient.
    internal var n₀ʹ: Double = 0.0                      // Kozai version (keep for re-encoding

}

//MARK: - elements initializer

public extension Elements {

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
    init(commonName: String, noradIndex: UInt, launchName: String,
         t₀: Date, e₀: Double, i₀: Double, ω₀: Double, Ω₀: Double, M₀: Double, n₀: Double,
         ephemType: Int, tleClass: String, tleNumber: Int, revNumber: Int, dragCoeff: Double) {

        self.commonName = commonName
        self.noradIndex = noradIndex
        self.launchName = launchName
        self.t₀ = t₀.daysSince1950
        self.e₀ = e₀
        self.i₀ = i₀ * deg2rad
        self.ω₀ = ω₀ * deg2rad
        self.Ω₀ = Ω₀ * deg2rad
        self.M₀ = M₀ * deg2rad
        self.ephemType = ephemType
        self.tleClass = tleClass
        self.tleNumber = tleNumber
        self.revNumber = revNumber
        self.dragCoeff = dragCoeff

        unKozai(n₀ * (π/720.0))

    }
}

//MARK: - three line initializer

public extension Elements {

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ generate one TLE (this struct) from the three lines of element info ..                           ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
    init(_ line0: String, _ line1: String, _ line2: String) throws {

/*╭╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╮
  ┆                                                                                                  ┆
  ┆ 0         1         2         3         4         5         6         7                          ┆
  ┆ 01234567890123456789012345678901234567890123456789012345678901234567890                          ┆
  ┆                                                                                                  ┆
  ┆                                                                                                  ┆
  ┆ AAAAAAAAAAAAAAAAAAAAAAAA                                                                         ┆
  ┆ ISS (ZARYA)                                                           optional leading "0 "      ┆
  ┆ ------------------------                                              < 24 char name             ┆
  ╰╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╯*/

        commonName = line0.hasPrefix("0 ") ? String(line0.dropFirst().dropFirst()) : line0

/*╭╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╮
  ┆ 1 NNNNNU NNNNNAAA NNNNN.NNNNNNNN ±.NNNNNNNN ±NNNNN-N ±NNNNN-N N NNNNN                            ┆
  ┆ 1 25544U 98067A   08246.53160505  .00005208  00000-0  43781-4 0  1753                            ┆
  ┆ 1 25544U 98067A   08246.53160505  .00005208 .00000-0 .43781-4 0  1753   [zero index]             ┆
  ┆   -----                                                               < [02-06] satellite #      ┆
  ┆        U                                                              < [   07] classification   ┆
  ┆          .-                                                           < [09-10] ID (year)        ┆
  ┆            ---                                                        < [11-13] ID (launch #)    ┆
  ┆               ---                                                     < [14-16] ID (fragment)    ┆
  ┆                   --                                                  < [18-19] epoch year       ┆
  ┆                     ------------                                      < [20-31] epoch day        ┆
  ┆                                  ----------           [not used SGP4] < [33-42] Mean Motion/s    ┆
  ┆                                             .-----    [not used SGP4] < [44-                     ┆
  ┆                                                   --  [not used SGP4] <    -51] Mean Motion/s/s  ┆
  ┆                                                      .-----           < [53-                     ┆
  ┆                                                            --         < [  -60] BSTAR drag term  ┆
  ┆                                                               -       < [   62] ephemeris type   ┆
  ┆                                                                 ----  < [64-67] element number   ┆
  ┆                                                                     - < [   68] checksum         ┆
  ╰╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╯*/

        let lineOneBytes: [UInt8] = Array(line1.utf8)

        var stringlet = String(bytes: lineOneBytes[2...6], encoding: .utf8)!
        self.noradIndex = alpha5ID(stringlet.trimmingCharacters(in: .whitespaces))

        self.tleClass = String(bytes: lineOneBytes[7...7], encoding: .utf8)!

        stringlet = String(bytes: lineOneBytes[9...10], encoding: .utf8)!
        let launchYear = Int(stringlet) ?? 56                               // fails to year 2056

        stringlet = String(bytes: lineOneBytes[11...16], encoding: .utf8)!
        let launchPart = stringlet.trimmingCharacters(in: .whitespaces)

        self.launchName = "\(launchYear < 57 ? 2000 : 1900 + launchYear)-" + launchPart

        stringlet = String(bytes: lineOneBytes[18...19], encoding: .utf8)!
        let epochYear = Int(stringlet)!

        stringlet = String(bytes: lineOneBytes[20...31], encoding: .utf8)!
        self.t₀ = epochDays(year: (epochYear < 57 ? 2000 : 1900) + epochYear, days: Double(stringlet)!)

        stringlet = (lineOneBytes[53] == 32 ||
                     lineOneBytes[53] == 43 ? "+" : "-") + "." +
                    String(bytes: lineOneBytes[54...54], encoding: .utf8)! +
                    String(bytes: lineOneBytes[55...58], encoding: .utf8)! + "e" +
                    String(bytes: lineOneBytes[59...60], encoding: .utf8)!
        self.dragCoeff = Double(stringlet)!

        stringlet = String(bytes: lineOneBytes[62...62], encoding: .utf8)!
        self.ephemType = Int(stringlet) ?? 0

        stringlet = String(bytes: lineOneBytes[64...67], encoding: .utf8)!
        self.tleNumber = Int(stringlet.trimmingCharacters(in: .whitespaces))!

/*╭╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╮
  ┆ 2 NNNNN NNN.NNNN NNN.NNNN NNNNNNN NNN.NNNN NNN.NNNN NN.NNNNNNNNNNNNNN                            ┆
  ┆ 2 25544  51.6437 339.5511 0006673  73.4733  44.7326 15.71870125560705                            ┆
  ┆ 2 25544  51.6437 339.5511.0006673  73.4733  44.7326 15.71870125560705   [zero index]             ┆
  ┆   -----                                                               < [02-06] satellite #      ┆
  ┆         --------                                                      < [08-15] inclination      ┆
  ┆                  --------                                             < [17-24] RAAN             ┆
  ┆                          .-------                                     < [26-32] eccentricity     ┆
  ┆                                   --------                            < [34-41] Arg of Perigee   ┆
  ┆                                            --------                   < [43-50] Mean Anomaly     ┆
  ┆                                                     -----------       < [52-62] Mean Motion      ┆
  ┆                                                                -----  < [63-67] revolution #     ┆
  ┆                                                                     - < [   68] checksum         ┆
  ┆                                                                                                  ┆
  ┆ The reference frame of the Earth-centered inertial (ECI) coordinates produced by the SGP4/SDP4   ┆
  ┆ orbital model is true equator, mean equinox (TEME) of epoch.                                     ┆
  ╰╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╯*/

        let lineTwoBytes: [UInt8] = Array(line2.utf8)

        stringlet = String(bytes: lineTwoBytes[2...6], encoding: .utf8)!
        guard self.noradIndex == alpha5ID(stringlet.trimmingCharacters(in: .whitespaces)) else {
            throw SatKitError.TLE("Line1 and Line2 NORAD IDs don't match ..")
        }

        stringlet = String(bytes: lineTwoBytes[8...15], encoding: .utf8)!
        self.i₀ = Double(stringlet.trimmingCharacters(in: .whitespaces))! * deg2rad

        stringlet = String(bytes: lineTwoBytes[17...24], encoding: .utf8)!
        self.Ω₀ = Double(stringlet.trimmingCharacters(in: .whitespaces))! * deg2rad

        stringlet = "." + String(bytes: lineTwoBytes[26...32], encoding: .utf8)!
        self.e₀ = Double(stringlet.replacingOccurrences(of: " ", with: "0"))!

        stringlet = String(bytes: lineTwoBytes[34...41], encoding: .utf8)!
        self.ω₀ = Double(stringlet.trimmingCharacters(in: .whitespaces))! * deg2rad

        stringlet = String(bytes: lineTwoBytes[43...50], encoding: .utf8)!
        self.M₀ = Double(stringlet.trimmingCharacters(in: .whitespaces))! * deg2rad

        stringlet = String(bytes: lineTwoBytes[52...62], encoding: .utf8)!
        self.n₀ʹ = Double(stringlet.trimmingCharacters(in: .whitespaces))!

        stringlet = String(bytes: lineTwoBytes[63...67], encoding: .utf8)!
        self.revNumber = Int(stringlet.trimmingCharacters(in: .whitespaces))!

        unKozai(self.n₀ʹ * (π/720.0))

        guard (self.ephemType == 0 || self.ephemType == 2 || self.ephemType == 3) else {
            throw SatKitError.TLE("Line1 ephemerisType ≠ 0, 2 or 3 .. [\(self.ephemType)]")
        }
    }
}

//MARK: - JSON initializer

public extension Elements {

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  │ Decoding one, or more, Elements from JSON requires a little work before the init ..              │
  │                                                                                                  │
  │ First, we need to create a JSON decoder and teach it how to decode ISO times with milliseconds   │
  │                                                                                                  │
  │     let jsonDecoder = JSONDecoder()                                                              │
  │     jsonDecoder.dateDecodingStrategy = .formatted(DateFormatter.iso8601Micros)                   │
  │                                                                                                  │
  │ Then, if JSON data in the form of a String, convert it to Data (catching any error)              │
  │                                                                                                  │
  │     guard let jsonData = jsonString.data(using: .utf8) else {                                    │
  │         throw Error("JSON failure converting String to Data ..")                                 │
  │     }                                                                                            │
  │                                                                                                  │
  │ Finally let the decoder do it's thing .. (again, catch errors if necessary)                      │
  │                                                                                                  │
  │     let elements = try jsonDecoder.decode(Elements.self, from: jsonData)                         │
  │                                                                                                  │
  │ or for an array of Elements                                                                      │
  │                                                                                                  │
  │     let ElementsArray = try jsonDecoder.decode([Elements].self, from: jsonData)                  │
  │                                                                                                  │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/

    private enum CodingKeys: String, CodingKey {
        case commonName = "OBJECT_NAME"
        case noradIndex = "NORAD_CAT_ID"
        case launchName = "OBJECT_ID"
        case t₀ = "EPOCH"
        case e₀ = "ECCENTRICITY"
        case i₀ = "INCLINATION"
        case ω₀ = "ARG_OF_PERICENTER"
        case Ω₀ = "RA_OF_ASC_NODE"
        case M₀ = "MEAN_ANOMALY"
        case n₀ = "MEAN_MOTION"
        case dragCoeff = "BSTAR"
        case ephemType = "EPHEMERIS_TYPE"
        case tleClass = "CLASSIFICATION_TYPE"
        case tleNumber = "ELEMENT_SET_NO"
        case revNumber = "REV_AT_EPOCH"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.commonName = try container.decode(String.self, forKey: .commonName)
        self.noradIndex = UInt(try container.decode(Int.self, forKey: .noradIndex))
        self.launchName = try container.decode(String.self, forKey: .launchName)
        self.t₀ = try container.decode(Date.self, forKey: .t₀).daysSince1950
        self.e₀ = try container.decode(Double.self, forKey: .e₀)
        self.i₀ = try container.decode(Double.self, forKey: .i₀) * deg2rad
        self.ω₀ = try container.decode(Double.self, forKey: .ω₀) * deg2rad
        self.Ω₀ = try container.decode(Double.self, forKey: .Ω₀) * deg2rad
        self.M₀ = try container.decode(Double.self, forKey: .M₀) * deg2rad
        self.n₀ = try container.decode(Double.self, forKey: .n₀)
        self.dragCoeff = try container.decode(Double.self, forKey: .dragCoeff)
        self.ephemType = try container.decode(Int.self, forKey: .ephemType)
        self.tleClass = try container.decode(String.self, forKey: .tleClass)
        self.tleNumber = try container.decode(Int.self, forKey: .tleNumber)
        self.revNumber = try container.decode(Int.self, forKey: .revNumber)
        
        n₀ʹ = n₀                                                // capture pre-Kozai n₀

        unKozai(try! container.decode(Double.self, forKey: .n₀) * (π/720.0))
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(commonName, forKey: .commonName)
        try container.encode(noradIndex, forKey: .noradIndex)
        try container.encode(launchName, forKey: .launchName)
        try container.encode(Date(daysSince1950: t₀), forKey: .t₀)
        try container.encode(e₀, forKey: .e₀)
        try container.encode(i₀ * rad2deg, forKey: .i₀)
        try container.encode(ω₀ * rad2deg, forKey: .ω₀)
        try container.encode(Ω₀ * rad2deg, forKey: .Ω₀)
        try container.encode(M₀ * rad2deg, forKey: .M₀)
        try container.encode(dragCoeff, forKey: .dragCoeff)
        try container.encode(ephemType, forKey: .ephemType)
        try container.encode(tleClass, forKey: .tleClass)
        try container.encode(tleNumber, forKey: .tleNumber)
        try container.encode(revNumber, forKey: .revNumber)
        try container.encode(self.n₀ʹ, forKey: .n₀)             // use the previously captured n₀ʹ
    }
}

//MARK: - XML initializer

public extension Elements {

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/

    init(xmlData: Data) {
        
        let parser = ElementsParser()
        parser.parseXML(xmlData)

        let satelliteInfo = parser.satInfoArray.first

        self.init(commonName: satelliteInfo!["OBJECT_NAME"]!,
                  noradIndex: UInt(satelliteInfo!["NORAD_CAT_ID"]!)!,
                  launchName: satelliteInfo!["OBJECT_ID"]!,
                  t₀: DateFormatter.iso8601Micros.date(from: satelliteInfo!["EPOCH"]!)!,
                  e₀: Double(satelliteInfo!["ECCENTRICITY"]!)!,
                  i₀: Double(satelliteInfo!["INCLINATION"]!)!,
                  ω₀: Double(satelliteInfo!["ARG_OF_PERICENTER"]!)!,
                  Ω₀: Double(satelliteInfo!["RA_OF_ASC_NODE"]!)!,
                  M₀: Double(satelliteInfo!["MEAN_ANOMALY"]!)!,
                  n₀: Double(satelliteInfo!["MEAN_MOTION"]!)!,
                  ephemType: Int(satelliteInfo!["EPHEMERIS_TYPE"]!)!,
                  tleClass: satelliteInfo!["CLASSIFICATION_TYPE"]!,
                  tleNumber: Int(satelliteInfo!["ELEMENT_SET_NO"]!)!,
                  revNumber: Int(satelliteInfo!["REV_AT_EPOCH"]!)!,
                  dragCoeff: Double(satelliteInfo!["BSTAR"]!)!)

        a₀ = 0.0
        n₀ʹ = 0.0

        unKozai(n₀ * (π/720.0))

    }
}

//MARK privates

extension Elements {
/*╭╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╮
  ┆ recover (un'Kozai) original mean motion and semi-major axis from the input elements for SxP4.    ┆
  ╰╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╯*/
    private mutating func unKozai(_ n₀ʹ: Double) {

        do {
            let θ = cos(self.i₀)                                    //         cos(i₀)  ..  θ
            let x3thm1 = 3.0 * θ * θ - 1.0                          //      3×cos²(i₀) - 1
            let β₀ = (1.0 - self.e₀ * self.e₀).squareRoot()         //         √(1-e₀²) ..  β₀
            let temp = 1.5 * EarthConstants.K₂ * x3thm1 / (β₀ * β₀ * β₀)

            let a₀ʹ = pow(EarthConstants.kₑ / n₀ʹ, ⅔)
            let δ₁ = temp / (a₀ʹ * a₀ʹ)
            let a₁ = a₀ʹ * (1.0 - δ₁ * (⅓ + δ₁ * (1.0 + 134.0 / 81.0 * δ₁)))
            let δ₀ = temp / (a₁ * a₁)

            self.n₀ = n₀ʹ / (1.0 + δ₀)                               //             n₀
            self.a₀ = a₁  / (1.0 - δ₀)                               //             a₀
        }
    }
}

//MARK: - Pretty Printer

public extension Elements {

/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    func debugDescription() -> String {

        if (-Date(daysSince1950: t₀).timeIntervalSinceNow * TimeConstants.sec2day < 1.0) {
            return String(format: """

                ┌─[elements : %4.1f hours old]───────────────────────────────────────────
                │  %@    %05d = %@ rev#:%05d tle#:%04d
                │     t₀:  %@    %+14.8f days after 1950
                │
                │    inc: %8.4f°     aop: %8.4f°    mot:  %11.8f (rev/day)
                │   raan: %8.4f°    anom: %8.4f°    ecc:   %9.7f
                │                                        drag:  %+11.4e
                └───────────────────────────────────────────────────────────────────────
                """,
                          -Date(daysSince1950: t₀).timeIntervalSinceNow * TimeConstants.sec2day * 24.0,
                          self.commonName.padding(toLength: 24, withPad: " ", startingAt: 0),
                          self.noradIndex,
                          self.launchName.padding(toLength: 11, withPad: " ", startingAt: 0),
                          self.revNumber, self.tleNumber,
                          String(describing: Date(daysSince1950: self.t₀)), self.t₀,
                          self.i₀ * rad2deg, self.ω₀ * rad2deg, self.n₀ / (π/720.0), self.Ω₀ * rad2deg,
                          self.M₀ * rad2deg, self.e₀, self.dragCoeff)
        } else {
            return String(format: """

                ┌─[elements : %5.2f days old]───────────────────────────────────────────
                │  %@    %05d = %@ rev#:%05d tle#:%04d
                │     t₀:  %@    %+14.8f days after 1950
                │
                │    inc: %8.4f°     aop: %8.4f°    mot:  %11.8f (rev/day)
                │   raan: %8.4f°    anom: %8.4f°    ecc:   %9.7f
                │                                        drag:  %+11.4e
                └───────────────────────────────────────────────────────────────────────
                """,
                          -Date(daysSince1950: t₀).timeIntervalSinceNow * TimeConstants.sec2day,
                          self.commonName.padding(toLength: 24, withPad: " ", startingAt: 0),
                          self.noradIndex,
                          self.launchName.padding(toLength: 11, withPad: " ", startingAt: 0),
                          self.revNumber, self.tleNumber,
                          String(describing: Date(daysSince1950: self.t₀)), self.t₀,
                          self.i₀ * rad2deg, self.ω₀ * rad2deg, self.n₀ / (π/720.0), self.Ω₀ * rad2deg,
                          self.M₀ * rad2deg, self.e₀, self.dragCoeff)
        }
    }
}

//MARK: - static functions

/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  ┆ Convenience function .. converts the YYDDD.DDDDDDDD TLE epoch time to days since 1950 reference. ┆
  ╰╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╯*/
fileprivate func epochDays(year: Int, days: Double) -> Double {
    Double(year-1950)*365.0 + Double((year-1949)/4) + days
}

/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Do the checksum check on a TLE line ("0"..."9" are 0...9; "-" is 1; last digit is checksum).     │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
private func checkSumGood(_ tleLine: String) -> Bool {
    var     checkSum: UInt8 = 0
    let     bytes = [UInt8](tleLine.utf8)

    for arrayIndex in 0..<bytes.count-1 {
        let byte = bytes[arrayIndex]
        if 48...57 ~= byte { checkSum += (byte - 48) }      // "0"..."9" -> 0...9
        if byte == 45 { checkSum += 1 }                     //    "-"    ->   1
        checkSum %= 10
    }

    return checkSum == bytes[bytes.count-1] - 48
}

/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Check the lines format validity.                                                                 │
  │            Return true if lines are 69 characters long, format is valid, and checksums are good. │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
public func formatOK(_ line1: String, _ line2: String) -> Bool {

    guard line1.lengthOfBytes(using: .utf8) == 69 else {
        print("line1 length ≠ 69: '\(line1)'"); return false
    }
    guard line2.lengthOfBytes(using: .utf8) == 69 else {
        print("line2 length ≠ 69: '\(line2)'"); return false
    }

    let lineOneRegEx = try!
        NSRegularExpression(pattern:
            "1 [ 0-9]{5}[A-Z] [ 0-9]{5}[ A-Z]{3} [ 0-9]{5}[.][ 0-9]{8} (?:(?:[ 0+-][.][ 0-9]{8})|(?: " +
            "[ +-][.][ 0-9]{7})) [ +-][ 0-9]{5}[+-][ 0-9] [ +-][ 0-9]{5}[+-][ 0-9] [ 0-9] [ 0-9]{4}[ 0-9]",
                            options: .caseInsensitive)

    guard lineOneRegEx.numberOfMatches(in: line1,
                                       range: NSRange(location: 0, length: 69)) == 1 else {
        print("line1 format bad: '\(line1)'"); return false
    }

    let lineTwoRegEx = try!
        NSRegularExpression(pattern:
            "2 [ 0-9]{5} [ 0-9]{3}[.][ 0-9]{4} [ 0-9]{3}[.][ 0-9]{4} [ 0-9]{7} [ 0-9]{3}[.][ 0-9]{4} " +
            "[ 0-9]{3}[.][ 0-9]{4} [ 0-9]{2}[.][ 0-9]{13}[ 0-9]",
                            options: .caseInsensitive)

    guard lineTwoRegEx.numberOfMatches(in: line2,
                                       range: NSRange(location: 0, length: 69)) == 1 else {
        print("line2 format bad: '\(line2)'"); return false
    }

    guard checkSumGood(line1) else { print("line1 checksum fail: '\(line1)'"); return false }
    guard checkSumGood(line2) else { print("line2 checksum fail: '\(line2)'"); return false }

    return true
}

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃ This function takes a String that is possibly the lines from a TLE file.  It splits it into an   ┃
  ┃ array of Strings (hopefully, TLE records).  Records starting with "#" are dropped, leading and   ┃
  ┃ trailing whitespace is stripped, and non-breaking spaces are converted to regular spaces.        ┃
  ┃                                                                                                  ┃
  ┃ Then, with a presumably clean set of TLEs, the function searches for the first TLE-1 line with   ┃
  ┃ a good checksum.  If that is followed immediately by a good TLE-2, the line before the TLE-1 is  ┃
  ┃ assumed to be a TLE-0 (if not a TLE-2) regardless of content.  These three lines are used to     ┃
  ┃ make a tuple (TLE-0, TLE-1, TLE-2), and the tuple is added to the array of TLE tuples which is   ┃
  ┃ returned by the function.                                                                        ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
public func preProcessTLEs(_ elementsString: String) -> [(String, String, String)] {
    var tuplesArray = [(String, String, String)]()

/*╭╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╮
  ┆ make sure there is a last line ("#END"), split the String into an array of Strings at <return>   ┆
  ┆ and convert non-breaking spaces ..                                                               ┆
  ╰╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╯*/
    var stringArray = (elementsString + "\n#EOF").replacingOccurrences(of: "\r",
                                                          with: "").components(separatedBy: "\n")

    func trimWhitespace(string: String) -> String {
        return string.trimmingCharacters(in: CharacterSet.whitespaces)
                                                .replacingOccurrences(of: "\u{00A0}", with: " ")
    }

/*╭╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╮
  ┆ drop any blank lines or lines starting with "#" and trim whitespace                              ┆
  ╰╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╯*/
    stringArray = ([""] + stringArray.map(trimWhitespace)
                                   .filter { !$0.hasPrefix("#") && !$0.isEmpty })

/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ with a cleaned Array(String) look for TLEs based on the first characters of each line expecting  │
  │     0 ...           <- may be absent, may not have a "0"                                         │
  │     1  ...          <- 69 characters long, starting with "1" and good checksum                   │
  │     2    ...        <- 69 characters long, starting with "2" and good checksum                   │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    var index = 0
    while index < stringArray.count {
/*╭╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╮
  ┆ look for TLE-1  (loop till we find one)                                                          ┆
  ╰╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╯*/
		let tleLine1 = stringArray[index]
        index += 1
        guard (tleLine1.utf8).count == 69,
               tleLine1.hasPrefix("1"),
               checkSumGood(tleLine1) else { continue }         // keep looking for TLE-1

/*╭╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╮
  ┆ look for TLE-2 following TLE-1 (if absent, loop till we find a TLE-1)                            ┆
  ╰╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╯*/
		let tleLine2 = stringArray[index]
        index += 1
        guard (tleLine2.utf8).count == 69,
               tleLine2.hasPrefix("2"),
               checkSumGood(tleLine2) else { continue }         // look for another TLE-1

/*╭╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╮
  ┆ got TLE-1 followed by TLE-2, so check for TLE-0 (three lines back) with, or without, a leading   ┆
  ┆ "0" .. it's not computationally significant so, if it's not a TLE-2, make it TLE-0.              ┆
  ┆                                                                                                  ┆
  ┆ If it APPEARS to be a TLE-2 (starts with "2") it probably belongs to the previous satellite and  ┆
  ┆ we have a "two index" tle file (then, set TLE-0 to "") ..                                        ┆
  ╰╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╯*/
        let tleLine0 = stringArray[index-3]

        tuplesArray.append(((tleLine0.hasPrefix("2 ") ? "" : tleLine0), tleLine1, tleLine2))
    }

    return tuplesArray
}

func base10ID(_ noradID: String) -> Int {
    guard let value = Int(noradID) else { return 0 }
    return value
}

/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Convert new Aplha-5 NORAD ID ("B1234") into an integer .. "B" * 10000 + 1234, "B" is base-34 ..  │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
func alpha5ID(_ noradID: String) -> UInt {              //      "B1234"      "5"
	let lastFive = ("00000" + noradID.uppercased())     // "00000B1234  "000005"
											.suffix(5)  //      "B1234"  "00005"
	let byte1 = (lastFive.first)!
	if let seqNo = Int(lastFive.dropFirst()) {

		switch String(byte1) {
		case "0"..."9":
			return UInt(Int(byte1.asciiValue!-48)*10000 + seqNo)
		case "A"..."H":
			return UInt(Int(byte1.asciiValue!-55)*10000 + seqNo)
		case "J"..."N":
			return UInt(Int(byte1.asciiValue!-56)*10000 + seqNo)
		case "P"..."Z":
			return UInt(Int(byte1.asciiValue!-57)*10000 + seqNo)
		default:
			return 0
		}

	}

	return 0
}

private func stringFrom(_ line: [UInt8], range: ClosedRange<Int>) -> String {
    String(bytes: line[range], encoding: .utf8)!.trimmingCharacters(in: .whitespaces)
}
