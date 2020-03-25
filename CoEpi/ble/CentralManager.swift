//
//  CentralManager.swift
//  CoEpi
//
//  Created by Johnson Hsieh on 3/25/20.
//  Copyright © 2020 org.coepi. All rights reserved.
//

import CoreBluetooth
import os.log

protocol CentralManager: NSObject {
    var isScanning: Bool { get }
    var bluetoothState: BluetoothState { get }
    func scanForPeripherals(withServices serviceUUIDs: [String]?, allowDuplicates: Bool)
    func connect(_ peripheral: CBPeripheral, options: [String : Any]?)
    func cancelPeripheralConnection(_ peripheral: CBPeripheral)
    func stopScan()
}

extension CBCentralManager : CentralManager {
    var bluetoothState: BluetoothState {
        os_log("Central manager did update state: %d", log: bleCentralLog, state.rawValue)
        return BluetoothState(cbState: state)
    }

    func scanForPeripherals(withServices serviceUUIDs: [String]?, allowDuplicates: Bool) {
        let options = [CBCentralManagerScanOptionAllowDuplicatesKey : NSNumber(booleanLiteral: allowDuplicates)]
        scanForPeripherals(withServices: serviceUUIDs?.map { CBUUID(string: $0) }, options: options)
    }
}

enum BluetoothState {
    case active
    case inactive
    init(cbState: CBManagerState) {
        switch cbState {
        case .poweredOn:
            self = .active
        default:
            self = .inactive
        }
    }
}

protocol CentralManagerDelegateInterface {
    func didUpdateState(central: CentralManager)
    func didDiscover(central: CentralManager, peripheral: CBPeripheral, advertisementData: [String: Any], RSSI: NSNumber)
    func didConnect(central: CentralManager, peripheral: CBPeripheral)
}

class CentralManagerDelegate: CentralManagerDelegateInterface {
    let shim: CentralManagerShim
    init(didUpdateState: @escaping (_ central: CBCentralManager) -> (),
         didDiscover: @escaping(_ central: CBCentralManager, _ peripheral: CBPeripheral, _ advertisementData: [String: Any], _ RSSI: NSNumber) -> (),
         didConnect: @escaping(_ central: CBCentralManager, _ peripheral: CBPeripheral) -> ()) {
        shim = CentralManagerShim(didUpdateState: didUpdateState, didDiscover: didDiscover, didConnect: didConnect)
    }

    func didUpdateState(central: CentralManager) {
        shim.centralManagerDidUpdateState(central as! CBCentralManager)
    }
    func didDiscover(central: CentralManager, peripheral: CBPeripheral, advertisementData: [String : Any], RSSI: NSNumber) {
        shim.centralManager(central as! CBCentralManager, didDiscover: peripheral, advertisementData: advertisementData, rssi: RSSI)
    }
    func didConnect(central: CentralManager, peripheral: CBPeripheral) {
        shim.centralManager(central as! CBCentralManager, didConnect: peripheral)
    }
}

class CentralManagerShim: NSObject, CBCentralManagerDelegate {
    let didUpdateState: (_ central: CBCentralManager) -> ()
    let didDiscover: (_ central: CBCentralManager, _ peripheral: CBPeripheral, _ advertisementData: [String: Any], _ RSSI: NSNumber) -> ()
    let didConnect: (_ central: CBCentralManager, _ peripheral: CBPeripheral) -> ()
    init(didUpdateState: @escaping (_ central: CBCentralManager) -> (),
         didDiscover: @escaping(_ central: CBCentralManager, _ peripheral: CBPeripheral, _ advertisementData: [String: Any], _ RSSI: NSNumber) -> (),
         didConnect: @escaping(_ central: CBCentralManager, _ peripheral: CBPeripheral) -> ()) {
        self.didUpdateState = didUpdateState
        self.didDiscover = didDiscover
        self.didConnect = didConnect
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        didUpdateState(central)
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        didDiscover(central, peripheral, advertisementData, RSSI)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        didConnect(central, peripheral)
    }

}
