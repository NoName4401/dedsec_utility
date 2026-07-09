package com.Gabe.projectmarcus.project_marcus

import android.bluetooth.*
import android.bluetooth.BluetoothHidDeviceAppSdpSettings
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.util.Log
import androidx.annotation.RequiresApi
import java.util.concurrent.Executor
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import java.util.*
import kotlin.collections.ArrayList
import kotlin.collections.HashMap

@RequiresApi(28)
class BluetoothHidHandler(dartExecutor: DartExecutor) {
    companion object {
        private const val TAG = "BluetoothHidHandler"
        private const val CHANNEL = "dedsec/bluetooth_hid"
        private const val EVENT_CHANNEL = "dedsec/bluetooth_hid_events"

        private fun hexToBytes(hex: String): ByteArray =
            hex.chunked(2).map { it.toInt(16).toByte() }.toByteArray()

        private val HID_KEYBOARD_DESCRIPTOR = hexToBytes(
            "05010906A101050719E029E71500250175019508810295017508810395057501050819012905910295017503910395067508150026FF00050719002AFF008100C0"
        )

        private val HID_KEYCODE_MAP = mapOf(
            'a' to 0x04.toByte(), 'b' to 0x05.toByte(), 'c' to 0x06.toByte(),
            'd' to 0x07.toByte(), 'e' to 0x08.toByte(), 'f' to 0x09.toByte(),
            'g' to 0x0A.toByte(), 'h' to 0x0B.toByte(), 'i' to 0x0C.toByte(),
            'j' to 0x0D.toByte(), 'k' to 0x0E.toByte(), 'l' to 0x0F.toByte(),
            'm' to 0x10.toByte(), 'n' to 0x11.toByte(), 'o' to 0x12.toByte(),
            'p' to 0x13.toByte(), 'q' to 0x14.toByte(), 'r' to 0x15.toByte(),
            's' to 0x16.toByte(), 't' to 0x17.toByte(), 'u' to 0x18.toByte(),
            'v' to 0x19.toByte(), 'w' to 0x1A.toByte(), 'x' to 0x1B.toByte(),
            'y' to 0x1C.toByte(), 'z' to 0x1D.toByte(),
            '1' to 0x1E.toByte(), '2' to 0x1F.toByte(), '3' to 0x20.toByte(),
            '4' to 0x21.toByte(), '5' to 0x22.toByte(), '6' to 0x23.toByte(),
            '7' to 0x24.toByte(), '8' to 0x25.toByte(), '9' to 0x26.toByte(),
            '0' to 0x27.toByte(),
            '\n' to 0x28.toByte(), 0x1B.toInt() to 0x29.toByte(),
            '\b' to 0x2A.toByte(), '\t' to 0x2B.toByte(),
            ' ' to 0x2C.toByte(),
            '-' to 0x2D.toByte(), '=' to 0x2E.toByte(), '[' to 0x2F.toByte(),
            ']' to 0x30.toByte(), '\\' to 0x31.toByte(),
            ';' to 0x33.toByte(), '\'' to 0x34.toByte(),
            '`' to 0x35.toByte(), ',' to 0x36.toByte(), '.' to 0x37.toByte(),
            '/' to 0x38.toByte(),
        )

        private val SHIFT_KEYS = setOf(
            'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
            'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
            '!', '@', '#', '\$', '%', '^', '&', '*', '(', ')', '_', '+',
            '{', '}', '|', ':', '"', '<', '>', '?', '~'
        )

        private val SHIFTED_MAP = mapOf(
            '!' to '1', '@' to '2', '#' to '3', '\$' to '4',
            '%' to '5', '^' to '6', '&' to '7', '*' to '8',
            '(' to '9', ')' to '0', '_' to '-', '+' to '=',
            '{' to '[', '}' to ']', '|' to '\\',
            ':' to ';', '"' to '\'', '<' to ',', '>' to '.',
            '?' to '/', '~' to '`'
        )
    }

    private val methodChannel = MethodChannel(dartExecutor, CHANNEL)
    private val eventChannel = EventChannel(dartExecutor, EVENT_CHANNEL)
    private var eventSink: EventChannel.EventSink? = null
    private var context: Context? = null
    private var bluetoothManager: BluetoothManager? = null
    private var bluetoothAdapter: BluetoothAdapter? = null
    private var hidDeviceProfile: BluetoothHidDevice? = null
    private var hidRegistered = false
    private var bondedDeviceList = mutableListOf<BluetoothDevice>()
    private var discoveredDevices = mutableListOf<BluetoothDevice>()
    private var currentDevice: BluetoothDevice? = null
    private var isScanning = false
    private var isConnecting = false

    private val broadcastReceiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context, intent: Intent) {
            when (intent.action) {
                BluetoothDevice.ACTION_FOUND -> {
                    val device = intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)
                    if (device != null && !discoveredDevices.any { it.address == device.address }) {
                        discoveredDevices.add(device)
                        sendDeviceList()
                    }
                }
                BluetoothDevice.ACTION_BOND_STATE_CHANGED -> {
                    val device = intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)
                    val bondState = intent.getIntExtra(BluetoothDevice.EXTRA_BOND_STATE, BluetoothDevice.ERROR)
                    if (device != null && bondState == BluetoothDevice.BOND_BONDED) {
                        updateBondedList()
                    }
                }
                BluetoothAdapter.ACTION_DISCOVERY_FINISHED -> {
                    isScanning = false
                    sendEvent("scanComplete", null)
                }
            }
        }
    }

    private val hidCallback = object : BluetoothHidDevice.Callback() {
        override fun onAppStatusChanged(device: BluetoothDevice, registered: Boolean) {
            hidRegistered = registered
            sendEvent("appStatus", mapOf("registered" to registered))
        }

        override fun onConnectionStateChanged(device: BluetoothDevice, state: Int) {
            currentDevice = device
            when (state) {
                BluetoothProfile.STATE_CONNECTED -> {
                    isConnecting = false
                    val map = HashMap<String, Any?>()
                    map["deviceName"] = device.name ?: "UNKNOWN"
                    map["deviceAddress"] = device.address ?: ""
                    sendEvent("connected", map)
                }
                BluetoothProfile.STATE_DISCONNECTED -> {
                    sendEvent("disconnected", null)
                }
                BluetoothProfile.STATE_CONNECTING -> {
                    isConnecting = true
                    sendEvent("connecting", null)
                }
            }
        }

        override fun onGetReport(device: BluetoothDevice, type: Byte, id: Byte, bufferSize: Int) {}
        override fun onSetReport(device: BluetoothDevice, type: Byte, id: Byte, data: ByteArray) {}
        override fun onSetProtocol(device: BluetoothDevice, protocol: Byte) {}
        override fun onInterruptData(device: BluetoothDevice, reportId: Byte, data: ByteArray) {}
        override fun onVirtualCableUnplug(device: BluetoothDevice) {}
    }

    private val profileListener = object : BluetoothProfile.ServiceListener {
        override fun onServiceConnected(profile: Int, proxy: BluetoothProfile?) {
            if (proxy is BluetoothHidDevice) {
                hidDeviceProfile = proxy
                sendEvent("profileReady", null)
            }
        }
        override fun onServiceDisconnected(profile: Int) {}
    }

    fun start(context: Context) {
        this.context = context

        methodChannel.setMethodCallHandler { call, result ->
            handleCall(call, result)
        }

        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })

        bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        bluetoothAdapter = bluetoothManager?.adapter

        val filter = IntentFilter().apply {
            addAction(BluetoothDevice.ACTION_FOUND)
            addAction(BluetoothDevice.ACTION_BOND_STATE_CHANGED)
            addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED)
        }
        context.registerReceiver(broadcastReceiver, filter)

        try {
            updateBondedList()
        } catch (_: SecurityException) {
            Log.w(TAG, "BLUETOOTH_PRIVILEGED not granted, bonded list unavailable")
        }
    }

    fun destroy() {
        try {
            context?.unregisterReceiver(broadcastReceiver)
        } catch (_: Exception) {}
        releaseHid()
        bluetoothAdapter?.cancelDiscovery()
        hidDeviceProfile = null
        context = null
    }

    private fun handleCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> initialize(call, result)
            "getState" -> getState(result)
            "discoverDevices" -> discoverDevices(result)
            "stopDiscovery" -> stopDiscovery(result)
            "pairDevice" -> pairDevice(call, result)
            "connectToDevice" -> connectToDevice(call, result)
            "disconnect" -> disconnect(result)
            "sendKeys" -> sendKeys(call, result)
            "release" -> release(result)
            "getBondedDevices" -> getBondedDevices(result)
            else -> result.notImplemented()
        }
    }

    private fun initialize(call: MethodCall, result: MethodChannel.Result) {
        val adapter = bluetoothAdapter ?: run {
            result.error("NO_ADAPTER", "Bluetooth adapter not available", null); return
        }

        if (!adapter.isEnabled) {
            result.error("BT_OFF", "Bluetooth is not enabled", null); return
        }

        try {
            adapter.getProfileProxy(context, profileListener, BluetoothProfile.HID_DEVICE)
            hidDeviceProfile?.registerApp(
                BluetoothHidDeviceAppSdpSettings(
                    "DedSec HID Keyboard",
                    "DedSec Virtual Keyboard",
                    "DedSec",
                    BluetoothHidDevice.SUBCLASS1_KEYBOARD,
                    HID_KEYBOARD_DESCRIPTOR,
                ),
                null,
                null,
                Executor { it.run() },
                hidCallback,
            )
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "HID init failed", e)
            result.error("INIT_FAILED", e.message ?: "HID initialization failed", null)
        }
    }

    private fun getState(result: MethodChannel.Result) {
        val map = HashMap<String, Any?>()
        map["registered"] = hidRegistered
        map["connected"] = currentDevice != null
        map["connecting"] = isConnecting
        map["scanning"] = isScanning
        map["deviceName"] = currentDevice?.name
        map["deviceAddress"] = currentDevice?.address
        map["bondedCount"] = bondedDeviceList.size
        result.success(map)
    }

    private fun discoverDevices(result: MethodChannel.Result) {
        val adapter = bluetoothAdapter
        if (adapter == null) { result.error("NO_ADAPTER", "No Bluetooth adapter", null); return }
        if (!adapter.isEnabled) { result.error("BT_OFF", "Bluetooth off", null); return }

        discoveredDevices.clear()

        if (adapter.isDiscovering) adapter.cancelDiscovery()
        isScanning = true

        try {
            adapter.startDiscovery()
            result.success(true)
        } catch (e: SecurityException) {
            result.error("PERMISSION", "Missing Bluetooth permission: ${e.message}", null)
        }
    }

    private fun stopDiscovery(result: MethodChannel.Result) {
        bluetoothAdapter?.cancelDiscovery()
        isScanning = false
        result.success(true)
    }

    private fun pairDevice(call: MethodCall, result: MethodChannel.Result) {
        val address = call.argument<String>("address") ?: run {
            result.error("NO_ADDRESS", "Device address required", null); return
        }
        val adapter = bluetoothAdapter ?: run {
            result.error("NO_ADAPTER", "No Bluetooth adapter", null); return
        }

        val device = adapter.getRemoteDevice(address)
        if (device == null) { result.error("NO_DEVICE", "Device not found at $address", null); return }

        try {
            device.createBond()
            sendEvent("pairing", mapOf("deviceName" to (device.name ?: address), "deviceAddress" to address))
            result.success(true)
        } catch (e: Exception) {
            result.error("PAIR_FAILED", "Pairing failed: ${e.message}", null)
        }
    }

    private fun connectToDevice(call: MethodCall, result: MethodChannel.Result) {
        val address = call.argument<String>("address") ?: run {
            result.error("NO_ADDRESS", "Device address required", null); return
        }
        val hid = hidDeviceProfile ?: run {
            result.error("NO_HID", "HID profile not initialized", null); return
        }

        val adapter = bluetoothAdapter ?: run {
            result.error("NO_ADAPTER", "No Bluetooth adapter", null); return
        }
        val device = adapter.getRemoteDevice(address)
        if (device == null) { result.error("NO_DEVICE", "Device not found", null); return }

        try {
            hid.connect(device)
            result.success(true)
        } catch (e: Exception) {
            result.error("CONNECT_FAILED", "HID connect failed: ${e.message}", null)
        }
    }

    private fun disconnect(result: MethodChannel.Result) {
        val device = currentDevice ?: run { result.success(false); return }
        try {
            hidDeviceProfile?.disconnect(device)
            currentDevice = null
            result.success(true)
        } catch (e: Exception) {
            result.error("DISCONNECT_FAILED", e.message, null)
        }
    }

    private fun sendKeys(call: MethodCall, result: MethodChannel.Result) {
        val text = call.argument<String>("text") ?: run {
            result.error("NO_TEXT", "Text to type required", null); return
        }
        val device = currentDevice ?: run {
            result.error("NO_DEVICE", "No connected device", null); return
        }
        val hid = hidDeviceProfile ?: run {
            result.error("NO_HID", "HID profile not initialized", null); return
        }

        try {
            for (char in text) {
                val keycode = charToHidKeycode(char)
                val mod = if (keycode.second) 0x02.toByte() else 0x00.toByte()
                val report = byteArrayOf(mod, 0, keycode.first, 0, 0, 0, 0, 0)
                val emptyReport = byteArrayOf(0, 0, 0, 0, 0, 0, 0, 0)

                hid.sendReport(device, 0, report)
                Thread.sleep(10)
                hid.sendReport(device, 0, emptyReport)
                Thread.sleep(15)
            }
            result.success(text.length)
        } catch (e: Exception) {
            result.error("SEND_FAILED", "Keystroke send failed: ${e.message}", null)
        }
    }

    private fun release(result: MethodChannel.Result) {
        releaseHid()
        result.success(true)
    }

    private fun getBondedDevices(result: MethodChannel.Result) {
        updateBondedList()
        val list = bondedDeviceList.map { device ->
            mapOf("name" to (device.name ?: "UNKNOWN"), "address" to device.address)
        }
        result.success(list)
    }

    private fun charToHidKeycode(c: Char): Pair<Byte, Boolean> {
        val shifted = SHIFT_KEYS.contains(c)
        val actualChar = if (shifted) SHIFTED_MAP[c] ?: c.lowercaseChar() else c.lowercaseChar()
        val code = HID_KEYCODE_MAP[actualChar] ?: 0x00.toByte()
        return Pair(code, shifted || c.isUpperCase())
    }

    private fun updateBondedList() {
        bondedDeviceList = try {
            bluetoothAdapter?.bondedDevices?.toMutableList() ?: mutableListOf()
        } catch (_: SecurityException) {
            mutableListOf()
        }
    }

    private fun sendDeviceList() {
        val list = discoveredDevices.map { device ->
            mapOf(
                "name" to (device.name ?: "UNKNOWN"),
                "address" to device.address,
                "bondState" to device.bondState,
            )
        }
        sendEvent("deviceList", list)
    }

    private fun releaseHid() {
        try {
            if (hidRegistered) {
                hidDeviceProfile?.unregisterApp()
                hidRegistered = false
            }
            bluetoothAdapter?.closeProfileProxy(BluetoothProfile.HID_DEVICE, hidDeviceProfile)
        } catch (_: Exception) {}
    }

    private fun sendEvent(type: String, data: Any?) {
        val map = HashMap<String, Any?>()
        map["type"] = type
        map["data"] = data
        eventSink?.success(map)
    }
}
