/*╔══════════════════════════════════════════════════════════════════════════════════════════════════╗
  ║ Satellite.swift                                                                           SatKit ║
  ║ Created by Gavin Eadie on Sep07/15 ... Copyright 2015-24 Ramsay Consulting. All rights reserved. ║
  ║──────────────────────────────────────────────────────────────────────────────────────────────────║
  ╚══════════════════════════════════════════════════════════════════════════════════════════════════╝*/

// swiftlint:disable identifier_name

import Foundation

public struct Satellite {

    private let propagator: Propagator

    public let tle: Elements                            // make TLE accessible
    public let commonName: String                       // "COSMOS .."
    public let noradIdent: String                       // "21332"
    public let t₀Days1950: Double                       // days since 1950

    public var e: Double { return propagator.e }        //### these vary slowly over time ..
    public var i: Double { return propagator.i }        //###
    public var ω: Double { return propagator.ω }        //###
    public var Ω: Double { return propagator.Ω }        //###

    public var extraInfo = [String: AnyObject]()

}

public extension Satellite {
/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │  Initialize Satellite with TLE struct ..                                                         │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    init(withTLE elements: Elements) {
        self.propagator = selectPropagator(tle: elements)

        self.tle = elements

        self.commonName = propagator.tle.commonName.isEmpty ? propagator.tle.launchName : propagator.tle.commonName
        self.noradIdent = String(propagator.tle.noradIndex)      // convert UInt to String
        self.t₀Days1950 = propagator.tle.t₀
    }

    init(elements: Elements) {
        self.propagator = selectPropagator(tle: elements)

        self.tle = elements

        self.commonName = propagator.tle.commonName.isEmpty ? propagator.tle.launchName : propagator.tle.commonName
        self.noradIdent = String(propagator.tle.noradIndex)      // convert UInt to String
        self.t₀Days1950 = propagator.tle.t₀
    }

/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │  Initialize Satellite with the three lines of a three line element set                           │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    init(_ line0: String, _ line1: String, _ line2: String) {
        do {
            let elements = try Elements(line0, line1, line2)
            self.init(withTLE: elements)
        } catch {
            fatalError("Satellite.init failure ..")
        }
    }

}

public extension Satellite {
    
    /// calculates the JD of  an offet (in minutes) from TLE epoch
    /// - Parameter minsAfterEpoch: minutes since `Satellite` epoch
    /// - Returns: the Julian date
    func julianDay(_ minsAfterEpoch: Double) -> Double {
        (t₀Days1950 + JD.epoch1950) + minsAfterEpoch * TimeConstants.min2day
    }

    func minsAfterEpoch(_ julianDays: Double) -> Double {
        (julianDays - (t₀Days1950 + JD.epoch1950)) * TimeConstants.day2min
    }

    var daysAfterEpoch: Double {
        return (ep1950DaysNow() - t₀Days1950)
    }

    var hoursAfterEpoch: Double {
        return (ep1950DaysNow() - t₀Days1950) * TimeConstants.day2hrs
    }

    var minsAfterEpoch: Double {
        return (ep1950DaysNow() - t₀Days1950) * TimeConstants.day2min
    }

}

public extension Satellite {

// MARK: - inertial position and velocity

/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ return satellite's earth centered inertial position (Kilometers) at minutes after TLE epoch      │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    func position(minsAfterEpoch: Double) throws -> Vector {
        let pv = try propagator.getPVCoordinates(minsAfterEpoch: minsAfterEpoch)
        return Vector((pv.position.x)/1000.0,
                      (pv.position.y)/1000.0,
                      (pv.position.z)/1000.0)
    }

/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ return satellite's earth centered inertial velocity (Kms/second) at minutes after TLE epoch      │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    func velocity(minsAfterEpoch: Double) throws -> Vector {
        let pv = try propagator.getPVCoordinates(minsAfterEpoch: minsAfterEpoch)
        return Vector((pv.velocity.x)/1000.0,
                      (pv.velocity.y)/1000.0,
                      (pv.velocity.z)/1000.0)
    }

/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ return satellite's earth centered inertial position (Kilometers) at Julian Date                  │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    func position(julianDays: Double) throws -> Vector {
        try position(minsAfterEpoch: minsAfterEpoch(julianDays))
    }

/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ return satellite's earth centered inertial velocity (Kms/second) at Julian Date                  │
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    func velocity(julianDays: Double) throws -> Vector {
        try velocity(minsAfterEpoch: minsAfterEpoch(julianDays))
    }

}

public extension Satellite {

// MARK: - latitude, longitude and altitude

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃  derive latitude, longitude and altitude at given time ..                                        ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
    func geoPosition(minsAfterEpoch: Double) throws -> LatLonAlt {
        return try geoPosition(julianDays: julianDay(minsAfterEpoch))
    }

    func geoPosition(julianDays: Double) throws -> LatLonAlt {
        return try eci2geo(julianDays: julianDays, celestial: position(julianDays: julianDays))
    }

// MARK: - azimuth, elevation and range

/*┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃  return topological position (satellite's azimuth, elevation and range) at given time ..         ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛*/
   func topPosition(minsAfterEpoch: Double, obsLatLonAlt: LatLonAlt) throws -> AziEleDst {
       try topPosition(julianDays: minsAfterEpoch * TimeConstants.min2day +
                                               (self.t₀Days1950 + JD.epoch1950), observer: obsLatLonAlt)
   }

   func topPosition(julianDays: Double, observer: LatLonAlt) throws -> AziEleDst {

       let satCel = try self.position(julianDays: julianDays)                  // ECI
       let obsCel = geo2eci(julianDays: julianDays, geodetic: observer)    // ECI

       let top = cel2top(julianDays: julianDays, satCel: satCel, obsCel: obsCel)

       let z = top.magnitude()

       return AziEleDst(atan2pi(top.y, -top.x) * rad2deg,
                        asin(top.z / z) * rad2deg,
                        z)
   }

}

public extension Satellite {

/*┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
  └──────────────────────────────────────────────────────────────────────────────────────────────────┘*/
    @available(*, deprecated, message: "PrettyPrint the elements from the Elements struct")
    func debugDescription() -> String {
        return tle.debugDescription()
    }

}
