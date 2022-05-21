//
//  ViewController.swift
//  VehicleDeadReckoning
//
//  Created by Jason Kim on 2022/01/02.
//

import UIKit
import MapKit
import CoreMotion


//let r2d = 180 / Double.pi
//let d2r = Double.pi / 180

class ViewController: UIViewController , CLLocationManagerDelegate{
    
    // For location variable
    let locationManager = CLLocationManager()
    
    // For looging variable
    let fileManager = FileManager.default
    var fileURL: URL? = nil
    var logContents : String?
    var loggingFile: String?
    var loggingUTC: String?
    var logpath : String?
    var outputStream : OutputStream?
    
    var memsState : MemsState!
    
    // For positioning Engine
    
    
    
    // Data From Location Framework
    var locationUpdateFlag : Bool = false
    var locationUpdateCnt : UInt64!
    var coor : CLLocationCoordinate2D?
    var speed : Double?
    var heading : Double?
    var accuracy : Double?
    var altitude : Double?
    var lat : Double?
    var lon : Double?
    var locationTimeUTC : [String]?
    
    //For heading
    var headingRate : Double = 0
    
    
    @IBOutlet weak var hdgRateShow: UILabel!
    var PositioningEngine : Int?
    var motionManager = CMMotionManager()
    
    var startStopToggle = 0
    
    @IBOutlet weak var startBtnText: UIButton!
    
    @IBOutlet weak var currentPosOnMap: MKMapView!
    
    @IBOutlet weak var latLonAltShow: UILabel!
    @IBOutlet weak var spdHdgAcuShow: UILabel!
    
  
    @IBOutlet weak var rollShow: UILabel!
    @IBOutlet weak var pitchShow: UILabel!
    @IBOutlet weak var yawShow: UILabel!

    @IBOutlet weak var accShow: UILabel!
    @IBOutlet weak var gyroShow: UILabel!
    
    @IBOutlet weak var accVarShow: UILabel!
    @IBOutlet weak var gyroVarShow: UILabel!
    
    @IBOutlet weak var staticDetectionStatusShow: UILabel!
    @IBOutlet weak var VDRstatusShow: UILabel!
    

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        
        //Initialize all variables.
        PositioningEngine = 0
        locationUpdateFlag = false
        locationUpdateCnt = 0
    }
    
    func log_print(log:String){
        outputStream!.write(log, maxLength: log.count)
    }

    //Function for various operation
    func goLocation(latitudeValue: CLLocationDegrees, longitudeValue:CLLocationDegrees,
                    delta span : Double)
    {
        let pLocation = CLLocationCoordinate2DMake(latitudeValue,longitudeValue)
        let spanValue = MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
        let pRegion = MKCoordinateRegion(center: pLocation, span: spanValue)
        
        currentPosOnMap.setRegion(pRegion, animated: true)
        
    }

    //When Update from GNSS.
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation])
    {
        
        locationUpdateFlag = true
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy,MM,DD,HH,mm,ss,SS"

        let hourMinSecond = dateFormatter.string(from: Date())
        let hourMinSecondList = hourMinSecond.components(separatedBy: ",")
        locationTimeUTC = hourMinSecondList
        
        let pLocation = locations.last
        //goLocation(latitudeValue: (pLocation?.coordinate.latitude)!, longitudeValue: (pLocation?.coordinate.longitude)!, delta: 0.01)
        
        coor = pLocation?.coordinate
        speed = pLocation?.speed
        heading = pLocation?.course
        accuracy = pLocation?.horizontalAccuracy
        altitude = pLocation?.altitude
        lat = coor!.latitude
        lon = coor!.longitude
        
        // To syncronize location data with sensor data.
        // So first throw away existing sensor data.
        if(locationUpdateCnt == 0 )
        {
            memsState?.initializeSensorBuffer()
        }

    }
    
    
    
    
    
    
    
    func updateAttitude(){
        var gyro :[Double] = [0,0,0]
        for i in 0...2{
            gyro[i] = memsState!.gyroAvgDouble[i] - memsState!.gyroBiasDouble[i]
        }
    }
    
    
    
    
    func outputAccelerationData(_ acceleration: CMAcceleration , timeStamp : TimeInterval)
    {
        //lock.lock(); defer {lock.unlock()}
        // CMAcceleration has G unit, G is 9.81m/s
        let accX = acceleration.x * 9.81
        let accY = acceleration.y * 9.81
        let accZ = acceleration.z * 9.81
        
        memsState.accArray.append(MemsState.accXYZ(xyz: [accX,accY,accZ], timeStamp: timeStamp))
        
    }
    
    func outputGyroData( gyro : CMRotationRate, timeStamp : TimeInterval)
    {
        //lock.lock(); defer {lock.unlock()}
        let gyroX = gyro.x
        let gyroY = gyro.y
        let gyroZ = gyro.z
        
        memsState.gyroArray.append(MemsState.gyroXYZ(xyz: [gyroX,gyroY,gyroZ], timeStamp: timeStamp))
    }
    
//    func loggingAccGyro(){
//        //lock.lock(); defer {lock.unlock()}
//        let accCnt = memsState.accArray.count
//        let gyroCnt = memsState.gyroArray.count
//
//        for i in 0...accCnt-1{
//            let timeStamp = memsState?.accArray[4 * i]
//            let accX = memsState?.accArray[4 * i + 1]
//            let accY = memsState?.accArray[4 * i + 2]
//            let accZ = memsState?.accArray[4 * i + 3]
//            //let accLog = String(format : "27,0,%.4f,%.4f,%.4f,%.4f\n",timeStamp,round(accX * 100000) / 10000,round(accY * 100000) / 10000,round(accZ * 100000) / 10000)
//            //logContents = logContents! + "27,0," +  accLog + "\n"
//
////            outputStream!.write(accLog,maxLength: accLog.count)
//
////            log_print(log: String(format : "27,0,%.4f,%.4f,%.4f,%.4f\n",timeStamp,round(accX * 100000) / 10000,round(accY * 100000) / 10000,round(accZ * 100000) / 10000))
//        }
//
//        for i in 0...gyroCnt-1{
//            let timeStamp = memsState?.gyroArray[ 4 * i]
//            let gyroX = memsState?.gyroArray[ 4 * i + 1]
//            let gyroY = memsState?.gyroArray[ 4 * i + 2]
//            let gyroZ = memsState?.gyroArray[ 4 * i + 3]
//            //let gyroLog = String(format : "27,1,%.4f,%.4f,%.4f,%.4f\n",timeStamp,gyroX,gyroY,gyroZ)
//            //logContents = logContents! + "27,1," +  gyroLog + "\n"
//            //outputStream!.write(gyroLog,maxLength: gyroLog.count)
////            log_print(log: String(format : "27,1,%.4f,%.4f,%.4f,%.4f\n",timeStamp,gyroX,gyroY,gyroZ))
//        }
//    }
    
    func PositioningEngineOn (){
        
        while(PositioningEngine! > 0)
        {

            if(locationUpdateFlag){
                
                // locationTimeUTC // list [String] [yyyy,HH,mm,ss,SS]
                
                locationUpdateCnt! += 1
                print("locationUpdate!!!")
                locationUpdateFlag = false
                let latLonAltShowText = String(format : "%.3f,%.3f,%.1f",lat!,lon!,altitude!)
                
                DispatchQueue.main.async {
                    self.goLocation(latitudeValue: (self.coor?.latitude)!, longitudeValue: (self.coor?.longitude)!, delta: 0.01)
                    self.latLonAltShow.text = latLonAltShowText
                    self.spdHdgAcuShow.text = String(format : "%.1f,%.1f,%.1f",self.speed!,self.heading!,self.accuracy!)
                }
                
                let latLonAltLog = String(format : "14,\(locationTimeUTC![0]),\(locationTimeUTC![1]),\(locationTimeUTC![2]),\(locationTimeUTC![3]),\(locationTimeUTC![4]),\(locationTimeUTC![5]).\(locationTimeUTC![6]),%.6f,%.6f,%.1f,%.2f,%.1f,%.2f\n",lat!,lon!,altitude!,speed!,heading!,accuracy!)
                //logContents = logContents! + "14," + latLonAltLog + "\n"
                
                //outputStream!.write(latLonAltLog,maxLength: latLonAltLog.count)
                log_print(log: latLonAltLog)
            }
            
            
            if(locationUpdateCnt! > 0){
                var accShow : [Double] = [0,0,0]
                var accVarShow : [Double] = [0,0,0]
                var hdgRateShowValue : Double = 0
                
                var gyroShow : [Double] = [0,0,0]
                var gyroVarShow : [Double] = [0,0,0]
                
                let accArrayCnt = memsState!.accArray.count/4
                let gyroArrayCnt = memsState!.gyroArray.count/4
                
//                loggingAccGyro()
                
                memsState.accAvgVarCalulate()
                memsState.gyroAvgVarCaluate()
                
                memsState.checkStaticDetection(accThreshold: 0.02,gyroThreshold: 00002)
                
                if(memsState.staticDetectionStatus == MemsState.STATIC_STATUS.STATIC) { // static case, then calculate and store the each bias.
                    for i in 0...2{
                        if(memsState.staticCnt == 0 ){
                            memsState!.accBiasDouble[i] = memsState!.accAvgDouble[i]
                            memsState!.gyroBiasDouble[i] = memsState!.gyroAvgDouble[i]
                        }
                        else{
                            memsState!.accBiasDouble[i] = 0.8 * memsState!.accBiasDouble[i] + 0.2 * memsState!.accAvgDouble[i]
                            memsState!.gyroBiasDouble[i] = 0.8 * memsState!.gyroAvgDouble[i] + 0.2 * memsState!.gyroAvgDouble[i]
                        }
                    }
                    memsState.staticCnt += 1
                    memsState.computeAttitude()
                    
                }
                else{
                    updateAttitude()
                }
                
                //                computeAttitude()
                memsState.computeHdgRate()
                hdgRateShowValue = round(headingRate * r2d * 10) / 10
                
                if(memsState.staticCnt>5){
                    memsState.computeAccXYZ()
                }
                

                
                if(abs(headingRate * r2d) < 0.5)
                {
                    // 1) Pile the value acceleration of each axis.
                    // 2) if some of the value would be over threshold, then compute ratio of x/y
                    // 3) it could be yaw(misalignment) value.
                }

                
                
                for i in 0...2{
                    accShow[i] = round(memsState!.accAvgDouble[i] * 100) / 100
                    if(memsState.staticCnt > 5 ){
                        accShow[i] = round(memsState.accXYZ_1s[i] * 100 ) / 100
                    }
                    accVarShow[i] = round(memsState.accVarDouble[i] * 100000) / 100000
                    gyroShow[i] = round(memsState.gyroAvgDouble[i] * 10000) / 10000
                    gyroVarShow[i] = round(memsState.gyroVarDouble[i] * 10000) / 10000
                }
                
                DispatchQueue.main.async {
                    self.accShow.text = "\(accArrayCnt))_\(accShow[0]),__\(accShow[1]),__\(accShow[2])"
                    self.gyroShow.text = "\(gyroArrayCnt))_\(gyroShow[0]),__\(gyroShow[1]),__\(gyroShow[2])"
                    
                    self.accVarShow.text = "\(accVarShow[0]),__\(accVarShow[1]),__\(accVarShow[2])"
                    self.gyroVarShow.text = "\(gyroVarShow[0]),__\(gyroVarShow[1]),__\(gyroVarShow[2])"
                    
                    if (self.memsState.staticDetectionStatus == MemsState.STATIC_STATUS.STATIC){
                        self.staticDetectionStatusShow.text = "Static"
                    }else if(self.memsState.staticDetectionStatus == MemsState.STATIC_STATUS.DYNAMIC){
                        self.staticDetectionStatusShow.text = "Dynamic wo static"
                    }else if(self.memsState.staticDetectionStatus == MemsState.STATIC_STATUS.DYNAMIC_AFTER_STATIC){
                        self.staticDetectionStatusShow.text = "Dynamic w static"
                    }
                    
                    self.rollShow.text = "\(round(self.memsState.roll * r2d * 10)/10 )"
                    self.pitchShow.text = "\(round(self.memsState.pitch * r2d * 10)/10 )"
                    
                    if(self.memsState.yawSetCnt > 5){
                        self.yawShow.text = "\(round(self.memsState.yaw * r2d * 10)/10)"
                    }
                    
                    self.hdgRateShow.text = "\(hdgRateShowValue)"
                    
                }
               
                memsState!.initializeSensorBuffer()
            }
            
        }
        
        // Terminate and Reset all related variable
        DispatchQueue.main.async {
            self.staticDetectionStatusShow.text = "Init"
        }
        memsState.staticDetectionStatus = MemsState.STATIC_STATUS.INIT
    }
    
    
    @IBAction func startBtn(_ sender: Any) {
        if(startStopToggle == 0 ){
            startStopToggle = 1
            startBtnText.setTitle("Stop", for: .normal)
            startBtnText.setTitleColor(.red, for: .normal)
                        
            // For logging
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy,MM,dd,HH,mm,ss"
            
            let hourMinSecond = dateFormatter.string(from: Date())
            let hourMinSecondList = hourMinSecond.components(separatedBy: ",")
            loggingUTC = "\(hourMinSecondList[0])_\(hourMinSecondList[1])_\(hourMinSecondList[2])_\(hourMinSecondList[3])_\(hourMinSecondList[4])_\(hourMinSecondList[5])"
            logContents = ""
            print(loggingUTC!)
            
            
            let documentsURL = fileManager.urls(for: .documentDirectory, in : .userDomainMask)[0]
            fileURL = documentsURL.appendingPathComponent("\(loggingUTC!).txt")
            logpath = fileURL?.path
            outputStream = OutputStream(toFileAtPath: logpath!, append: true)
            outputStream?.open()
            
            //
            memsState = MemsState()
            
            
            // Start GNSS Engine
            locationManager.startUpdatingLocation()
            currentPosOnMap.showsUserLocation = true
            
            
            // Start motionSensor(Accelerometer, GyroScope
            print("----START-----")
            motionManager.accelerometerUpdateInterval = 0.02
            motionManager.gyroUpdateInterval = 0.02
            
            motionManager.startAccelerometerUpdates(to: OperationQueue.current!, withHandler: {
                (accelerometerData: CMAccelerometerData!, error: Error!) -> Void in self.outputAccelerationData(accelerometerData.acceleration , timeStamp: accelerometerData.timestamp)
                if (error != nil){
                    print(error!)
                }
            })
            
            motionManager.startGyroUpdates(to: OperationQueue.current!, withHandler: {
                (gyroData: CMGyroData!, error: Error!) -> Void in self.outputGyroData(gyro: gyroData.rotationRate,timeStamp: gyroData.timestamp)
                if (error != nil){
                    print(error!)
                }
            })
            
            PositioningEngine = 1
            
            Thread{
                self.PositioningEngineOn()
            }.start()
            
            
        }
        else
        {
            startStopToggle = 0
            startBtnText.setTitle("Start", for: .normal)
            startBtnText.setTitleColor(.white, for: .normal)
            
            PositioningEngineOff()
            
            startStopToggle = 0
            
            locationManager.stopUpdatingLocation()
            currentPosOnMap.showsUserLocation = false
            
            motionManager.stopAccelerometerUpdates()
            motionManager.stopGyroUpdates()
            
            outputStream?.close()
        }
    }
    
    func PositioningEngineOff()
    {
        //lock.lock(); defer {lock.unlock()}
        PositioningEngine = 0
        
        memsState.initializeStaticStatus()
        memsState.initializeAttitude()
        memsState.initializePVDate()
    }
    
}
