//
//  PluginSecretStore.swift
//  ActivateDock
//
//  Stores sensitive plugin values locally without Keychain prompts.
//  The encryption key is app-local, so this protects against casual
//  plaintext inspection rather than replacing OS-level credential storage.
//

import CryptoKit
import Foundation

enum PluginSecretStore {
    private static let valuesKey = "PluginSecretOverridesEncrypted"
    private static let keyKey = "PluginSecretEncryptionKey"

    static func read(account: String) -> String? {
        guard let blob = encryptedValues()[account] else { return nil }
        return decrypt(blob)
    }

    static func write(_ value: String, account: String) {
        guard let blob = encrypt(value) else { return }
        var values = encryptedValues()
        values[account] = blob
        save(values)
    }

    static func delete(account: String) {
        var values = encryptedValues()
        values.removeValue(forKey: account)
        save(values)
    }

    private static func encryptedValues() -> [String: String] {
        guard let data = UserDefaults.standard.data(forKey: valuesKey),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private static func save(_ values: [String: String]) {
        guard let data = try? JSONEncoder().encode(values) else { return }
        UserDefaults.standard.set(data, forKey: valuesKey)
    }

    private static func encrypt(_ value: String) -> String? {
        guard let data = value.data(using: .utf8),
              let sealed = try? AES.GCM.seal(data, using: symmetricKey()),
              let combined = sealed.combined else { return nil }
        return combined.base64EncodedString()
    }

    private static func decrypt(_ blob: String) -> String? {
        guard let data = Data(base64Encoded: blob),
              let sealed = try? AES.GCM.SealedBox(combined: data),
              let opened = try? AES.GCM.open(sealed, using: symmetricKey()) else {
            return nil
        }
        return String(data: opened, encoding: .utf8)
    }

    private static func symmetricKey() -> SymmetricKey {
        if let stored = UserDefaults.standard.string(forKey: keyKey),
           let data = Data(base64Encoded: stored),
           data.count == 32 {
            return SymmetricKey(data: data)
        }

        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let data = Data(bytes)
        UserDefaults.standard.set(data.base64EncodedString(), forKey: keyKey)
        return SymmetricKey(data: data)
    }
}
