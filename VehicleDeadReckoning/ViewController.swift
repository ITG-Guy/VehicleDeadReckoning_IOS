//
//  ViewController.swift
//  VehicleDeadReckoning
//
//  Created by Jason Kim on 2022/01/02.
//

import UIKit
import MapKit
import CoreMotion

let r2d = 180 / Double.pi
let d2r = Double.pi / 180

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
    
    // Sensor Data
    let lock = NSLock() // when access to accArray and gyroArray, Locked is needed.
    var accArray : Array<Double> = []
    var accAvgDouble : [Double] = [0,0,0]
    var accVarDouble : [Double] = [0,0,0]
    var accBiasDouble: [Double] = [0,0,0]
    
    var gyroArray : Array<Double> = []
    var gyroAvgDouble : [Double] = [0,0,0]
    var gyroVarDouble : [Double] = [0,0,0]
    var gyroBiasDouble : [Double] = [0,0,0]
    
    
    // For positioning Engine
    var staticDetectionStatus : Int? // 0 : init, 1: static, 2: dynamic 3: dynamic after static detection at least once.
    var staticCnt :Int  = 0
    var staticFlag : Int? // 0: Dynamic, 1 : Static
    var VDRstatusShowContent : Int? // 0 : Depend on LocationUpdates 1: VDR is working
    
    
    
    // Data From Location Framework
    var locationUpdateFlag : Bool!
    var locationUpdateCnt : UInt64!
    var coor : CLLocationCoordinate2D?
    var speed : Double?
    var heading : Double?
    var accuracy : Double?
    var altitude : Double?
    var lat : Double?
    var lon : Double?
    var locationTimeUTC : [String]?
    
    
    // Attitude
    var roll : Double = 0.0
    var pitch: Double = 0.0
    var yaw : Double = 0.0
    var yawSetCnt : Int = 0
    
    // Acceleration array
    var accXYZ : [Double] = [0,0,0]
    var accSumXY : [Double] = [0,0,0]
    var accNED : [Double] = [0,0,0]
    
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
            //Initialize acc,gyro Buffer
            accArray  = []
            accAvgDouble = [0,0,0]
            accVarDouble = [0,0,0]
            
            gyroArray = []
            gyroAvgDouble = [0,0,0]
            gyroVarDouble = [0,0,0]
        }

    }
    
    func computeHdgRate(){
        let cosRoll = cos(roll)
        let sinRoll = sin(roll)
        let cosPitch = cos(pitch)
        let sinPitch = sin(pitch)
        
        
        
        var gyro :[Double] = [0,0,0]
        for i in 0...2{
            gyro[i] = gyroAvgDouble[i] - gyroBiasDouble[i]
        }
        // if headingRate < threshold
        // Take ratio to yaw
        // and count the yawCnt
        
        headingRate = -sinPitch * gyro[1] + cosPitch * (sinRoll * gyro[0] - cosRoll * gyro[2])
        
    }
    
    func computeAccXYZ(){
        var acc :[Double] = [0,0,0]
        for i in 0...2{
            acc[i] = accAvgDouble[i]-accBiasDouble[i]
            //print("i: \(acc[i]), \(accAvgDouble[i]) , \(accBiasDouble[i])")
        }
        
        let cosPitch = cos(pitch)
        let sinPitch = sin(pitch)
        let cosRoll = cos(roll)
        let sinRoll = sin(roll)
        
        accXYZ[0] = cosRoll * acc[0] + sinRoll * acc[2]
        accXYZ[1] = cosPitch * acc[1] + sinPitch * (-sinRoll * acc[0] + sinRoll * acc[2])
        accXYZ[2] = sinPitch * acc[1] + cosPitch * (-sinRoll * acc[0] + cosRoll * acc[2])
        
        accXYZ[0] = -accXYZ[0]
        accXYZ[1] = -accXYZ[1]
        accXYZ[2] = -accXYZ[2]
        
//        print("roll: \(round(roll * r2d * 10)/10)")
//        print("pitch: \(round(pitch * r2d * 10)/10)")
//        print("accXYZ:   \(accXYZ[0])  ,  \(accXYZ[1])  ,  \(accXYZ[2])")
//
        if(abs(headingRate * r2d)<0.3   && yawSetCnt < 10){
            if(accXYZ[1]>0){
                accSumXY[0] += accXYZ[0]
                accSumXY[1] += accXYZ[1]
            }
            else{
                accSumXY[0] += -accXYZ[0]
                accSumXY[1] += -accXYZ[1]
            }
        }
        
        if(accSumXY[0] > 15.0 || accSumXY[1] > 15.0){
            let tmp = atan2(accSumXY[0],accSumXY[1]) - Double.pi/2
            if(yawSetCnt == 0){
                // Initial value
                yaw = tmp
            }
            else{
                // Update weighted average
                yaw = yaw * 0.8 + tmp * 0.2
            }
            yawSetCnt += 1
        }
        
        log_print(log: "accSumXY,\(accSumXY[0]),\(accSumXY[1]),yaw,\(yaw),yawSetCnt,\(yawSetCnt),hdgRate,\(headingRate * r2d)\n")
        
        
    }
    
    // Compute Attitude on static status
    func computeAttitude () {
        // Compute roll and pitch value on the static status
        var acc :[Double] = [0,0,0]
        var Roll:Double = 0.0
        var Pitch:Double = 0.0
        
        for i in 0...2{
            acc[i] = accAvgDouble[i] //-accBiasDouble[i]
        }
        
        let Gravity = sqrt(acc[0]*acc[0]+acc[1]*acc[1]+acc[2]*acc[2])
        
        Pitch = asin(-acc[1]/Gravity)
        Roll = asin(acc[0]/(Gravity*cos(Pitch)))

        
        if(staticCnt == 1){
            roll = Roll
            pitch = Pitch
        }
        else{
            roll = 0.8 * Roll + 0.2 * roll
            pitch = 0.8 * Pitch + 0.2 * pitch
        }
    }
    
    func updateAttitude(){
        var gyro :[Double] = [0,0,0]
        for i in 0...2{
            gyro[i] = gyroAvgDouble[i] - gyroBiasDouble[i]
        }
    }
    
    func checkStaticDetection(){
        let accThreshold = 0.015
        let gyroThrshold = 0.001
        
        let accResetThreshold = 0.15
        let gyroResetThreshold = 0.15

        
        if(
            (accVarDouble[0] < accThreshold && accVarDouble[1] < accThreshold && accVarDouble[2] < accThreshold )
            &&
            (gyroVarDouble[0] < gyroThrshold && gyroVarDouble[1] < gyroThrshold && gyroVarDouble[2] < gyroThrshold)
        ){
//            staticDetectionStatus = 1
            if (speed! < 0.5 && speed! >= 0){
                staticDetectionStatus = 1
            }
        }else{
            if(staticDetectionStatus == 0){
                staticDetectionStatus = 2
            }else if (
                (staticDetectionStatus == 2)
                ||
                (
                    (accVarDouble[0] > accResetThreshold
                     || accVarDouble[1] > accResetThreshold
                     || accVarDouble[2] > accResetThreshold )
                    &&
                    (gyroVarDouble[0] > gyroResetThreshold
                     || gyroVarDouble[1] > gyroResetThreshold
                     || gyroVarDouble[2] > gyroResetThreshold)
                )
            ) // start Dynamic.
            {
                staticDetectionStatus = 2
            }else if (staticDetectionStatus == 1) // After static Detection
            {
                staticDetectionStatus = 3
            }
            
        }
        
    }
    
    
    func accAvgVarCalulate(){
        let cnt = Int(accArray.count/4)
        var accSum : Array<Double> = [0,0,0]
        var accSqSum : Array<Double> = [0,0,0]
        if(cnt != 0 ) {
            for i in 0...(cnt-1){
                for j in 0...2{
                    accSum[j] += accArray[i*4+j+1]
                    accSqSum[j] += accArray[i*4+j+1] * accArray[i*4+j+1]
                }
            }
            for j in 0...2{
                accAvgDouble[j] = accSum[j]/Double(cnt)
                accVarDouble[j] = accSqSum[j]/Double(cnt) - accAvgDouble[j] * accAvgDouble[j]
            }
        }
        return
    }
    
    func gyroAvgVarCaluate(){
        let cnt = Int(gyroArray.count/4)
        var gyroSum : Array<Double> = [0,0,0]
        var gyroSqSum : Array<Double> = [0,0,0]
        if(cnt != 0 ) {
            for i in 0...(cnt-1){
                for j in 0...2{
                    gyroSum[j] += gyroArray[i*4+j+1]
                    gyroSqSum[j] += gyroArray[i*4+j+1] * gyroArray[i*4+j+1]
                }
            }
            for j in 0...2{
                gyroAvgDouble[j] = gyroSum[j]/Double(cnt)
                gyroVarDouble[j] = gyroSqSum[j]/Double(cnt) - gyroAvgDouble[j] * gyroAvgDouble[j]
            }
        }
        return
    }
    
    func outputAccelerationData(_ acceleration: CMAcceleration , timeStamp : TimeInterval)
    {
        lock.lock(); defer {lock.unlock()}
        // CMAcceleration has G unit, G is 9.81m/s
        let accX = acceleration.x * 9.81
        let accY = acceleration.y * 9.81
        let accZ = acceleration.z * 9.81
        
        accArray.append(timeStamp)
        accArray.append(accX)
        accArray.append(accY)
        accArray.append(accZ)
        
    }
    
    func outputGyroData( gyro : CMRotationRate, timeStamp : TimeInterval)
    {
        lock.lock(); defer {lock.unlock()}
        let gyroX = gyro.x
        let gyroY = gyro.y
        let gyroZ = gyro.z
        
        gyroArray.append(timeStamp)
        gyroArray.append(gyroX)
        gyroArray.append(gyroY)
        gyroArray.append(gyroZ)

    }
    
    func loggingAccGyro(){
        lock.lock(); defer {lock.unlock()}
        let accCnt = accArray.count/4
        let gyroCnt = gyroArray.count/4
        
        for i in 0...accCnt-1{
            let timeStamp = accArray[4 * i]
            let accX = accArray[4 * i + 1]
            let accY = accArray[4 * i + 2]
            let accZ = accArray[4 * i + 3]
            //let accLog = String(format : "27,0,%.4f,%.4f,%.4f,%.4f\n",timeStamp,round(accX * 100000) / 10000,round(accY * 100000) / 10000,round(accZ * 100000) / 10000)
            //logContents = logContents! + "27,0," +  accLog + "\n"
            
//            outputStream!.write(accLog,maxLength: accLog.count)
            
            log_print(log: String(format : "27,0,%.4f,%.4f,%.4f,%.4f\n",timeStamp,round(accX * 100000) / 10000,round(accY * 100000) / 10000,round(accZ * 100000) / 10000))
        }
        
        for i in 0...gyroCnt-1{
            let timeStamp = gyroArray[ 4 * i]
            let gyroX = gyroArray[ 4 * i + 1]
            let gyroY = gyroArray[ 4 * i + 2]
            let gyroZ = gyroArray[ 4 * i + 3]
            //let gyroLog = String(format : "27,1,%.4f,%.4f,%.4f,%.4f\n",timeStamp,gyroX,gyroY,gyroZ)
            //logContents = logContents! + "27,1," +  gyroLog + "\n"
            //outputStream!.write(gyroLog,maxLength: gyroLog.count)
            log_print(log: String(format : "27,1,%.4f,%.4f,%.4f,%.4f\n",timeStamp,gyroX,gyroY,gyroZ))
        }
    }
    
    func PositioningEngineOn (){
        
        while(PositioningEngine! > 0)
        {

            sleep(1)

            if(locationUpdateFlag!){
                
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
            
            
            // Sensor Engine Operation
            print("Positioning Engine Running")
            
            
            if(locationUpdateCnt! > 0){
                var accShow : [Double] = [0,0,0]
                var accVarShow : [Double] = [0,0,0]
                var hdgRateShowValue : Double = 0
                
                var gyroShow : [Double] = [0,0,0]
                var gyroVarShow : [Double] = [0,0,0]
                
                let accArrayCnt = self.accArray.count/4
                let gyroArrayCnt = self.gyroArray.count/4
                
                loggingAccGyro()
                
                accAvgVarCalulate()
                gyroAvgVarCaluate()
                
                checkStaticDetection()
                
                if(staticDetectionStatus == 1) { // static case, then calculate and store the each bias.
                    for i in 0...2{
                        if(staticCnt == 0 ){
                            accBiasDouble[i] = accAvgDouble[i]
                            gyroBiasDouble[i] = gyroAvgDouble[i]
                        }
                        else{
                            accBiasDouble[i] = 0.8 * accBiasDouble[i] + 0.2 * accAvgDouble[i]
                            gyroBiasDouble[i] = 0.8 * gyroAvgDouble[i] + 0.2 * gyroAvgDouble[i]
                        }
                    }
                    staticCnt += 1
                    computeAttitude()
                    
                }
                else{
                    updateAttitude()
                }
                
                //                computeAttitude()
                computeHdgRate()
                hdgRateShowValue = round(headingRate * r2d * 10) / 10
                
                if(staticCnt>5){
                    computeAccXYZ()
                }
                

                
                if(abs(headingRate * r2d) < 0.5)
                {
                    // 1) Pile the value acceleration of each axis.
                    // 2) if some of the value would be over threshold, then compute ratio of x/y
                    // 3) it could be yaw(misalignment) value.
                }

                
                
                for i in 0...2{
                    accShow[i] = round(accAvgDouble[i] * 100) / 100
                    if(staticCnt > 5 ){
                        accShow[i] = round(accXYZ[i] * 100 ) / 100
                    }
                    accVarShow[i] = round(accVarDouble[i] * 100000) / 100000
                    gyroShow[i] = round(gyroAvgDouble[i] * 10000) / 10000
                    gyroVarShow[i] = round(gyroVarDouble[i] * 10000) / 10000
                }
                
                DispatchQueue.main.async {
                    self.accShow.text = "\(accArrayCnt))_\(accShow[0]),__\(accShow[1]),__\(accShow[2])"
                    self.gyroShow.text = "\(gyroArrayCnt))_\(gyroShow[0]),__\(gyroShow[1]),__\(gyroShow[2])"
                    
                    self.accVarShow.text = "\(accVarShow[0]),__\(accVarShow[1]),__\(accVarShow[2])"
                    self.gyroVarShow.text = "\(gyroVarShow[0]),__\(gyroVarShow[1]),__\(gyroVarShow[2])"
                    
                    if (self.staticDetectionStatus == 1){
                        self.staticDetectionStatusShow.text = "Static"
                    }else if(self.staticDetectionStatus == 2){
                        self.staticDetectionStatusShow.text = "Dynamic wo static"
                    }else if(self.staticDetectionStatus == 3){
                        self.staticDetectionStatusShow.text = "Dynamic w static"
                    }
                    
                    self.rollShow.text = "\(round(self.roll * r2d * 10)/10 )"
                    self.pitchShow.text = "\(round(self.pitch * r2d * 10)/10 )"
                    
                    if(self.yawSetCnt > 5){
                        self.yawShow.text = "\(round(self.yaw * r2d * 10)/10)"
                    }
                    
                    self.hdgRateShow.text = "\(hdgRateShowValue)"
                    
                }
               
                //Initialize acc,gyro Buffer
                accArray  = []
                accAvgDouble = [0,0,0]
                accVarDouble = [0,0,0]
                
                gyroArray = []
                gyroAvgDouble = [0,0,0]
                gyroVarDouble = [0,0,0]
            }
            
        }
        
        // Terminate and Reset all related variable
        DispatchQueue.main.async {
            self.staticDetectionStatusShow.text = "Init"
        }
        staticDetectionStatus = 0
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
        lock.lock(); defer {lock.unlock()}
        PositioningEngine = 0
        staticDetectionStatus = 0
        staticCnt = 0
        roll = 0
        pitch = 0
        
        accSumXY = [0,0,0]
        
        
    }
    
}

