//
//  UartModuleViewController.swift
//  MyStats
//
//  Created by Amrinder Gill on 5/27/20.
//  Copyright © 2020 Amrinder Gill. All rights reserved.
//

import Foundation
import UIKit
import CoreBluetooth

class UartModuleViewController: UIViewController, CBPeripheralManagerDelegate, UITextViewDelegate, UITextFieldDelegate {
    
    //UI
    //@IBOutlet weak var baseTextView: UITextView!
    //@IBOutlet weak var baseTextView: UITextView!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var inputTextField: UITextField!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var switchUI: UISwitch!
    
    @IBOutlet weak var ShotImage: UIImageView!
    
    //Data
    var peripheralManager: CBPeripheralManager?
    var peripheral: CBPeripheral!
    private var consoleAsciiText:NSAttributedString? = NSAttributedString(string: "")
    
    var bleVC: BLECentralViewController = BLECentralViewController()
    
        
    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.backBarButtonItem = UIBarButtonItem(title:"Back", style:.plain, target:nil, action:nil)
        self.inputTextField.delegate = self


        //Input Text Field setup
        self.inputTextField.layer.borderWidth = 2.0
        self.inputTextField.layer.borderColor = UIColor.blue.cgColor
        self.inputTextField.layer.cornerRadius = 3.0
        //Create and start the peripheral manager
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        //-Notification for updating the text view with incoming text
        updateIncomingData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        //--self.baseTextView.text = ""
        
        
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        // peripheralManager?.stopAdvertising()
        // self.peripheralManager = nil
        super.viewDidDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: Notification.Name(rawValue: "Good"), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name(rawValue: "Missed"), object: nil)
    }
    
    
    func updateIncomingData () {
        //Add an Observer
        NotificationCenter.default.addObserver(self, selector: #selector(UartModuleViewController.updateImage(notification:)), name: Notification.Name(rawValue: "Good"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(UartModuleViewController.updateImage(notification:)), name: Notification.Name(rawValue: "Missed"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(UartModuleViewController.printPrediction(notification:)), name: Notification.Name(rawValue: "Predicted"), object: nil)
    }

    @IBOutlet weak var PredictionLabel: UILabel!
    
    
    @objc func printPrediction (notification: NSNotification) {
        print("Prediction ->>>> : \(BLECentralViewController.prediction1)")
        self.PredictionLabel.text = BLECentralViewController.prediction1
    }
    
    @objc func updateImage(notification: NSNotification) {
        let isShotMade = notification.name.rawValue == "Good"
        if(isShotMade){
            switchUI.setOn(false, animated: true)
            NotificationCenter.default.post(name:NSNotification.Name(rawValue: "Do Not Collect"), object: self)
        }
        let image = isShotMade ? UIImage(named: "Good")! : UIImage(named: "Missed")!
        ShotImage.image = image
    }
    
    @IBAction func clickSendAction(_ sender: AnyObject) {
        outgoingData()
        
    }
    
    
    
    func outgoingData () {
        let appendString = "\n"
        
        let inputText = inputTextField.text
        
        let myFont = UIFont(name: "Helvetica Neue", size: 15.0)
        let myAttributes1 = [convertFromNSAttributedStringKey(NSAttributedString.Key.font): myFont!, convertFromNSAttributedStringKey(NSAttributedString.Key.foregroundColor): UIColor.blue]
        
        writeValue(data: inputText!)
        
        let attribString = NSAttributedString(string: "[Outgoing]: " + inputText! + appendString, attributes: convertToOptionalNSAttributedStringKeyDictionary(myAttributes1))
        let newAsciiText = NSMutableAttributedString(attributedString: self.consoleAsciiText!)
        newAsciiText.append(attribString)
        
        consoleAsciiText = newAsciiText
        //erase what's in the text field
        inputTextField.text = ""
        
    }
    
    // Write functions
    func writeValue(data: String){
        let valueString = (data as NSString).data(using: String.Encoding.utf8.rawValue)
        //change the "data" to valueString
        if let blePeripheral = blePeripheral{
            if let txCharacteristic = txCharacteristic {
                blePeripheral.writeValue(valueString!, for: txCharacteristic, type: CBCharacteristicWriteType.withResponse)
            }
        }
    }
    
    func writeCharacteristic(val: Int8){
        var val = val
        let ns = NSData(bytes: &val, length: MemoryLayout<Int8>.size)
        blePeripheral!.writeValue(ns as Data, for: txCharacteristic!, type: CBCharacteristicWriteType.withResponse)
    }
    
    
    
    //MARK: UITextViewDelegate methods
    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
// --       if textView === baseTextView {
//  --          //tapping on consoleview dismisses keyboard
// --           inputTextField.resignFirstResponder()
// --           return false
//        }
        return true
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        scrollView.setContentOffset(CGPoint(x:0, y:250), animated: true)
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        scrollView.setContentOffset(CGPoint(x:0, y:0), animated: true)
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn {
            return
        }
        print("Peripheral manager is running")
    }
    
    //Check when someone subscribe to our characteristic, start sending the data
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        print("Device subscribe to characteristic")
    }
    
    //This on/off switch sends a value of 1 and 0 to the device

    
    @IBAction func switchAction(_ sender: Any) {
        if switchUI.isOn {
            print("Collecting Data ")
            NotificationCenter.default.post(name:NSNotification.Name(rawValue: "Collect"), object: self)
        }
        else
        {
            print("Not Collecting Data")
            NotificationCenter.default.post(name:NSNotification.Name(rawValue: "Do Not Collect"), object: self)
        }
                
    }
    
    @IBAction func deleteButton(_ sender: Any) {
        NotificationCenter.default.post(name:NSNotification.Name(rawValue: "Delete"), object: self)
    }
    
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        outgoingData()
        return(true)
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            print("\(error)")
            return
        }
    }
}


// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromNSAttributedStringKey(_ input: NSAttributedString.Key) -> String {
    return input.rawValue
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToOptionalNSAttributedStringKeyDictionary(_ input: [String: Any]?) -> [NSAttributedString.Key: Any]? {
    guard let input = input else { return nil }
    return Dictionary(uniqueKeysWithValues: input.map { key, value in (NSAttributedString.Key(rawValue: key), value)})
}

