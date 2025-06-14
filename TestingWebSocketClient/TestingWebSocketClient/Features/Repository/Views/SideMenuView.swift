//
//  SideMenuView.swift
//  TestingWebSocketClient
//
//  Created by Tornike Gomareli on 06.06.25.
//

import SwiftUI

struct SideMenuView: View {
  let repositoryViewModel: RepositoryViewModel
  @Binding var isShowing: Bool
  
  var body: some View {
    ZStack {
      if isShowing {
        Color.black
          .opacity(0.3)
          .ignoresSafeArea()
          .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
              isShowing = false
            }
          }
        
        HStack {
          VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
              Text("Repositories")
                .font(.largeTitle)
                .fontWeight(.bold)
              
              if let selected = repositoryViewModel.selectedRepository {
                VStack(alignment: .leading, spacing: 4) {
                  Text("Selected:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                  Text(selected.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                }
                .padding(.top, 8)
              }
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            
            Divider()
            
            if repositoryViewModel.repositories.isEmpty {
              VStack(spacing: 16) {
                Image(systemName: "folder.badge.questionmark")
                  .font(.system(size: 48))
                  .foregroundColor(.secondary)
                
                Text("No repositories found")
                  .font(.headline)
                  .foregroundColor(.secondary)
                
                Text("Make sure REPO_PATHS is configured on the server")
                  .font(.caption)
                  .foregroundColor(.secondary)
                  .multilineTextAlignment(.center)
                  .padding(.horizontal)
              }
              .frame(maxWidth: .infinity, maxHeight: .infinity)
              .padding()
            } else {
              ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                  ForEach(repositoryViewModel.repositories) { repo in
                    RepositoryRow(
                      repository: repo,
                      isSelected: repositoryViewModel.selectedRepository?.id == repo.id,
                      onTap: {
                        selectRepository(repo)
                      }
                    )
                  }
                }
              }
            }
            
            Spacer()
            
            // Footer
            Divider()
            
            Button(action: refreshRepositories) {
              Label("Refresh Repositories", systemImage: "arrow.clockwise")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .foregroundColor(.blue)
          }
          .frame(width: UIScreen.main.bounds.width * 0.8)
          .background(Color(UIColor.systemBackground))
          .transition(.move(edge: .leading))
          
          Spacer()
        }
        .ignoresSafeArea()
      }
    }
    .animation(.easeInOut(duration: 0.3), value: isShowing)
  }
  
  private func selectRepository(_ repository: Repository) {
    repositoryViewModel.selectRepository(repository)
  }
  
  private func refreshRepositories() {
    repositoryViewModel.refreshRepositories()
  }
}
