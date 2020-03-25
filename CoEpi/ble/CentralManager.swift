//
//  CentralManager.swift
//  CoEpi
//
//  Created by Johnson Hsieh on 3/25/20.
//  Copyright © 2020 org.coepi. All rights reserved.
//

import CoreBluetooth
import Foundation
import os.log

protocol CentralManager: NSObject {
    var isScanning: Bool { get }
    var bluetoothState: BluetoothState { get }
    func scanForPeripherals(withServices serviceUUIDs: [UUID]?, allowDuplicates: Bool)
    func connect(_ peripheral: Central.Peripheral, options: [String : Any]?)
    func cancelPeripheralConnection(_ peripheral: Central.Peripheral)
    func stopScan()
}

extension CBCentralManager : CentralManager {
    var bluetoothState: BluetoothState {
        os_log("Central manager did update state: %d", log: bleCentralLog, state.rawValue)
        return BluetoothState(cbState: state)
    }

    func scanForPeripherals(withServices serviceUUIDs: [UUID]?, allowDuplicates: Bool) {
        let options = [CBCentralManagerScanOptionAllowDuplicatesKey : NSNumber(booleanLiteral: allowDuplicates)]
        scanForPeripherals(withServices: serviceUUIDs?.map { CBUUID(nsuuid: $0) }, options: options)
    }

    func connect(_ peripheral: Central.Peripheral, options: [String : Any]?) {
        connect(peripheral.peripheral as! CBPeripheral, options: options)
    }

    func cancelPeripheralConnection(_ peripheral: Central.Peripheral) {
        cancelPeripheralConnection(peripheral.peripheral as! CBPeripheral)
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
    func didDiscover(central: CentralManager, peripheral: Central.Peripheral, advertisementData: [String: Any], RSSI: NSNumber)
    func didConnect(central: CentralManager, peripheral: Central.Peripheral)
}

class CentralManagerDelegate: CentralManagerDelegateInterface {
    private let shim: CentralManagerShim

    init(didUpdateState: @escaping (_ central: CBCentralManager) -> (),
         didDiscover: @escaping(_ central: CBCentralManager, _ peripheral: Central.Peripheral, _ advertisementData: [String: Any], _ RSSI: NSNumber) -> (),
         didConnect: @escaping(_ central: CBCentralManager, _ peripheral: Central.Peripheral) -> ()) {
        shim = CentralManagerShim(didUpdateState: didUpdateState, didDiscover: didDiscover, didConnect: didConnect)
    }

    func didUpdateState(central: CentralManager) {
        shim.centralManagerDidUpdateState(central as! CBCentralManager)
    }

    func didDiscover(central: CentralManager, peripheral: Central.Peripheral, advertisementData: [String : Any], RSSI: NSNumber) {
        shim.centralManager(central as! CBCentralManager, didDiscover: peripheral.peripheral as! CBPeripheral, advertisementData: advertisementData, rssi: RSSI)
    }

    func didConnect(central: CentralManager, peripheral: Central.Peripheral) {
        shim.centralManager(central as! CBCentralManager, didConnect: peripheral.peripheral as! CBPeripheral)
    }
}

class CentralManagerShim: NSObject, CBCentralManagerDelegate {
    private let didUpdateState: (_ central: CBCentralManager) -> ()
    private let didDiscover: (_ central: CBCentralManager, _ peripheral: Central.Peripheral, _ advertisementData: [String: Any], _ RSSI: NSNumber) -> ()
    private let didConnect: (_ central: CBCentralManager, _ peripheral: Central.Peripheral) -> ()

    init(didUpdateState: @escaping (_ central: CBCentralManager) -> (),
         didDiscover: @escaping(_ central: CBCentralManager, _ peripheral: Central.Peripheral, _ advertisementData: [String: Any], _ RSSI: NSNumber) -> (),
         didConnect: @escaping(_ central: CBCentralManager, _ peripheral: Central.Peripheral) -> ()) {
        self.didUpdateState = didUpdateState
        self.didDiscover = didDiscover
        self.didConnect = didConnect
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        didUpdateState(central)
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        didDiscover(central, Central.Peripheral(peripheral: peripheral), advertisementData, RSSI)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        didConnect(central, Central.Peripheral(peripheral: peripheral))
    }

}

protocol PeripheralProtocol {
    var identifier: UUID { get }
    var name: String? { get }
//    var peripheralDelegate: PeripheralDelegateInterface? { get }
    var peripheralState: Central.PeripheralState { get }
    var services1: Array<Central.Service>? { get }

    func discoverServices(_ services: [UUID]?)
    func discoverCharacteristics(_ characteristicUUIDs: [UUID]?, for service: Central.Service)
    func readValue(for characteristic: Central.Characteristic)
}

extension CBPeripheral: PeripheralProtocol {
    var services1: Array<Central.Service>? {
        return self.services?.map { Central.Service(service: $0) }
    }
    
    func discoverServices(_ services: [UUID]?) {
        return discoverServices(services?.map { CBUUID(nsuuid: $0) })
    }
    
    func discoverCharacteristics(_ characteristicUUIDs: [UUID]?, for service: Central.Service) {
        let CBUUIDs: [CBUUID]? = characteristicUUIDs?.map { CBUUID(nsuuid: $0) }
        return discoverCharacteristics(CBUUIDs, for: service.service as! CBService)
    }
    
    func readValue(for characteristic: Central.Characteristic) {
        return readValue(for: characteristic.characteristic as! CBCharacteristic)
    }
    
//    var peripheralDelegate: PeripheralDelegateInterface? {
//        return delegate
//    }
//
    var peripheralState: Central.PeripheralState {
        return Central.PeripheralState(state: state)
    }
}

protocol PeripheralDelegateInterface {
    func didDiscoverServices(_ peripheral: Central.Peripheral, _ error: Error?)
    func didDiscoverCharacteristicsFor(_ peripheral: Central.Peripheral, _ service: Central.Service, _ error: Error?)
    func didUpdateValueFor(_ peripheral: Central.Peripheral, _ characteristic: Central.Characteristic, _ error: Error?)
    func didModifyServices(_ peripheral: Central.Peripheral, _ invalidatedServices: [Central.Service])
}

protocol ServiceProtocol {
    var identifier: UUID? { get }
    var characteristics1: [Central.Characteristic]? { get }
    var description: String { get }
}

extension CBService: ServiceProtocol {
    var identifier: UUID? {
        return UUID(uuidString: uuid.uuidString)
    }

    var characteristics1: [Central.Characteristic]? {
        return self.characteristics?.map { Central.Characteristic(characteristic: $0)}
    }
}

protocol CharacteristicProtocol {
    var identifier: UUID? { get }
    var service1: Central.Service { get }
    var dataValue: Data? { get }
    var byteCount: Int? { get }
    var description: String { get }
}

extension CBCharacteristic: CharacteristicProtocol {
    var identifier: UUID? {
        return UUID(uuidString: uuid.uuidString)
    }
    
    var service1: Central.Service {
        return Central.Service(service: service)
    }
    
    var dataValue: Data? {
        return value
    }

    var byteCount: Int? {
        return value?.count
    }
}

enum Central {
    class Peripheral: NSObject {
        fileprivate let peripheral: PeripheralProtocol

        // TODO: get from peripheral in init so they can be properties
        var identifier: UUID
        var name: String?
        var state: PeripheralState
        var services: Array<Central.Service>?
        
        var delegate: PeripheralDelegateInterface?
//        {
//            set {
//
//            }
//        }

        init(peripheral: PeripheralProtocol) {
            self.identifier = peripheral.identifier
            self.name = peripheral.name
            
            self.state = peripheral.peripheralState
            self.services = peripheral.services1
            self.peripheral = peripheral
        }

        func discoverServices(_ services: [UUID]?) {
            return peripheral.discoverServices(services)
        }

        func discoverCharacteristics(_ characteristicUUIDs: [UUID]?, for service: Service) {
            return peripheral.discoverCharacteristics(characteristicUUIDs, for: service)
        }

        func readValue(for characteristic: Characteristic) {
            return peripheral.readValue(for: characteristic)
        }
    }

    enum PeripheralState {
        case connecting
        case connected
        case disconnected
        case disconnecting
        
        init(state: CBPeripheralState) {
            switch state {
            case .connecting:
                self = .connecting
            case .connected:
                self = .connected
            case .disconnected:
                self = .disconnected
            case .disconnecting:
                self = .disconnecting
            @unknown default:
                self = .disconnected
            }
        }
    }

    class PeripheralDelegate: PeripheralDelegateInterface {

        private let shim: PeripheralDelegateShim

        init(didDiscoverServices: @escaping (_ peripheral: Peripheral, _ error: Error?) -> (),
             didDiscoverCharacteristicsFor: @escaping (_ peripheral: Peripheral, _ service: Service, _ error: Error?) -> (),
           didUpdateValueFor: @escaping (_ peripheral: Peripheral, _ characteristic: Characteristic, _ error: Error?) -> (),
           didModifyServices: @escaping (_ peripheral: Peripheral, _ invalidatedServices: [Service]) -> ()) {
            shim = PeripheralDelegateShim(didDiscoverServices: didDiscoverServices,
                                          didDiscoverCharacteristicsFor: didDiscoverCharacteristicsFor,
                                          didUpdateValueFor: didUpdateValueFor,
                                          didModifyServices: didModifyServices)
        }

        func didDiscoverServices(_ peripheral: Peripheral, _ error: Error?) {
            shim.peripheral(peripheral.peripheral as! CBPeripheral, didDiscoverServices: error)
        }

        func didDiscoverCharacteristicsFor(_ peripheral: Peripheral, _ service: Service, _ error: Error?) {
            shim.peripheral(peripheral.peripheral as! CBPeripheral, didDiscoverCharacteristicsFor: service.service as! CBService, error: error)
        }

        func didUpdateValueFor(_ peripheral: Peripheral, _ characteristic: Characteristic, _ error: Error?) {
            shim.peripheral(peripheral.peripheral as! CBPeripheral, didUpdateValueFor: characteristic.characteristic as! CBCharacteristic, error: error)
        }

        func didModifyServices(_ peripheral: Peripheral, _ invalidatedServices: [Service]) {
            shim.peripheral(peripheral.peripheral as! CBPeripheral,
                            didModifyServices: invalidatedServices.map { $0.service as! CBService })
        }
    }

    class PeripheralDelegateShim: NSObject, CBPeripheralDelegate {
        private let didDiscoverServices: (_ peripheral: Peripheral, _ error: Error?) -> ()
        private let didDiscoverCharacteristicsFor: (_ peripheral: Peripheral, _ service: Service, _ error: Error?) -> ()
        private let didUpdateValueFor: (_ peripheral: Peripheral, _ characteristic: Characteristic, _ error: Error?) -> ()
        private let didModifyServices: (_ peripheral: Peripheral, _ invalidatedServices: [Service]) -> ()

        init(didDiscoverServices: @escaping (_ peripheral: Peripheral, _ error: Error?) -> (),
             didDiscoverCharacteristicsFor: @escaping (_ peripheral: Peripheral, _ service: Service, _ error: Error?) -> (),
             didUpdateValueFor: @escaping (_ peripheral: Peripheral, _ characteristic: Characteristic, _ error: Error?) -> (),
             didModifyServices: @escaping (_ peripheral: Peripheral, _ invalidatedServices: [Service]) -> ()) {
            self.didDiscoverServices = didDiscoverServices
            self.didDiscoverCharacteristicsFor = didDiscoverCharacteristicsFor
            self.didUpdateValueFor = didUpdateValueFor
            self.didModifyServices = didModifyServices
        }

        func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
            didDiscoverServices(Peripheral(peripheral: peripheral), error)
        }

        func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
            didDiscoverCharacteristicsFor(Peripheral(peripheral: peripheral), Service(service: service), error)
        }

        func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
            didUpdateValueFor(Peripheral(peripheral: peripheral), Characteristic(characteristic: characteristic), error)
        }

        // Is there any need for this to be implemented currently?
        func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
            didModifyServices(Peripheral(peripheral: peripheral), invalidatedServices.map { Service(service: $0) })
        }
    }
    
    class Service {
        var identifier: UUID?
        var characteristics: [Characteristic]?
        var description: String
        
        fileprivate let service: ServiceProtocol
        init(service: ServiceProtocol) {
            self.identifier = service.identifier
            self.characteristics = service.characteristics1
            self.description = service.description
            
            self.service = service
        }
    }
    
    class Characteristic: NSObject {
        
        var identifier: UUID?
        var dataValue: Data?
        var byteCount: Int?
//        var description: String
        var service: Service
        
        fileprivate let characteristic: CharacteristicProtocol

        init(characteristic: CharacteristicProtocol) {
            self.identifier = characteristic.identifier
            self.dataValue = characteristic.dataValue
            self.byteCount = characteristic.byteCount
//            self.description = characteristic.description
            self.service = characteristic.service1
            
            self.characteristic = characteristic
        }
    }
}
