//
//  ViewController.swift
//  MyStats
//
//  Created by Amrinder Gill on 5/17/20.
//  Copyright © 2020 Amrinder Gill. All rights reserved.
//
import Foundation
import UIKit
import CoreBluetooth
import CoreML
import CoreMotion



var blePeripheral : CBPeripheral?
var rxCharacteristic : CBCharacteristic?
var txCharacteristic : CBCharacteristic?
var characteristicASCIIValue = NSString()


class BLECentralViewController: UIViewController, CBPeripheralDelegate, CBCentralManagerDelegate,
    UITableViewDelegate, UITableViewDataSource {
        
    //Data
    var centralManager : CBCentralManager!
    var RSSIs = [NSNumber]()
    var data = NSMutableData()
    var writeData: String = ""
    var peripherals: [CBPeripheral] = []
    var characteristicValue = [CBUUID: NSData]()
    var timer = Timer()
    var characteristics = [String : CBCharacteristic]()
    var characteristicFloatValue = 0.0;
    var csvArray:[Dictionary<String, AnyObject>] =  Array();
    var numberOfRecordedData = 150
    var IsCollectingData = false
    var fileCounter = 0
    static var prediction1: String = "default"
    
    
    //Structs
    struct ModelConstants {
      static let numOfFeatures = 6
      // Must be the same value you used while training
      static let predictionWindowSize = 150
      // Must be the same value you used while training
      static let sensorsUpdateFrequency = 1.0 / 10.0
      static let hiddenInLength = 20
      static let hiddenCellInLength = 200
    }
    
    private let classifier = ActivityClassifier()
    private let modelName:String = "ActivityClassifier"
    var currentIndexInPredictionWindow = 0
    
    let accX = try? MLMultiArray(
        shape: [ModelConstants.predictionWindowSize] as [NSNumber],
        dataType: MLMultiArrayDataType.double)
    let accY = try? MLMultiArray(
        shape: [ModelConstants.predictionWindowSize] as [NSNumber],
        dataType: MLMultiArrayDataType.double)
    let accZ = try? MLMultiArray(
        shape: [ModelConstants.predictionWindowSize] as [NSNumber],
        dataType: MLMultiArrayDataType.double)
    let rotX = try? MLMultiArray(
        shape: [ModelConstants.predictionWindowSize] as [NSNumber],
        dataType: MLMultiArrayDataType.double)
    let rotY = try? MLMultiArray(
        shape: [ModelConstants.predictionWindowSize] as [NSNumber],
        dataType: MLMultiArrayDataType.double)
    let rotZ = try? MLMultiArray(
        shape: [ModelConstants.predictionWindowSize] as [NSNumber],
        dataType: MLMultiArrayDataType.double)
    
    var currentState = try? MLMultiArray(
    shape: [(ModelConstants.hiddenInLength +
      ModelConstants.hiddenCellInLength) as NSNumber],
    dataType: MLMultiArrayDataType.double)
    
    

    
    //UI
    @IBOutlet weak var baseTableView: UITableView!
    @IBOutlet weak var refreshButton: UIBarButtonItem!
    
    @IBAction func refreshAction(_ sender: AnyObject) {
        disconnectFromDevice()
        self.peripherals = []
        self.RSSIs = []
        self.baseTableView.reloadData()
        startScan()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.baseTableView.delegate = self
        self.baseTableView.dataSource = self
        self.baseTableView.reloadData()
        
        // Make sure nothing is running through the model yet
        stopDeviceMotion()
        //Clear out the CSV files 
        //clearTempFolder()
        
        /* CBCentralManager objects are used to manage discovered or connected remote peripheral devices , including scanning for, discovering, and connecting to advertising peripherals.
         */
        centralManager = CBCentralManager(delegate: self, queue: nil)
        let backButton = UIBarButtonItem(title: "Disconnect", style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backButton
        collectDataObserver()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        disconnectFromDevice()
        super.viewDidAppear(animated)
        refreshScanView()
        print("View Cleared")
    }
    
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        print("Stop Scanning")
        centralManager?.stopScan()
    }
    
    func stopDeviceMotion() {
    // Stop streaming device data
      
    // Reset some parameters
      currentIndexInPredictionWindow = 0
      currentState = try? MLMultiArray(
        shape: [(ModelConstants.hiddenInLength +
          ModelConstants.hiddenCellInLength) as NSNumber],
        dataType: MLMultiArrayDataType.double)
    }
    
    func addMotionDataSampleToArray(motionSample: [Float]) {
    // Using global queue for building prediction array
    DispatchQueue.global().async {
      self.rotX![self.currentIndexInPredictionWindow] = motionSample[0] as NSNumber
      self.rotY![self.currentIndexInPredictionWindow] = motionSample[1] as NSNumber
      self.rotZ![self.currentIndexInPredictionWindow] = motionSample[2] as NSNumber
       self.accX![self.currentIndexInPredictionWindow] = motionSample[3] as NSNumber
       self.accY![self.currentIndexInPredictionWindow] = motionSample[4] as NSNumber
        self.accZ![self.currentIndexInPredictionWindow] = motionSample[5] as NSNumber
              
         // Update prediction array index
         self.currentIndexInPredictionWindow += 1
              
         // If data array is full - execute a prediction
         if (self.currentIndexInPredictionWindow == ModelConstants.predictionWindowSize) {
           // Move to main thread to update the UI
           DispatchQueue.main.async {
             // Use the predicted activity
            BLECentralViewController.prediction1 = self.activityPrediction() ?? "N/A"

            NotificationCenter.default.post(name:NSNotification.Name(rawValue: "Predicted"), object: self)
           }
           // Start a new prediction window from scratch
           self.currentIndexInPredictionWindow = 0
         }
       }
     }
    
    func activityPrediction() -> String? {
      // Perform prediction
      let modelPrediction = try? classifier.prediction(
        Accel_X: accX!,
        Accel_Y: accY!,
        Accel_Z: accZ!,
        Gyro_X: rotX!,
        Gyro_Y: rotY!,
        Gyro_Z: rotZ!,
        stateIn: currentState)
    // Update the state vector
      currentState = modelPrediction?.stateOut
    // Return the predicted activity
      return modelPrediction?.label
    }
    
    //Search for devices
    func startScan() {
        peripherals = []
        print("Now Scanning...")
        self.timer.invalidate()
        centralManager?.scanForPeripherals(withServices: [BLEService_UUID] , options: [CBCentralManagerScanOptionAllowDuplicatesKey:false])
        Timer.scheduledTimer(withTimeInterval: 17, repeats: false) {_ in
            self.cancelScan()
        }
    }
    
    /*Stop scanning*/
    func cancelScan() {
        self.centralManager?.stopScan()
        print("Scan Stopped")
        print("Number of Peripherals Found: \(peripherals.count)")
    }
    
    func refreshScanView() {
        baseTableView.reloadData()
    }
    
    //-Terminate all Peripheral Connection
    /*
     Call this when things either go wrong, or done with the connection.
     */
    func disconnectFromDevice () {
        if blePeripheral != nil {
            centralManager?.cancelPeripheralConnection(blePeripheral!)
        }
    }
    
    
    func restoreCentralManager() {
        //Restores Central Manager delegate if something went wrong
        centralManager?.delegate = self
    }
    
    /*
     Called when the central manager discovers a peripheral while scanning. Also, once peripheral is connected, cancel scanning.
     */
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        blePeripheral = peripheral
        self.peripherals.append(peripheral)
        self.RSSIs.append(RSSI)
        peripheral.delegate = self
        self.baseTableView.reloadData()
        if blePeripheral == nil {
            print("Found new pheripheral devices with services")
            print("Peripheral name: \(String(describing: peripheral.name))")
            print("**********************************")
            print ("Advertisement Data : \(advertisementData)")
        }
    }
    
    //Peripheral Connections: Connecting, Connected, Disconnected
    
    //-Connection
    func connectToDevice () {
        centralManager?.connect(blePeripheral!, options: nil)
    }
    
    /*
     Invoked when a connection is successfully created with a peripheral.
     This method is invoked when a call to connect(_:options:) is successful.
     */
    //-Connected
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("*****************************")
        print("Connection complete")
        print("Peripheral info: \(String(describing: blePeripheral))")
        
        //Stop Scan-
        centralManager?.stopScan()
        print("Scan Stopped")
        
        //Erase data that we might have
        data.length = 0
        
        //Discovery callback
        peripheral.delegate = self
        //Only look for services that matches transmit uuid
        peripheral.discoverServices([BLEService_UUID])
        
        
        //Once connected, move to new view controller to manager incoming and outgoing data
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        
        let uartViewController = storyboard.instantiateViewController(withIdentifier: "UartModuleViewController") as! UartModuleViewController
        
        uartViewController.peripheral = peripheral
        
        navigationController?.pushViewController(uartViewController, animated: true)
    }
    
    /*
     Invoked when the central manager fails to create a connection with a peripheral.
     */
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if error != nil {
            print("Failed to connect to peripheral")
            return
        }
    }
    
    func disconnectAllConnection() {
        centralManager.cancelPeripheralConnection(blePeripheral!)
    }
    
    /*
     Invoked when you discover the peripheral’s available services.
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("*******************************************************")
        
        if ((error) != nil) {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else {
            return
        }
        //Discover the all characteristic
        for service in services {
            
            peripheral.discoverCharacteristics(nil, for: service)
        }
        print("Discovered Services: \(services)")
    }
    
    /*
     Invoked when you discover the characteristics of a specified service.
     */
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        print("*******************************************************")
        
        if ((error) != nil) {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else {
            return
        }
        
        print("Found \(characteristics.count) characteristics!")
        
        for characteristic in characteristics {
            //looks for the right characteristic
            
            if characteristic.uuid.isEqual(gyroBLE_Characteristic_uuid_Rx)  {
                rxCharacteristic = characteristic
                
                //Once found, subscribe to the this particular characteristic...
                peripheral.setNotifyValue(true, for: rxCharacteristic!)
                // didUpdateNotificationStateForCharacteristic method will be called automatically
                peripheral.readValue(for: characteristic)
                print("Rx Characteristic: \(characteristic.uuid)")
            }
            if characteristic.uuid.isEqual(gyroBLE_Characteristic_uuid_Tx){
                txCharacteristic = characteristic
                print("Tx Characteristic: \(characteristic.uuid)")
            }
            if characteristic.uuid.isEqual(accelBLE_Characteristic_uuid_Rx)  {
                rxCharacteristic = characteristic
                
                //Once found, subscribe to the this particular characteristic...
                peripheral.setNotifyValue(true, for: rxCharacteristic!)
                // didUpdateNotificationStateForCharacteristic method will be called automatically
                peripheral.readValue(for: characteristic)
                print("Rx Characteristic: \(characteristic.uuid)")
            }
            if characteristic.uuid.isEqual(accelBLE_Characteristic_uuid_Tx){
                txCharacteristic = characteristic
                print("Tx Characteristic: \(characteristic.uuid)")
            }
            peripheral.discoverDescriptors(for: characteristic)
        }
    }
    
    // MARK: - Getting Values From Characteristic
    /**  found a characteristic of a service, read the characteristic's value by calling the peripheral "readValueForCharacteristic" method within the "didDiscoverCharacteristicsFor service" delegate.
     */
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        guard characteristic == rxCharacteristic,
            let data:Data = characteristic.value
            else { return }

        var myFloatArray = Array<Float>(repeating: 0, count: data.count/MemoryLayout<Float>.stride)
        myFloatArray.withUnsafeMutableBytes { data.copyBytes(to: $0) }
        
    
        var sensorReadings = Dictionary<String, AnyObject>()

        
        if(IsCollectingData == true) {
            //Send data to be predicted to UI
            var sendDataArray = [Float]()
            sendDataArray.append(myFloatArray[2])
            sendDataArray.append(myFloatArray[3])
            sendDataArray.append(myFloatArray[4])
            sendDataArray.append(myFloatArray[5])
            sendDataArray.append(myFloatArray[6])
            sendDataArray.append(myFloatArray[7])

            //Disabling sending data temporarily
            self.addMotionDataSampleToArray(motionSample: sendDataArray)
            sensorReadings.updateValue(myFloatArray[2] as AnyObject, forKey: "Gyro X")
            sensorReadings.updateValue(myFloatArray[3] as AnyObject, forKey: "Gyro Y")
            sensorReadings.updateValue(myFloatArray[4] as AnyObject, forKey: "Gyro Z")
            sensorReadings.updateValue(myFloatArray[5] as AnyObject, forKey: "Acc X")
            sensorReadings.updateValue(myFloatArray[6] as AnyObject, forKey: "Acc Y")
            sensorReadings.updateValue(myFloatArray[7] as AnyObject, forKey: "Acc Z")
            csvArray.append(sensorReadings)
            if(csvArray.count == numberOfRecordedData){
                print("---> : File creating..")
                createCSVFile(from: csvArray)
                NotificationCenter.default.post(name:NSNotification.Name(rawValue: "Good"), object: self)
                csvArray.removeAll();
                
            }
        }
                
    }

    func collectDataObserver () {
        //Add an Observer
        NotificationCenter.default.addObserver(self, selector: #selector(BLECentralViewController.toggleData(notification:)), name: Notification.Name(rawValue: "Collect"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(BLECentralViewController.toggleData(notification:)), name: Notification.Name(rawValue: "Do Not Collect"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(BLECentralViewController.clearTempFolder(notification:)), name: Notification.Name(rawValue: "Delete"), object: nil)

    }
    
    @objc func toggleData(notification: NSNotification) {
        print("Notification Received")
        let isCollectData = notification.name.rawValue == "Collect"
        if(isCollectData){
            IsCollectingData = true
        }
        else
        {
            IsCollectingData = false
            NotificationCenter.default.post(name:NSNotification.Name(rawValue: "Missed"), object: self)
        }
    }
    
    func createCSVFile(from recArray:[Dictionary<String, AnyObject>])
    {
        var csvString = "\("Gyro X"),\("Gyro Y"),\("Gyro Z"),\("Accel X"),\("Accel Y"),\("Accel Z")\n\n"
        
        for accelValues in recArray {
            csvString = csvString.appending("\(String(describing: accelValues["Gyro X"]!)),\(String(describing: accelValues["Gyro Y"]!)),\(String(describing: accelValues["Gyro Z"]!)),\(String(describing: accelValues["Acc X"]!)),\(String(describing: accelValues["Acc Y"]!)),\(String(describing: accelValues["Acc Z"]!))\n")
        }
        
        let fileManager = FileManager.default
        do {
            let path = try FileManager.default.url(for: .documentDirectory, in: .allDomainsMask, appropriateFor: nil, create: true)
            let fileURL =  path.appendingPathComponent("CSVTestData\(fileCounter).csv")
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            print("Done Creating CSV :  \(fileURL.path)")
            fileCounter += 1
            
        } catch {
            print("Error Creating CSV File")
        }
        
        
    }
    
    //Clears out the CSVs created for ML model data
    @objc func clearTempFolder(notification: NSNotification) {
        
        let fileManager = FileManager.default
        let myDocuments = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        guard let filePaths = try? fileManager.contentsOfDirectory(at: myDocuments, includingPropertiesForKeys: nil, options: []) else { return }
        
        print("Clearing CSVs: ")
        fileCounter = 0;
        
        for filePath in filePaths {
            try? fileManager.removeItem(at: filePath)
        }
    }
    

    func processSensorData(sensorDataArray : [Float])
    {
        
        print("---> : \(sensorDataArray)")
        
        if(sensorDataArray[0] < -1.0 && sensorDataArray[1] < -0.5 && sensorDataArray[2] > 0.5)
        {
            print("---> SUCCESS GOOD");
            NotificationCenter.default.post(name:NSNotification.Name(rawValue: "Good"), object: self)
        }

    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        print("*******************************************************")
        
        if error != nil {
            print("\(error.debugDescription)")
            return
        }
        guard let descriptors = characteristic.descriptors else { return }
            
        descriptors.forEach { descript in
            print("function name: DidDiscoverDescriptorForChar \(String(describing: descript.description))")
            print("Rx Value \(String(describing: rxCharacteristic?.value))")
            print("Tx Value \(String(describing: txCharacteristic?.value))")

        }
    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        print("*******************************************************")
        
        if (error != nil) {
            print("Error changing notification state:\(String(describing: error?.localizedDescription))")
            
        } else {
            print("Characteristic's value subscribed")
        }
        
        if (characteristic.isNotifying) {
            print ("Subscribed. Notification has begun for: \(characteristic.uuid)")
        }
    }
    
    
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected")
    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("Error discovering services: error")
            return
        }
        print("Message sent")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
        guard error == nil else {
            print("Error discovering services: error")
            return
        }
        print("Succeeded!")
    }
    
    //Table View Functions
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.peripherals.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        //Connect to device where the peripheral is connected
        let cell = tableView.dequeueReusableCell(withIdentifier: "BlueCell") as! PeripheralTableViewCell
        let peripheral = self.peripherals[indexPath.row]
        let RSSI = self.RSSIs[indexPath.row]
        
        
        if peripheral.name == nil {
            cell.peripheralLabel.text = "nil"
        } else {
            cell.peripheralLabel.text = peripheral.name
        }
        cell.rssiLabel.text = "RSSI: \(RSSI)"
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        blePeripheral = peripherals[indexPath.row]
        connectToDevice()
    }
    
    /*
     Invoked when the central manager’s state is updated.
     */
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == CBManagerState.poweredOn {
            print("Bluetooth Enabled")
            startScan()
            
        } else {
            print("Bluetooth Disabled- Make sure your Bluetooth is turned on")
            
            let alertVC = UIAlertController(title: "Bluetooth is not enabled", message: "Make sure that your bluetooth is turned on", preferredStyle: UIAlertController.Style.alert)
            let action = UIAlertAction(title: "ok", style: UIAlertAction.Style.default, handler: { (action: UIAlertAction) -> Void in
                self.dismiss(animated: true, completion: nil)
            })
            alertVC.addAction(action)
            self.present(alertVC, animated: true, completion: nil)
        }
    }
    
    
    
}

