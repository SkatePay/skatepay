//
//  FilePicker.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 10/7/24.
//

import SwiftUI
import PhotosUI

struct FilePicker: UIViewControllerRepresentable {
    @Binding var selectedMediaURL: URL?
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .any(of: [.images, .videos]) // Allow both images and videos
        config.selectionLimit = 1 // Limit selection to 1 file
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        var parent: FilePicker
        
        init(_ parent: FilePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true, completion: nil)
            
            guard let provider = results.first?.itemProvider else { return }
            
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, error in
                    if let tempURL = url {
                        self.saveFileToDocumentsDirectory(from: tempURL, fileType: "image") { savedURL in
                            DispatchQueue.main.async {
                                self.parent.selectedMediaURL = savedURL
                            }
                        }
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                    if let tempURL = url {
                        self.saveFileToDocumentsDirectory(from: tempURL, fileType: "video") { savedURL in
                            DispatchQueue.main.async {
                                self.parent.selectedMediaURL = savedURL
                            }
                        }
                    }
                }
            }
        }
        
        // Move the file to a permanent location in the documents directory
        func saveFileToDocumentsDirectory(from tempURL: URL, fileType: String, completion: @escaping (URL?) -> Void) {
            let fileManager = FileManager.default
            
            // Get the documents directory
            let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            
            // Generate a unique file name
            let fileName = UUID().uuidString + (fileType == "image" ? ".png" : ".mov")
            let destinationURL = documentsDirectory.appendingPathComponent(fileName)
            
            do {
                // Copy the file from tempURL to the documents directory
                try fileManager.copyItem(at: tempURL, to: destinationURL)
                print("File successfully saved to: \(destinationURL)")
                completion(destinationURL)
            } catch {
                print("Error saving file: \(error)")
                completion(nil)
            }
        }
    }
}
