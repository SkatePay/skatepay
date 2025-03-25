//
//  BirthdayView.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 3/24/25.
//

import SwiftUI

struct BirthdayView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    @State private var showingConfirmation = false
    @State private var savedDOB: Date?
    
    // Date range (5-100 years old)
    private var minDate: Date {
        Calendar.current.date(byAdding: .year, value: -100, to: Date()) ?? Date()
    }
    
    private var maxDate: Date {
        Calendar.current.date(byAdding: .year, value: -5, to: Date()) ?? Date()
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 44))
                    .foregroundColor(.blue)
                
                Text("When's your birthday?")
                    .font(.title2.bold())
                
                Text("We use this to personalize your experience")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 40)
            
            // Date Picker
            DatePicker(
                "Date of Birth",
                selection: $dateOfBirth,
                in: minDate...maxDate,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding(.horizontal)
            .labelsHidden()
            
            // Age Verification
            HStack {
                Image(systemName: "checkmark.seal")
                Text("You'll be \(ageFromDOB()) years old")
            }
            .foregroundColor(.secondary)
            
            Spacer()
            
            // Save Button
            Button(action: {
                showingConfirmation = true
            }) {
                Text("Confirm Birthday")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .navigationTitle("Set Birthday")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("") {
                    dismiss()
                }
            }
        }
        .alert("Confirm Birthday", isPresented: $showingConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Confirm", role: .none) {
                savedDOB = dateOfBirth
                
                UserDefaults.standard.set(dateOfBirth, forKey: UserDefaults.Keys.birthday)
                dismiss()
            }
        } message: {
            Text("You entered \(formattedDate(dateOfBirth)).\nYou'll be \(ageFromDOB()) years old.")
        }
    }
    
    private func ageFromDOB() -> Int {
        Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
}
