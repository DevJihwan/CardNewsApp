        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.pdf],  // ⚠️ FIX: .data 제거하고 PDF만 허용
            asCopy: true
        )