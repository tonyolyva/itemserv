import CoreData
import SQLite3

extension NSManagedObjectContext {
    func vacuum() {
        guard let coordinator = self.persistentStoreCoordinator else { return }
        for store in coordinator.persistentStores {
            guard let url = store.url else { continue }

            var db: OpaquePointer?
            if sqlite3_open(url.path, &db) == SQLITE_OK {
                if sqlite3_exec(db, "VACUUM;", nil, nil, nil) != SQLITE_OK {
                    let errmsg = String(cString: sqlite3_errmsg(db)!)
                    print("VACUUM error: \(errmsg)")
                }
                sqlite3_close(db)
            }
        }
    }
}
