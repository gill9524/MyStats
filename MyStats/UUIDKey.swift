//
//  UUIDKey.swift
//  MyStats
//
//  Created by Amrinder Gill on 5/17/20.
//  Copyright © 2020 Amrinder Gill. All rights reserved.
//

import CoreBluetooth
//Uart Service uuid


let kBLEService_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
let aBLE_Characteristic_uuid_Tx = "beb5483e-36e1-4688-b7f5-ea07361b26a8"
let aBLE_Characteristic_uuid_Rx = "beb5483e-36e1-4688-b7f5-ea07361b26a8"
let gBLE_Characteristic_uuid_Tx = "3101"
let gBLE_Characteristic_uuid_Rx = "3101"
let MaxCharacters = 20

let BLEService_UUID = CBUUID(string: kBLEService_UUID)
let accelBLE_Characteristic_uuid_Tx = CBUUID(string: aBLE_Characteristic_uuid_Tx)//(Property = Write without response)
let accelBLE_Characteristic_uuid_Rx = CBUUID(string: aBLE_Characteristic_uuid_Rx)// (Property = Read/Notify)
let gyroBLE_Characteristic_uuid_Tx = CBUUID(string: gBLE_Characteristic_uuid_Tx)//(Property = Write without response)
let gyroBLE_Characteristic_uuid_Rx = CBUUID(string: gBLE_Characteristic_uuid_Rx)// (Property = Read/Notify)
