# 📦 itemserv

**itemserv** is an iOS/iPadOS app designed to help you organize, locate, and manage physical items in a warehouse, garage, or storage room. It supports a customizable hierarchy of Rooms → Sectors → Shelves → Boxes → Items, all stored with rich metadata and optional photos.

---

## 🚀 Features

- 📂 **Flexible Hierarchy**: Organize items by Room, Sector, Shelf, and Box.
- 🗃️ **Box Types & Names**: Customizable box names and types (e.g., plastic, cardboard).
- 🖼️ **Image Support**: Attach photos to each item.
- 🔍 **Powerful Filtering**: Search and filter by category, box, room, and more.
- 📦 **"Unboxed" Support**: Manage items not stored in any box.
- 🔄 **Import & Export**: Backup and restore items (JSON + image .zip format).
- 🖨️ **Label Printing**: Compatible with Brother QL-1110NWBC printer.
- 📷 **Barcode Scanning**: Fast item lookup via barcode.

---

## 📱 Requirements

- iOS/iPadOS 17+
- Swift 5.9+
- Xcode 15+
- iCloud enabled (for CloudKit-based sync)

---

## 🛠️ Technologies

- SwiftUI
- SwiftData
- CloudKit
- CoreImage & AVFoundation (for barcode scanning)
- UIKit bridge (for camera/image picker)

---

## 📦 Structure

- `Models/` – SwiftData models: Item, Room, Sector, Shelf, BoxName, BoxType, Category
- `Views/` – SwiftUI views for main interface and admin panels
- `Helpers/` – Utilities for barcode, image handling, printing, etc.
- `ExportImport/` – Zip-based backup and restore logic

---

## 🔐 iCloud / Privacy

All data is stored locally on device and optionally synced with iCloud (CloudKit private database). No data is sent to third parties.

---

## 💡 Future Plans

- Tagging and smart folders
- iCloud sharing (multi-user access)
- AI-based item recognition
- More printer support

---

## 📃 License

This project is licensed under the MIT License. See `LICENSE` for details.

---

## 👨‍💻 Author

Developed by [Your Name]  
GitHub: [github.com/yourusername](https://github.com/tonyolyva)

---

## 📸 Screenshots 
* **export items**: https://github.com/tonyolyva/itemserv/blob/main/Screenshots/export_items.jpeg
* **admin panel**: https://github.com/tonyolyva/itemserv/blob/main/Screenshots/admin_panel.jpeg
* **box linked items expanded**: https://github.com/tonyolyva/itemserv/blob/main/Screenshots/box_linked_items_expanded.jpeg
* **box linked items collapsed**: https://github.com/tonyolyva/itemserv/blob/main/Screenshots/box_linked_items_collapsed.jpeg
* **export categories**: https://github.com/tonyolyva/itemserv/blob/main/Screenshots/export_categories.jpeg
* **box linked items filter**: https://github.com/tonyolyva/itemserv/blob/main/Screenshots/box_linked_items_filter.jpeg
* **import categories**: https://github.com/tonyolyva/itemserv/blob/main/Screenshots/import_categories.jpeg
* **import export_items**: https://github.com/tonyolyva/itemserv/blob/main/Screenshots/import_export_items.jpeg
* **import items_select_multiple_zip**: https://github.com/tonyolyva/itemserv/blob/main/Screenshots/import_items_select_multiple_zip.jpeg
* **items filter**: rooms https://github.com/tonyolyva/itemserv/blob/main/Screenshots/items_filter.jpeg
* **manage_box_names**: https://github.com/tonyolyva/itemserv/blob/main/Screenshots/manage_box_names.jpeg
* **manage_box_types**: https://github.com/tonyolyva/itemserv/blob/main/Screenshots/manage_box_types.jpeg
* **manage_categories**: https://github.com/tonyolyva/itemserv/blob/main/Screenshots/manage_categories.jpeg
* **manage_rooms**: https://github.com/tonyolyva/itemserv/blob/main/Screenshots/manage_rooms.jpeg
* **manage_sectors**: https://github.com/tonyolyva/itemserv/blob/main/Screenshots/manage_sectors.jpeg
* **manage_shelves**: https://github.com/tonyolyva/itemserv/blob/main/Screenshots/manage_shelves.jpeg


