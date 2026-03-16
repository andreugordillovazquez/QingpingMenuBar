import Foundation
import Security

/// Stores Qingping API credentials in the macOS Keychain.
enum CredentialsStore {

    private static let service = "com.andreugordillo.QingpingMenuBar"
    private static let legacyService = "com.qingping.menubar"

    // MARK: - App Key

    static var appKey: String? {
        get { read(account: "appKey") }
        set {
            if let value = newValue {
                save(account: "appKey", value: value)
            } else {
                delete(account: "appKey")
            }
        }
    }

    // MARK: - App Secret

    static var appSecret: String? {
        get { read(account: "appSecret") }
        set {
            if let value = newValue {
                save(account: "appSecret", value: value)
            } else {
                delete(account: "appSecret")
            }
        }
    }

    /// Whether both credentials are present.
    static var hasCredentials: Bool {
        appKey != nil && appSecret != nil
    }

    /// Migrate credentials from the old service name if present.
    static func migrateIfNeeded() {
        guard read(account: "appKey") == nil else { return }

        if let oldKey = read(account: "appKey", service: legacyService),
           let oldSecret = read(account: "appSecret", service: legacyService) {
            save(account: "appKey", value: oldKey)
            save(account: "appSecret", value: oldSecret)
            delete(account: "appKey", service: legacyService)
            delete(account: "appSecret", service: legacyService)
        }
    }

    // MARK: - Keychain Helpers

    @discardableResult
    private static func save(account: String, value: String, service svc: String = service) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        delete(account: account, service: svc)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: svc,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    private static func read(account: String, service svc: String = service) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: svc,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private static func delete(account: String, service svc: String = service) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: svc,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
