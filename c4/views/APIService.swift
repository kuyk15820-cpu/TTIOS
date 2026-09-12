import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL ไม่ถูกต้อง"
        case .networkError(let error):
            return "เกิดข้อผิดพลาดในการเชื่อมต่อ: \(error.localizedDescription)"
        case .invalidResponse:
            return "ได้รับการตอบกลับที่ไม่ถูกต้องจากเซิร์ฟเวอร์"
        case .serverError(let message):
            return message
        }
    }
}

class APIService {
    static let shared = APIService()
    
    // ⚠️ เปลี่ยน URL ตรงนี้ให้ตรงกับ Domain/Host จริงของคุณ
    private let baseURL = "https://thsv7.hostatom.com" 
    
    private init() {}
    
    // MARK: - Helper Request Methods
    private func performRequest<T: Decodable>(endpoint: String, method: String = "GET", bodyParams: [String: Any]? = nil) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        if let bodyParams = bodyParams {
            if method == "POST" {
                // แปลงเป็น x-www-form-urlencoded เพื่อให้ตรงตาม PHP Backend ($_POST)
                let bodyString = bodyParams.map { "\($0.key)=\("\($0.value)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&")
                request.httpBody = bodyString.data(using: .utf8)
                request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            }
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    // MARK: - Dashboard Stats
    func getDashboardStats() async throws -> DashboardStats {
        struct Response: Codable {
            let status: Bool
            let data: DashboardStats?
            let message: String?
        }
        let res: Response = try await performRequest(endpoint: "/index.php")
        if res.status, let stats = res.data {
            return stats
        }
        throw APIError.serverError(res.message ?? "ไม่สามารถดึงข้อมูลสถิติได้")
    }

    // MARK: - Projects / Packages API
    func getProjects(tab: String) async throws -> [Project] {
        struct Response: Codable {
            let status: Bool
            let data: [Project]?
            let message: String?
        }
        let res: Response = try await performRequest(endpoint: "/package.php?action=list&tab=\(tab)")
        if res.status, let projects = res.data {
            return projects
        }
        return []
    }

    func createProject(name: String, contact: String) async throws -> Bool {
        struct Response: Codable {
            let status: Bool
            let message: String?
        }
        let params: [String: Any] = ["action": "create", "name": name, "contact_link": contact]
        let res: Response = try await performRequest(endpoint: "/package.php", method: "POST", bodyParams: params)
        if !res.status { throw APIError.serverError(res.message ?? "ไม่สามารถสร้าง Package ได้") }
        return res.status
    }

    func updateProject(id: Int, name: String, contact: String) async throws -> Bool {
        struct Response: Codable {
            let status: Bool
            let message: String?
        }
        let params: [String: Any] = ["action": "edit", "id": id, "name": name, "contact_link": contact]
        let res: Response = try await performRequest(endpoint: "/package.php", method: "POST", bodyParams: params)
        if !res.status { throw APIError.serverError(res.message ?? "ไม่สามารถแก้ไข Package ได้") }
        return res.status
    }

    func toggleProjectMaintenance(id: Int, isMaintenance: Bool) async throws -> Bool {
        struct Response: Codable {
            let status: Bool
            let message: String?
        }
        let params: [String: Any] = ["action": "toggle_maint", "id": id, "status": isMaintenance ? 1 : 0]
        let res: Response = try await performRequest(endpoint: "/package.php", method: "POST", bodyParams: params)
        return res.status
    }

    func deleteProject(id: Int) async throws -> Bool {
        struct Response: Codable {
            let status: Bool
            let message: String?
        }
        let params: [String: Any] = ["action": "delete", "id": id]
        let res: Response = try await performRequest(endpoint: "/package.php", method: "POST", bodyParams: params)
        return res.status
    }

    func restoreProject(id: Int) async throws -> Bool {
        struct Response: Codable {
            let status: Bool
            let message: String?
        }
        let params: [String: Any] = ["action": "restore", "id": id]
        let res: Response = try await performRequest(endpoint: "/package.php", method: "POST", bodyParams: params)
        return res.status
    }

    func executeProjectBulkAction(action: String, ids: [Int], currentTab: String) async throws -> Bool {
        struct Response: Codable {
            let status: Bool
            let message: String?
        }
        let idsString = ids.map { String($0) }.joined(separator: ",")
        let params: [String: Any] = ["action": "bulk_action", "bulk_type": action, "ids": idsString, "tab": currentTab]
        let res: Response = try await performRequest(endpoint: "/package.php", method: "POST", bodyParams: params)
        return res.status
    }

    func clearProjectsInTab(tab: String) async throws -> Bool {
        struct Response: Codable {
            let status: Bool
            let message: String?
        }
        let params: [String: Any] = ["action": "clear_tab", "tab": tab]
        let res: Response = try await performRequest(endpoint: "/package.php", method: "POST", bodyParams: params)
        return res.status
    }

    // MARK: - License Keys API
    func getKeys(tab: String) async throws -> [LicenseKey] {
        struct Response: Codable {
            let status: Bool
            let data: [LicenseKey]?
            let message: String?
        }
        let res: Response = try await performRequest(endpoint: "/key.php?action=list&tab=\(tab)")
        if res.status, let keys = res.data {
            return keys
        }
        return []
    }

    func createKey(
        projectId: Int,
        prefixType: String,
        customPrefix: String?,
        type: String,
        maxDevices: Int,
        staticDate: String?,
        durationNum: Int,
        durationUnit: String
    ) async throws -> Bool {
        struct Response: Codable {
            let status: Bool
            let message: String?
        }
        var params: [String: Any] = [
            "action": "create",
            "project_id": projectId,
            "prefix_type": prefixType,
            "type": type,
            "max_devices": maxDevices,
            "duration_num": durationNum,
            "duration_unit": durationUnit
        ]
        if let customPrefix = customPrefix { params["custom_prefix"] = customPrefix }
        if let staticDate = staticDate { params["static_date"] = staticDate }

        let res: Response = try await performRequest(endpoint: "/key.php", method: "POST", bodyParams: params)
        if !res.status { throw APIError.serverError(res.message ?? "ไม่สามารถสร้าง Key ได้") }
        return res.status
    }

    func renewKey(id: Int, num: Int, unit: String) async throws -> Bool {
        struct Response: Codable {
            let status: Bool
            let message: String?
        }
        let params: [String: Any] = ["action": "renew", "id": id, "num": num, "unit": unit]
        let res: Response = try await performRequest(endpoint: "/key.php", method: "POST", bodyParams: params)
        return res.status
    }

    func resetDevice(id: Int) async throws -> Bool {
        struct Response: Codable {
            let status: Bool
            let message: String?
        }
        let params: [String: Any] = ["action": "reset_device", "id": id]
        let res: Response = try await performRequest(endpoint: "/key.php", method: "POST", bodyParams: params)
        return res.status
    }

    func resetAllDevices() async throws -> Bool {
        struct Response: Codable {
            let status: Bool
            let message: String?
        }
        let params: [String: Any] = ["action": "reset_all_devices"]
        let res: Response = try await performRequest(endpoint: "/key.php", method: "POST", bodyParams: params)
        return res.status
    }

    func banKey(id: Int, banType: String, hours: Int?, reason: String) async throws -> Bool {
        struct Response: Codable {
            let status: Bool
            let message: String?
        }
        var params: [String: Any] = ["action": "ban", "id": id, "ban_type": banType, "reason": reason]
        if let hours = hours { params["hours"] = hours }

        let res: Response = try await performRequest(endpoint: "/key.php", method: "POST", bodyParams: params)
        return res.status
    }

    func unbanKey(id: Int) async throws -> Bool {
        struct Response: Codable {
            let status: Bool
            let message: String?
        }
        let params: [String: Any] = ["action": "unban", "id": id]
        let res: Response = try await performRequest(endpoint: "/key.php", method: "POST", bodyParams: params)
        return res.status
    }

    func deleteKey(id: Int) async throws -> Bool {
        struct Response: Codable {
            let status: Bool
            let message: String?
        }
        let params: [String: Any] = ["action": "delete", "id": id]
        let res: Response = try await performRequest(endpoint: "/key.php", method: "POST", bodyParams: params)
        return res.status
    }

    func executeKeyBulkAction(action: String, ids: [Int], currentTab: String) async throws -> Bool {
        struct Response: Codable {
            let status: Bool
            let message: String?
        }
        let idsString = ids.map { String($0) }.joined(separator: ",")
        let params: [String: Any] = ["action": "bulk_action", "bulk_type": action, "ids": idsString, "tab": currentTab]
        let res: Response = try await performRequest(endpoint: "/key.php", method: "POST", bodyParams: params)
        return res.status
    }

    func clearKeysInTab(tab: String) async throws -> Bool {
        struct Response: Codable {
            let status: Bool
            let message: String?
        }
        let params: [String: Any] = ["action": "clear_tab", "tab": tab]
        let res: Response = try await performRequest(endpoint: "/key.php", method: "POST", bodyParams: params)
        return res.status
    }
}
