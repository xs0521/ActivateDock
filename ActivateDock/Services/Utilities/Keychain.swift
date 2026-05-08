//
//  Keychain.swift
//  ActivateDock
//
//  Minimal Security/SecItem wrapper used by PluginConfigStore for
//  sensitive plugin variables. App sandbox is off, so we land in the
//  user's default login keychain without any keychain-access-groups
//  entitlement. Errors are logged + swallowed; this storage is best-
//  effort and the user can always retype a missing secret.
//

import Foundation
import Security

enum Keychain {

    static let service = "zerobytetech.ActivateDock.PluginConfig"

    static func read(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data,
                  let string = String(data: data, encoding: .utf8) else { return nil }
            return string
        case errSecItemNotFound:
            return nil
        default:
            NSLog("[Keychain] read failed for account \(account): OSStatus \(status)")
            return nil
        }
    }

    @discardableResult
    static func write(_ value: String, account: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let updateAttrs: [String: Any] = [
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, updateAttrs as CFDictionary)
        if updateStatus == errSecSuccess { return true }
        if updateStatus != errSecItemNotFound {
            NSLog("[Keychain] update failed for account \(account): OSStatus \(updateStatus)")
            return false
        }

        var addAttrs = query
        addAttrs[kSecValueData as String] = data
        addAttrs[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let addStatus = SecItemAdd(addAttrs as CFDictionary, nil)
        if addStatus == errSecSuccess { return true }
        NSLog("[Keychain] add failed for account \(account): OSStatus \(addStatus)")
        return false
    }

    @discardableResult
    static func delete(account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound { return true }
        NSLog("[Keychain] delete failed for account \(account): OSStatus \(status)")
        return false
    }
}
