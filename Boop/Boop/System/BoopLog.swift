//
//  BoopLog.swift
//  Boop
//
//  Shared diagnostic log handles. View with:
//  log stream --predicate 'subsystem == "com.OKatBest.Boop2"' --level debug
//

import Foundation
import os.log

enum BoopLog {
    static let subsystem = "com.OKatBest.Boop2"

    static let app = OSLog(subsystem: subsystem, category: "app")
    static let tabs = OSLog(subsystem: subsystem, category: "tabs")
    static let stats = OSLog(subsystem: subsystem, category: "stats")
    static let scripts = OSLog(subsystem: subsystem, category: "scripts")
}
