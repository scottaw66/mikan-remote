import Foundation
import CoreAudio
import MikanProtocol

/// Wraps the CoreAudio HAL to enumerate output devices, switch the system
/// default output, and notify on live device/selection changes.
final class AudioDeviceController {
    /// Fired (on the main queue) whenever the device list or default output changes.
    var onChange: (() -> Void)?

    private var listenerBlock: AudioObjectPropertyListenerBlock?

    init() {
        installListeners()
    }

    deinit {
        removeListeners()
    }

    // MARK: - Public API

    /// Current output devices and the UID of the default output device.
    func currentState() -> (devices: [AudioDevice], currentDeviceId: String) {
        let devices = outputDevices()
        let currentUID = defaultOutputDeviceID().flatMap { uid(for: $0) } ?? ""
        return (devices, currentUID)
    }

    /// Switch the system default output device to the one with the given UID.
    /// Returns false if no matching device is found or the set call fails.
    @discardableResult
    func setDefaultOutput(uid targetUID: String) -> Bool {
        guard let deviceID = outputDeviceIDs().first(where: { uid(for: $0) == targetUID }) else {
            return false
        }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var id = deviceID
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &id
        )
        return status == noErr
    }

    // MARK: - Enumeration

    private func outputDevices() -> [AudioDevice] {
        outputDeviceIDs().compactMap { id in
            guard let deviceUID = uid(for: id), let name = name(for: id) else { return nil }
            return AudioDevice(id: deviceUID, name: name)
        }
    }

    /// All device IDs that have at least one output stream.
    private func outputDeviceIDs() -> [AudioDeviceID] {
        allDeviceIDs().filter { hasOutputStreams($0) }
    }

    private func allDeviceIDs() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize
        ) == noErr else { return [] }

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        guard count > 0 else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &ids
        ) == noErr else { return [] }
        return ids
    }

    private func hasOutputStreams(_ id: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &dataSize) == noErr else {
            return false
        }
        return dataSize > 0
    }

    private func defaultOutputDeviceID() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioDeviceID(0)
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &deviceID
        )
        return status == noErr ? deviceID : nil
    }

    // MARK: - Per-device string properties

    private func uid(for id: AudioDeviceID) -> String? {
        stringProperty(kAudioDevicePropertyDeviceUID, for: id)
    }

    private func name(for id: AudioDeviceID) -> String? {
        stringProperty(kAudioObjectPropertyName, for: id)
    }

    private func stringProperty(_ selector: AudioObjectPropertySelector, for id: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: CFString = "" as CFString
        var dataSize = UInt32(MemoryLayout<CFString>.size)
        let status = withUnsafeMutablePointer(to: &value) { ptr -> OSStatus in
            AudioObjectGetPropertyData(id, &address, 0, nil, &dataSize, ptr)
        }
        guard status == noErr else { return nil }
        return value as String
    }

    // MARK: - Live update listeners

    private func installListeners() {
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            DispatchQueue.main.async { self?.onChange?() }
        }
        listenerBlock = block

        for selector in [
            kAudioHardwarePropertyDevices,
            kAudioHardwarePropertyDefaultOutputDevice
        ] {
            var address = AudioObjectPropertyAddress(
                mSelector: selector,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectAddPropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject), &address, DispatchQueue.main, block
            )
        }
    }

    private func removeListeners() {
        guard let block = listenerBlock else { return }
        for selector in [
            kAudioHardwarePropertyDevices,
            kAudioHardwarePropertyDefaultOutputDevice
        ] {
            var address = AudioObjectPropertyAddress(
                mSelector: selector,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject), &address, DispatchQueue.main, block
            )
        }
    }
}
