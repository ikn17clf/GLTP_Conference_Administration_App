//
//  GoogleSheetsService.swift
//  GLTP-Conference-Administration-App
//
//  Created by 稲村 健太郎 on 2025/07/22.
//

// -----------------------------------------------------------------------------
//
// GoogleSheetsService.swift
// Google Apps ScriptのWebアプリと通信するクラスです。（変更なし）
//
// -----------------------------------------------------------------------------
import Foundation

class GoogleSheetsService {
    
    static let shared = GoogleSheetsService()
    
    private init() {}

    func verifyAndMarkQRCode(qrCode: String, completion: @escaping (Bool, String) -> Void) {
        guard let urlString = getGASAPIURL(),
              let url = URL(string: urlString) else {
            completion(false, "no")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = "qrCode=\(qrCode)".data(using: .utf8)

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error: \(error)")
                completion(false, "no")
                return
            }

            guard let data = data else {
                print("No data received")
                completion(false, "no")
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: String] {
                    let success = json["status"] == "success"
                    let priority = json["priority"] ?? "no"
                    completion(success, priority)
                } else {
                    completion(false, "no")
                }
            } catch {
                print("JSON parse error")
                completion(false, "no")
            }
        }

        task.resume()
    }
    func getGASAPIURL() -> String? {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let url = dict["GAS_API_URL"] as? String else {
            print("⚠️ Config.plist 読み込み失敗")
            return nil
        }
        return url
    }
}
