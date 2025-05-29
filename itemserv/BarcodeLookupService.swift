import Foundation

struct UPCItem: Decodable {
    let title: String?
    let description: String?
    let brand: String?
    let images: [String]?
}

struct UPCItemResponse: Decodable {
    let items: [UPCItem]
}

class BarcodeLookupService {
    static let shared = BarcodeLookupService()

    private let apiHost = "https://api.upcitemdb.com/prod/trial/lookup"

    func lookup(upc: String, isLoading: @escaping (Bool) -> Void, completion: @escaping (UPCItem?) -> Void) {
        guard let url = URL(string: "\(apiHost)?upc=\(upc)") else {
            isLoading(false)
            completion(nil)
            return
        }

        isLoading(true)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        URLSession.shared.dataTask(with: request) { data, response, error in
            isLoading(false)
            guard let data = data else {
                completion(nil)
                return
            }

            do {
                let result = try JSONDecoder().decode(UPCItemResponse.self, from: data)
                completion(result.items.first)
            } catch {
                completion(nil)
            }
        }.resume()
    }
}
