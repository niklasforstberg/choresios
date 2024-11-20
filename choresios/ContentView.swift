//
//  ContentView.swift
//  choresios
//
//  Created by Niklas Förstberg on 2024-11-19.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    
    var body: some View {
        if viewModel.isLoggedIn {
            ChoreSelectionView(viewModel: viewModel)
        } else {
            LoginView(viewModel: viewModel)
        }
    }
}

struct LoginView: View {
    @ObservedObject var viewModel: ContentViewModel
    @State private var email = ""
    @State private var password = ""
    
    var body: some View {
        VStack {
            TextField("Email", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
            
            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Button("Login") {
                Task {
                    await viewModel.login(email: email, password: password)
                }
            }
            .padding()
            
            if let error = viewModel.error {
                Text(error)
                    .foregroundColor(.red)
            }
        }
        .padding()
    }
}

struct ChoreSelectionView: View {
    @ObservedObject var viewModel: ContentViewModel
    
    var body: some View {
        VStack {
            if let selectedUser = viewModel.selectedUser {
                Text("Selected User: \(selectedUser.firstName ?? "") \(selectedUser.lastName ?? "")")
            }
            
            if let selectedChore = viewModel.selectedChore {
                Text("Selected Chore: \(selectedChore.name ?? "")")
            }
            
            List(viewModel.familyMembers, id: \.id) { user in
                Text("\(user.firstName ?? "") \(user.lastName ?? "")")
                    .onTapGesture {
                        viewModel.selectedUser = user
                    }
            }
            
            List(viewModel.chores, id: \.id) { chore in
                Text(chore.name ?? "")
                    .onTapGesture {
                        viewModel.selectedChore = chore
                    }
            }
            
            Button("Submit") {
                Task {
                    await viewModel.submitChoreLog()
                }
            }
            .disabled(viewModel.selectedUser == nil || viewModel.selectedChore == nil)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
