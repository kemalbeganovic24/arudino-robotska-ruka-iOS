import SwiftUI
import CoreBluetooth
import Combine

// MARK: - Bluetooth Manager (CoreBluetooth / BLE)
class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var isConnected = false
    @Published var statusText = "Not Connected"
    
    private var centralManager: CBCentralManager!
    private var targetPeripheral: CBPeripheral?
    private var txCharacteristic: CBCharacteristic?
    
    // Standardni BLE UUID-ovi za HM-10 / AT-09 Bluetooth module
    private let serviceUUID = CBUUID(string: "FFE0")
    private let characteristicUUID = CBUUID(string: "FFE1")

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func startScanningOrConnect() {
        if centralManager.state == .poweredOn {
            statusText = "Connecting..."
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        } else {
            statusText = "Bluetooth OFF"
        }
    }

    // MARK: - CBCentralManagerDelegate
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state != .poweredOn {
            statusText = "Bluetooth OFF"
            isConnected = false
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let name = peripheral.name, name.contains("HM") || name.contains("BT") || name.contains("BLE") || name.contains("Arduino") {
            connectToPeripheral(peripheral)
        }
    }

    private func connectToPeripheral(_ peripheral: CBPeripheral) {
        targetPeripheral = peripheral
        targetPeripheral?.delegate = self
        centralManager.stopScan()
        centralManager.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        statusText = "Connected"
        isConnected = true
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        statusText = "Not Connected"
        isConnected = false
        txCharacteristic = nil
    }

    // MARK: - CBPeripheralDelegate
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics([characteristicUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.uuid == characteristicUUID {
                txCharacteristic = characteristic
            }
        }
    }

    // Slanje komande ka Arduinu
    func sendData(_ command: String) {
        guard isConnected, let peripheral = targetPeripheral, let characteristic = txCharacteristic else { return }
        if let data = command.data(using: .utf8) {
            peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
        }
    }
}

// MARK: - SwiftUI Glavni Ekran
struct ContentView: View {
    @StateObject private var btManager = BluetoothManager()
    
    // Tajmer za slanje sa Džojstika
    @State private var joystickOffset: CGSize = .zero
    @State private var timer: Timer? = nil

    var body: some View {
        ZStack {
            // Pozadina - Gradijent iz Figme
            LinearGradient(
                gradient: Gradient(colors: [Color.white, Color(red: 0.33, green: 0.51, blue: 0.88)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                Spacer().frame(height: 10)
                
                // PTF Logo / Naslovi
                Text("Mobilna aplikacija Arduino robotska ruka")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.black)
                
                Text("Politehnički fakultet Univerziteta u Zenici")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)

                Spacer().frame(height: 10)

                // Status i Spoji Se dugme
                VStack(spacing: 4) {
                    Text("Status")
                        .font(.system(size: 14))
                        .foregroundColor(.black)
                    
                    Text(btManager.statusText)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(btManager.isConnected ? Color.green : Color.red)
                    
                    Button(action: {
                        btManager.startScanningOrConnect()
                    }) {
                        Text("Spoji se")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Color.white)
                            .cornerRadius(8)
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    }
                }

                Spacer().frame(height: 15)

                // ==================== DŽOJSTIK (FIGMA DIZAJN) ====================
                ZStack {
                    Circle()
                        .fill(Color(red: 0.88, green: 0.88, blue: 0.90))
                        .frame(width: 170, height: 170)

                    // Strelice i OK u sredini
                    VStack {
                        Image(systemName: "triangle.fill").font(.system(size: 12)).foregroundColor(.black)
                        Spacer()
                        HStack {
                            Image(systemName: "triangle.fill").rotationEffect(.degrees(-90)).font(.system(size: 12)).foregroundColor(.black)
                            Spacer()
                            Text("OK").font(.system(size: 11, weight: .bold)).foregroundColor(.black)
                            Spacer()
                            Image(systemName: "triangle.fill").rotationEffect(.degrees(90)).font(.system(size: 12)).foregroundColor(.black)
                        }
                        Spacer()
                        Image(systemName: "triangle.fill").rotationEffect(.degrees(180)).font(.system(size: 12)).foregroundColor(.black)
                    }
                    .frame(width: 120, height: 120)

                    // Pomični krug
                    Circle()
                        .fill(Color(red: 0.25, green: 0.32, blue: 0.71).opacity(0.3))
                        .frame(width: 60, height: 60)
                        .offset(joystickOffset)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let maxRadius: CGFloat = 60
                                    let translation = value.translation
                                    let distance = sqrt(pow(translation.width, 2) + pow(translation.height, 2))
                                    
                                    if distance < maxRadius {
                                        joystickOffset = translation
                                    } else {
                                        let angle = atan2(translation.height, translation.width)
                                        joystickOffset = CGSize(
                                            width: cos(angle) * maxRadius,
                                            height: sin(angle) * maxRadius
                                        )
                                    }
                                    
                                    startJoystickTimer()
                                }
                                .onEnded { _ in
                                    joystickOffset = .zero
                                    stopJoystickTimer()
                                }
                        )
                }

                Spacer().frame(height: 15)

                // ==================== LAKAT DUGMAD ====================
                HStack(spacing: 20) {
                    Button(action: { btManager.sendData("E") }) {
                        Text("Savij lakat")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.black)
                            .frame(width: 120, height: 40)
                            .background(Color.white)
                            .cornerRadius(20)
                    }

                    Button(action: { btManager.sendData("B") }) {
                        Text("Ispruži lakat")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.black)
                            .frame(width: 120, height: 40)
                            .background(Color.white)
                            .cornerRadius(20)
                    }
                }

                Spacer().frame(height: 15)

                // ==================== ŠTIPALJKA (SLIDERI) ====================
                HStack(spacing: 30) {
                    // Zgrabi
                    VStack {
                        Button(action: { btManager.sendData("Z") }) {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.8))
                                .frame(width: 60, height: 110)
                                .overlay(
                                    VStack {
                                        Spacer()
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 50, height: 50)
                                            .shadow(radius: 2)
                                    }
                                    .padding(5)
                                )
                        }
                        Text("Zgrabi")
                            .font(.system(size: 12))
                            .foregroundColor(.black)
                    }

                    // Popusti
                    VStack {
                        Button(action: { btManager.sendData("O") }) {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.8))
                                .frame(width: 60, height: 110)
                                .overlay(
                                    VStack {
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 50, height: 50)
                                            .shadow(radius: 2)
                                        Spacer()
                                    }
                                    .padding(5)
                                )
                        }
                        Text("Popusti")
                            .font(.system(size: 12))
                            .foregroundColor(.black)
                    }
                }

                Spacer()
            }
            .padding()
        }
    }

    // Tajmer za neprekidno slanje komandi sa džojstika
    private func startJoystickTimer() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in
            let deadZone: CGFloat = 15
            
            // Y Osa (Gore / Dole)
            if joystickOffset.height < -deadZone {
                btManager.sendData("U") // GORE
            } else if joystickOffset.height > deadZone {
                btManager.sendData("D") // DOLE
            }
            
            // X Osa (Lijevo / Desno)
            if joystickOffset.width < -deadZone {
                btManager.sendData("L") // LIJEVO
            } else if joystickOffset.width > deadZone {
                btManager.sendData("R") // DESNO
            }
        }
    }

    private func stopJoystickTimer() {
        timer?.invalidate()
        timer = nil
    }
}
