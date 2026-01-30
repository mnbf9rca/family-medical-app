// swiftlint:disable all
import Foundation

// Depending on the consumer's build setup, the low-level FFI code
// might be in a separate module, or it might be compiled inline into
// this module. This is a bit of light hackery to work with both.
#if canImport(opaque_swiftFFI)
import opaque_swiftFFI
#endif

private extension RustBuffer {
    /// Allocate a new buffer, copying the contents of a `UInt8` array.
    init(bytes: [UInt8]) {
        let rbuf = bytes.withUnsafeBufferPointer { ptr in
            RustBuffer.from(ptr)
        }
        self.init(capacity: rbuf.capacity, len: rbuf.len, data: rbuf.data)
    }

    static func empty() -> RustBuffer {
        RustBuffer(capacity: 0, len: 0, data: nil)
    }

    static func from(_ ptr: UnsafeBufferPointer<UInt8>) -> RustBuffer {
        try! rustCall { ffi_opaque_swift_rustbuffer_from_bytes(ForeignBytes(bufferPointer: ptr), $0) }
    }

    /// Frees the buffer in place.
    /// The buffer must not be used after this is called.
    func deallocate() {
        try! rustCall { ffi_opaque_swift_rustbuffer_free(self, $0) }
    }
}

private extension ForeignBytes {
    init(bufferPointer: UnsafeBufferPointer<UInt8>) {
        self.init(len: Int32(bufferPointer.count), data: bufferPointer.baseAddress)
    }
}

// For every type used in the interface, we provide helper methods for conveniently
// lifting and lowering that type from C-compatible data, and for reading and writing
// values of that type in a buffer.

// Helper classes/extensions that don't change.
// Someday, this will be in a library of its own.

private extension Data {
    init(rustBuffer: RustBuffer) {
        self.init(
            bytesNoCopy: rustBuffer.data!,
            count: Int(rustBuffer.len),
            deallocator: .none
        )
    }
}

// Define reader functionality.  Normally this would be defined in a class or
// struct, but we use standalone functions instead in order to make external
// types work.
//
// With external types, one swift source file needs to be able to call the read
// method on another source file's FfiConverter, but then what visibility
// should Reader have?
// - If Reader is fileprivate, then this means the read() must also
//   be fileprivate, which doesn't work with external types.
// - If Reader is internal/public, we'll get compile errors since both source
//   files will try define the same type.
//
// Instead, the read() method and these helper functions input a tuple of data

private func createReader(data: Data) -> (data: Data, offset: Data.Index) {
    (data: data, offset: 0)
}

/// Reads an integer at the current offset, in big-endian order, and advances
/// the offset on success. Throws if reading the integer would move the
/// offset past the end of the buffer.
private func readInt<T: FixedWidthInteger>(_ reader: inout (data: Data, offset: Data.Index)) throws -> T {
    let range = reader.offset ..< reader.offset + MemoryLayout<T>.size
    guard reader.data.count >= range.upperBound else {
        throw UniffiInternalError.bufferOverflow
    }
    if T.self == UInt8.self {
        let value = reader.data[reader.offset]
        reader.offset += 1
        return value as! T
    }
    var value: T = 0
    let _ = withUnsafeMutableBytes(of: &value) { reader.data.copyBytes(to: $0, from: range) }
    reader.offset = range.upperBound
    return value.bigEndian
}

/// Reads an arbitrary number of bytes, to be used to read
/// raw bytes, this is useful when lifting strings
private func readBytes(_ reader: inout (data: Data, offset: Data.Index), count: Int) throws -> [UInt8] {
    let range = reader.offset ..< (reader.offset + count)
    guard reader.data.count >= range.upperBound else {
        throw UniffiInternalError.bufferOverflow
    }
    var value = [UInt8](repeating: 0, count: count)
    value.withUnsafeMutableBufferPointer { buffer in
        reader.data.copyBytes(to: buffer, from: range)
    }
    reader.offset = range.upperBound
    return value
}

/// Reads a float at the current offset.
private func readFloat(_ reader: inout (data: Data, offset: Data.Index)) throws -> Float {
    try Float(bitPattern: readInt(&reader))
}

/// Reads a float at the current offset.
private func readDouble(_ reader: inout (data: Data, offset: Data.Index)) throws -> Double {
    try Double(bitPattern: readInt(&reader))
}

/// Indicates if the offset has reached the end of the buffer.
private func hasRemaining(_ reader: (data: Data, offset: Data.Index)) -> Bool {
    reader.offset < reader.data.count
}

// Define writer functionality.  Normally this would be defined in a class or
// struct, but we use standalone functions instead in order to make external
// types work.  See the above discussion on Readers for details.

private func createWriter() -> [UInt8] {
    []
}

private func writeBytes(_ writer: inout [UInt8], _ byteArr: some Sequence<UInt8>) {
    writer.append(contentsOf: byteArr)
}

/// Writes an integer in big-endian order.
///
/// Warning: make sure what you are trying to write
/// is in the correct type!
private func writeInt(_ writer: inout [UInt8], _ value: some FixedWidthInteger) {
    var value = value.bigEndian
    withUnsafeBytes(of: &value) { writer.append(contentsOf: $0) }
}

private func writeFloat(_ writer: inout [UInt8], _ value: Float) {
    writeInt(&writer, value.bitPattern)
}

private func writeDouble(_ writer: inout [UInt8], _ value: Double) {
    writeInt(&writer, value.bitPattern)
}

/// Protocol for types that transfer other types across the FFI. This is
/// analogous to the Rust trait of the same name.
private protocol FfiConverter {
    associatedtype FfiType
    associatedtype SwiftType

    static func lift(_ value: FfiType) throws -> SwiftType
    static func lower(_ value: SwiftType) -> FfiType
    static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> SwiftType
    static func write(_ value: SwiftType, into buf: inout [UInt8])
}

/// Types conforming to `Primitive` pass themselves directly over the FFI.
private protocol FfiConverterPrimitive: FfiConverter where FfiType == SwiftType {}

extension FfiConverterPrimitive {
    #if swift(>=5.8)
    @_documentation(visibility: private)
    #endif
    public static func lift(_ value: FfiType) throws -> SwiftType {
        value
    }

    #if swift(>=5.8)
    @_documentation(visibility: private)
    #endif
    public static func lower(_ value: SwiftType) -> FfiType {
        value
    }
}

/// Types conforming to `FfiConverterRustBuffer` lift and lower into a `RustBuffer`.
/// Used for complex types where it's hard to write a custom lift/lower.
private protocol FfiConverterRustBuffer: FfiConverter where FfiType == RustBuffer {}

extension FfiConverterRustBuffer {
    #if swift(>=5.8)
    @_documentation(visibility: private)
    #endif
    public static func lift(_ buf: RustBuffer) throws -> SwiftType {
        var reader = createReader(data: Data(rustBuffer: buf))
        let value = try read(from: &reader)
        if hasRemaining(reader) {
            throw UniffiInternalError.incompleteData
        }
        buf.deallocate()
        return value
    }

    #if swift(>=5.8)
    @_documentation(visibility: private)
    #endif
    public static func lower(_ value: SwiftType) -> RustBuffer {
        var writer = createWriter()
        write(value, into: &writer)
        return RustBuffer(bytes: writer)
    }
}

/// An error type for FFI errors. These errors occur at the UniFFI level, not
/// the library level.
private enum UniffiInternalError: LocalizedError {
    case bufferOverflow
    case incompleteData
    case unexpectedOptionalTag
    case unexpectedEnumCase
    case unexpectedNullPointer
    case unexpectedRustCallStatusCode
    case unexpectedRustCallError
    case unexpectedStaleHandle
    case rustPanic(_ message: String)

    var errorDescription: String? {
        switch self {
        case .bufferOverflow: "Reading the requested value would read past the end of the buffer"
        case .incompleteData: "The buffer still has data after lifting its containing value"
        case .unexpectedOptionalTag: "Unexpected optional tag; should be 0 or 1"
        case .unexpectedEnumCase: "Raw enum value doesn't match any cases"
        case .unexpectedNullPointer: "Raw pointer value was null"
        case .unexpectedRustCallStatusCode: "Unexpected RustCallStatus code"
        case .unexpectedRustCallError: "CALL_ERROR but no errorClass specified"
        case .unexpectedStaleHandle: "The object in the handle map has been dropped already"
        case let .rustPanic(message): message
        }
    }
}

private extension NSLock {
    func withLock<T>(f: () throws -> T) rethrows -> T {
        self.lock()
        defer { self.unlock() }
        return try f()
    }
}

private let CALL_SUCCESS: Int8 = 0
private let CALL_ERROR: Int8 = 1
private let CALL_UNEXPECTED_ERROR: Int8 = 2
private let CALL_CANCELLED: Int8 = 3

private extension RustCallStatus {
    init() {
        self.init(
            code: CALL_SUCCESS,
            errorBuf: RustBuffer(
                capacity: 0,
                len: 0,
                data: nil
            )
        )
    }
}

private func rustCall<T>(_ callback: (UnsafeMutablePointer<RustCallStatus>) -> T) throws -> T {
    let neverThrow: ((RustBuffer) throws -> Never)? = nil
    return try makeRustCall(callback, errorHandler: neverThrow)
}

private func rustCallWithError<T>(
    _ errorHandler: @escaping (RustBuffer) throws -> some Swift.Error,
    _ callback: (UnsafeMutablePointer<RustCallStatus>) -> T
) throws -> T {
    try makeRustCall(callback, errorHandler: errorHandler)
}

private func makeRustCall<T>(
    _ callback: (UnsafeMutablePointer<RustCallStatus>) -> T,
    errorHandler: ((RustBuffer) throws -> some Swift.Error)?
) throws -> T {
    uniffiEnsureInitialized()
    var callStatus = RustCallStatus()
    let returnedVal = callback(&callStatus)
    try uniffiCheckCallStatus(callStatus: callStatus, errorHandler: errorHandler)
    return returnedVal
}

private func uniffiCheckCallStatus(
    callStatus: RustCallStatus,
    errorHandler: ((RustBuffer) throws -> some Swift.Error)?
) throws {
    switch callStatus.code {
    case CALL_SUCCESS:
        return

    case CALL_ERROR:
        if let errorHandler = errorHandler {
            throw try errorHandler(callStatus.errorBuf)
        } else {
            callStatus.errorBuf.deallocate()
            throw UniffiInternalError.unexpectedRustCallError
        }

    case CALL_UNEXPECTED_ERROR:
        // When the rust code sees a panic, it tries to construct a RustBuffer
        // with the message.  But if that code panics, then it just sends back
        // an empty buffer.
        if callStatus.errorBuf.len > 0 {
            throw try UniffiInternalError.rustPanic(FfiConverterString.lift(callStatus.errorBuf))
        } else {
            callStatus.errorBuf.deallocate()
            throw UniffiInternalError.rustPanic("Rust panic")
        }

    case CALL_CANCELLED:
        fatalError("Cancellation not supported yet")

    default:
        throw UniffiInternalError.unexpectedRustCallStatusCode
    }
}

private func uniffiTraitInterfaceCall<T>(
    callStatus: UnsafeMutablePointer<RustCallStatus>,
    makeCall: () throws -> T,
    writeReturn: (T) -> Void
) {
    do {
        try writeReturn(makeCall())
    } catch {
        callStatus.pointee.code = CALL_UNEXPECTED_ERROR
        callStatus.pointee.errorBuf = FfiConverterString.lower(String(describing: error))
    }
}

private func uniffiTraitInterfaceCallWithError<T, E>(
    callStatus: UnsafeMutablePointer<RustCallStatus>,
    makeCall: () throws -> T,
    writeReturn: (T) -> Void,
    lowerError: (E) -> RustBuffer
) {
    do {
        try writeReturn(makeCall())
    } catch let error as E {
        callStatus.pointee.code = CALL_ERROR
        callStatus.pointee.errorBuf = lowerError(error)
    } catch {
        callStatus.pointee.code = CALL_UNEXPECTED_ERROR
        callStatus.pointee.errorBuf = FfiConverterString.lower(String(describing: error))
    }
}

private class UniffiHandleMap<T> {
    private var map: [UInt64: T] = [:]
    private let lock = NSLock()
    private var currentHandle: UInt64 = 1

    func insert(obj: T) -> UInt64 {
        lock.withLock {
            let handle = currentHandle
            currentHandle += 1
            map[handle] = obj
            return handle
        }
    }

    func get(handle: UInt64) throws -> T {
        try lock.withLock {
            guard let obj = map[handle] else {
                throw UniffiInternalError.unexpectedStaleHandle
            }
            return obj
        }
    }

    @discardableResult
    func remove(handle: UInt64) throws -> T {
        try lock.withLock {
            guard let obj = map.removeValue(forKey: handle) else {
                throw UniffiInternalError.unexpectedStaleHandle
            }
            return obj
        }
    }

    var count: Int {
        map.count
    }
}

// Public interface members begin here.

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
private struct FfiConverterString: FfiConverter {
    typealias SwiftType = String
    typealias FfiType = RustBuffer

    static func lift(_ value: RustBuffer) throws -> String {
        defer {
            value.deallocate()
        }
        if value.data == nil {
            return String()
        }
        let bytes = UnsafeBufferPointer<UInt8>(start: value.data!, count: Int(value.len))
        return String(bytes: bytes, encoding: String.Encoding.utf8)!
    }

    static func lower(_ value: String) -> RustBuffer {
        value.utf8CString.withUnsafeBufferPointer { ptr in
            // The swift string gives us int8_t, we want uint8_t.
            ptr.withMemoryRebound(to: UInt8.self) { ptr in
                // The swift string gives us a trailing null byte, we don't want it.
                let buf = UnsafeBufferPointer(rebasing: ptr.prefix(upTo: ptr.count - 1))
                return RustBuffer.from(buf)
            }
        }
    }

    static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> String {
        let len: Int32 = try readInt(&buf)
        return try String(bytes: readBytes(&buf, count: Int(len)), encoding: String.Encoding.utf8)!
    }

    static func write(_ value: String, into buf: inout [UInt8]) {
        let len = Int32(value.utf8.count)
        writeInt(&buf, len)
        writeBytes(&buf, value.utf8)
    }
}

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
private struct FfiConverterData: FfiConverterRustBuffer {
    typealias SwiftType = Data

    static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> Data {
        let len: Int32 = try readInt(&buf)
        return try Data(readBytes(&buf, count: Int(len)))
    }

    static func write(_ value: Data, into buf: inout [UInt8]) {
        let len = Int32(value.count)
        writeInt(&buf, len)
        writeBytes(&buf, value)
    }
}

/**
 * Client login state wrapper
 */
public protocol ClientLoginProtocol: AnyObject {
    func finish(serverResponse: Data, password: String) throws -> LoginResult

    func getRequest() -> Data
}

/**
 * Client login state wrapper
 */
open class ClientLogin:
ClientLoginProtocol {
    fileprivate let pointer: UnsafeMutableRawPointer!

    // Used to instantiate a [FFIObject] without an actual pointer, for fakes in tests, mostly.
    #if swift(>=5.8)
    @_documentation(visibility: private)
    #endif
    public struct NoPointer {
        public init() {}
    }

    // TODO: We'd like this to be `private` but for Swifty reasons,
    // we can't implement `FfiConverter` without making this `required` and we can't
    // make it `required` without making it `public`.
    public required init(unsafeFromRawPointer pointer: UnsafeMutableRawPointer) {
        self.pointer = pointer
    }

    // This constructor can be used to instantiate a fake object.
    // - Parameter noPointer: Placeholder value so we can have a constructor separate from the default empty one that
    // may be implemented for classes extending [FFIObject].
    //
    // - Warning:
    //     Any object instantiated with this constructor cannot be passed to an actual Rust-backed object. Since there
    //     isn't a backing [Pointer] the FFI lower functions will crash.
    #if swift(>=5.8)
    @_documentation(visibility: private)
    #endif
    public init(noPointer: NoPointer) {
        self.pointer = nil
    }

    #if swift(>=5.8)
    @_documentation(visibility: private)
    #endif
    public func uniffiClonePointer() -> UnsafeMutableRawPointer {
        try! rustCall { uniffi_opaque_swift_fn_clone_clientlogin(self.pointer, $0) }
    }

    // No primary constructor declared for this class.

    deinit {
        guard let pointer = pointer else {
            return
        }

        try! rustCall { uniffi_opaque_swift_fn_free_clientlogin(pointer, $0) }
    }

    public static func start(password: String) throws -> ClientLogin {
        try FfiConverterTypeClientLogin.lift(rustCallWithError(FfiConverterTypeOpaqueError.lift) {
            uniffi_opaque_swift_fn_constructor_clientlogin_start(
                FfiConverterString.lower(password), $0
            )
        })
    }

    open func finish(serverResponse: Data, password: String) throws -> LoginResult {
        try FfiConverterTypeLoginResult.lift(rustCallWithError(FfiConverterTypeOpaqueError.lift) {
            uniffi_opaque_swift_fn_method_clientlogin_finish(
                self.uniffiClonePointer(),
                FfiConverterData.lower(serverResponse),
                FfiConverterString.lower(password),
                $0
            )
        })
    }

    open func getRequest() -> Data {
        try! FfiConverterData.lift(try! rustCall {
            uniffi_opaque_swift_fn_method_clientlogin_get_request(
                self.uniffiClonePointer(),
                $0
            )
        })
    }
}

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public struct FfiConverterTypeClientLogin: FfiConverter {
    typealias FfiType = UnsafeMutableRawPointer
    typealias SwiftType = ClientLogin

    public static func lift(_ pointer: UnsafeMutableRawPointer) throws -> ClientLogin {
        ClientLogin(unsafeFromRawPointer: pointer)
    }

    public static func lower(_ value: ClientLogin) -> UnsafeMutableRawPointer {
        value.uniffiClonePointer()
    }

    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> ClientLogin {
        let v: UInt64 = try readInt(&buf)
        // The Rust code won't compile if a pointer won't fit in a UInt64.
        // We have to go via `UInt` because that's the thing that's the size of a pointer.
        let ptr = UnsafeMutableRawPointer(bitPattern: UInt(truncatingIfNeeded: v))
        if ptr == nil {
            throw UniffiInternalError.unexpectedNullPointer
        }
        return try lift(ptr!)
    }

    public static func write(_ value: ClientLogin, into buf: inout [UInt8]) {
        // This fiddling is because `Int` is the thing that's the same size as a pointer.
        // The Rust code won't compile if a pointer won't fit in a `UInt64`.
        writeInt(&buf, UInt64(bitPattern: Int64(Int(bitPattern: lower(value)))))
    }
}

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeClientLogin_lift(_ pointer: UnsafeMutableRawPointer) throws -> ClientLogin {
    try FfiConverterTypeClientLogin.lift(pointer)
}

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeClientLogin_lower(_ value: ClientLogin) -> UnsafeMutableRawPointer {
    FfiConverterTypeClientLogin.lower(value)
}

/**
 * Client registration state wrapper
 */
public protocol ClientRegistrationProtocol: AnyObject {
    func finish(serverResponse: Data, password: String) throws -> RegistrationResult

    func getRequest() -> Data
}

/**
 * Client registration state wrapper
 */
open class ClientRegistration:
ClientRegistrationProtocol {
    fileprivate let pointer: UnsafeMutableRawPointer!

    // Used to instantiate a [FFIObject] without an actual pointer, for fakes in tests, mostly.
    #if swift(>=5.8)
    @_documentation(visibility: private)
    #endif
    public struct NoPointer {
        public init() {}
    }

    // TODO: We'd like this to be `private` but for Swifty reasons,
    // we can't implement `FfiConverter` without making this `required` and we can't
    // make it `required` without making it `public`.
    public required init(unsafeFromRawPointer pointer: UnsafeMutableRawPointer) {
        self.pointer = pointer
    }

    // This constructor can be used to instantiate a fake object.
    // - Parameter noPointer: Placeholder value so we can have a constructor separate from the default empty one that
    // may be implemented for classes extending [FFIObject].
    //
    // - Warning:
    //     Any object instantiated with this constructor cannot be passed to an actual Rust-backed object. Since there
    //     isn't a backing [Pointer] the FFI lower functions will crash.
    #if swift(>=5.8)
    @_documentation(visibility: private)
    #endif
    public init(noPointer: NoPointer) {
        self.pointer = nil
    }

    #if swift(>=5.8)
    @_documentation(visibility: private)
    #endif
    public func uniffiClonePointer() -> UnsafeMutableRawPointer {
        try! rustCall { uniffi_opaque_swift_fn_clone_clientregistration(self.pointer, $0) }
    }

    // No primary constructor declared for this class.

    deinit {
        guard let pointer = pointer else {
            return
        }

        try! rustCall { uniffi_opaque_swift_fn_free_clientregistration(pointer, $0) }
    }

    public static func start(password: String) throws -> ClientRegistration {
        try FfiConverterTypeClientRegistration.lift(rustCallWithError(FfiConverterTypeOpaqueError.lift) {
            uniffi_opaque_swift_fn_constructor_clientregistration_start(
                FfiConverterString.lower(password), $0
            )
        })
    }

    open func finish(serverResponse: Data, password: String) throws -> RegistrationResult {
        try FfiConverterTypeRegistrationResult.lift(rustCallWithError(FfiConverterTypeOpaqueError.lift) {
            uniffi_opaque_swift_fn_method_clientregistration_finish(
                self.uniffiClonePointer(),
                FfiConverterData.lower(serverResponse),
                FfiConverterString.lower(password),
                $0
            )
        })
    }

    open func getRequest() -> Data {
        try! FfiConverterData.lift(try! rustCall {
            uniffi_opaque_swift_fn_method_clientregistration_get_request(
                self.uniffiClonePointer(),
                $0
            )
        })
    }
}

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public struct FfiConverterTypeClientRegistration: FfiConverter {
    typealias FfiType = UnsafeMutableRawPointer
    typealias SwiftType = ClientRegistration

    public static func lift(_ pointer: UnsafeMutableRawPointer) throws -> ClientRegistration {
        ClientRegistration(unsafeFromRawPointer: pointer)
    }

    public static func lower(_ value: ClientRegistration) -> UnsafeMutableRawPointer {
        value.uniffiClonePointer()
    }

    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> ClientRegistration {
        let v: UInt64 = try readInt(&buf)
        // The Rust code won't compile if a pointer won't fit in a UInt64.
        // We have to go via `UInt` because that's the thing that's the size of a pointer.
        let ptr = UnsafeMutableRawPointer(bitPattern: UInt(truncatingIfNeeded: v))
        if ptr == nil {
            throw UniffiInternalError.unexpectedNullPointer
        }
        return try lift(ptr!)
    }

    public static func write(_ value: ClientRegistration, into buf: inout [UInt8]) {
        // This fiddling is because `Int` is the thing that's the same size as a pointer.
        // The Rust code won't compile if a pointer won't fit in a `UInt64`.
        writeInt(&buf, UInt64(bitPattern: Int64(Int(bitPattern: lower(value)))))
    }
}

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeClientRegistration_lift(_ pointer: UnsafeMutableRawPointer) throws -> ClientRegistration {
    try FfiConverterTypeClientRegistration.lift(pointer)
}

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeClientRegistration_lower(_ value: ClientRegistration) -> UnsafeMutableRawPointer {
    FfiConverterTypeClientRegistration.lower(value)
}

public struct LoginResult {
    public var credentialFinalization: Data
    public var sessionKey: Data
    public var exportKey: Data

    /// Default memberwise initializers are never public by default, so we
    /// declare one manually.
    public init(credentialFinalization: Data, sessionKey: Data, exportKey: Data) {
        self.credentialFinalization = credentialFinalization
        self.sessionKey = sessionKey
        self.exportKey = exportKey
    }
}

extension LoginResult: Equatable, Hashable {
    public static func == (lhs: LoginResult, rhs: LoginResult) -> Bool {
        if lhs.credentialFinalization != rhs.credentialFinalization {
            return false
        }
        if lhs.sessionKey != rhs.sessionKey {
            return false
        }
        if lhs.exportKey != rhs.exportKey {
            return false
        }
        return true
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(credentialFinalization)
        hasher.combine(sessionKey)
        hasher.combine(exportKey)
    }
}

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public struct FfiConverterTypeLoginResult: FfiConverterRustBuffer {
    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> LoginResult {
        try LoginResult(
            credentialFinalization: FfiConverterData.read(from: &buf),
            sessionKey: FfiConverterData.read(from: &buf),
            exportKey: FfiConverterData.read(from: &buf)
        )
    }

    public static func write(_ value: LoginResult, into buf: inout [UInt8]) {
        FfiConverterData.write(value.credentialFinalization, into: &buf)
        FfiConverterData.write(value.sessionKey, into: &buf)
        FfiConverterData.write(value.exportKey, into: &buf)
    }
}

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeLoginResult_lift(_ buf: RustBuffer) throws -> LoginResult {
    try FfiConverterTypeLoginResult.lift(buf)
}

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeLoginResult_lower(_ value: LoginResult) -> RustBuffer {
    FfiConverterTypeLoginResult.lower(value)
}

public struct RegistrationResult {
    public var registrationUpload: Data
    public var exportKey: Data

    /// Default memberwise initializers are never public by default, so we
    /// declare one manually.
    public init(registrationUpload: Data, exportKey: Data) {
        self.registrationUpload = registrationUpload
        self.exportKey = exportKey
    }
}

extension RegistrationResult: Equatable, Hashable {
    public static func == (lhs: RegistrationResult, rhs: RegistrationResult) -> Bool {
        if lhs.registrationUpload != rhs.registrationUpload {
            return false
        }
        if lhs.exportKey != rhs.exportKey {
            return false
        }
        return true
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(registrationUpload)
        hasher.combine(exportKey)
    }
}

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public struct FfiConverterTypeRegistrationResult: FfiConverterRustBuffer {
    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> RegistrationResult {
        try RegistrationResult(
            registrationUpload: FfiConverterData.read(from: &buf),
            exportKey: FfiConverterData.read(from: &buf)
        )
    }

    public static func write(_ value: RegistrationResult, into buf: inout [UInt8]) {
        FfiConverterData.write(value.registrationUpload, into: &buf)
        FfiConverterData.write(value.exportKey, into: &buf)
    }
}

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeRegistrationResult_lift(_ buf: RustBuffer) throws -> RegistrationResult {
    try FfiConverterTypeRegistrationResult.lift(buf)
}

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeRegistrationResult_lower(_ value: RegistrationResult) -> RustBuffer {
    FfiConverterTypeRegistrationResult.lower(value)
}

public enum OpaqueError {
    case ProtocolError
    case InvalidInput
    case SerializationError
}

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public struct FfiConverterTypeOpaqueError: FfiConverterRustBuffer {
    typealias SwiftType = OpaqueError

    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> OpaqueError {
        let variant: Int32 = try readInt(&buf)
        switch variant {
        case 1: return .ProtocolError
        case 2: return .InvalidInput
        case 3: return .SerializationError
        default: throw UniffiInternalError.unexpectedEnumCase
        }
    }

    public static func write(_ value: OpaqueError, into buf: inout [UInt8]) {
        switch value {
        case .ProtocolError:
            writeInt(&buf, Int32(1))

        case .InvalidInput:
            writeInt(&buf, Int32(2))

        case .SerializationError:
            writeInt(&buf, Int32(3))
        }
    }
}

extension OpaqueError: Equatable, Hashable {}

extension OpaqueError: Foundation.LocalizedError {
    public var errorDescription: String? {
        String(reflecting: self)
    }
}

/**
 * Generate client identifier from username (SHA256 hash with app salt)
 */
public func generateClientIdentifier(username: String) throws -> String {
    try FfiConverterString.lift(rustCallWithError(FfiConverterTypeOpaqueError.lift) {
        uniffi_opaque_swift_fn_func_generate_client_identifier(
            FfiConverterString.lower(username), $0
        )
    })
}

private enum InitializationResult {
    case ok
    case contractVersionMismatch
    case apiChecksumMismatch
}

/// Use a global variable to perform the versioning checks. Swift ensures that
/// the code inside is only computed once.
private var initializationResult: InitializationResult = {
    // Get the bindings contract version from our ComponentInterface
    let bindings_contract_version = 26
    // Get the scaffolding contract version by calling the into the dylib
    let scaffolding_contract_version = ffi_opaque_swift_uniffi_contract_version()
    if bindings_contract_version != scaffolding_contract_version {
        return InitializationResult.contractVersionMismatch
    }
    if uniffi_opaque_swift_checksum_func_generate_client_identifier() != 57_014 {
        return InitializationResult.apiChecksumMismatch
    }
    if uniffi_opaque_swift_checksum_method_clientlogin_finish() != 43_646 {
        return InitializationResult.apiChecksumMismatch
    }
    if uniffi_opaque_swift_checksum_method_clientlogin_get_request() != 18_869 {
        return InitializationResult.apiChecksumMismatch
    }
    if uniffi_opaque_swift_checksum_method_clientregistration_finish() != 55_546 {
        return InitializationResult.apiChecksumMismatch
    }
    if uniffi_opaque_swift_checksum_method_clientregistration_get_request() != 1_373 {
        return InitializationResult.apiChecksumMismatch
    }
    if uniffi_opaque_swift_checksum_constructor_clientlogin_start() != 46_105 {
        return InitializationResult.apiChecksumMismatch
    }
    if uniffi_opaque_swift_checksum_constructor_clientregistration_start() != 14_741 {
        return InitializationResult.apiChecksumMismatch
    }

    return InitializationResult.ok
}()

private func uniffiEnsureInitialized() {
    switch initializationResult {
    case .ok:
        break
    case .contractVersionMismatch:
        fatalError("UniFFI contract version mismatch: try cleaning and rebuilding your project")
    case .apiChecksumMismatch:
        fatalError("UniFFI API checksum mismatch: try cleaning and rebuilding your project")
    }
}

// swiftlint:enable all
