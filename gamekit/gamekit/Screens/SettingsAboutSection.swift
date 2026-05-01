//
//  SettingsAboutSection.swift
//  gamekit
//
//  Extracted 2026-05-01 from SettingsView.swift to keep the host file
//  under the §8.5 hard cap (was 556 LOC). Same precedent as
//  SettingsSyncSection.swift (06-07) and AcknowledgmentsView.swift (05-04).
//
//  Owns the ABOUT card + its support-flow state + MFMailComposeViewController
//  bridge. Surfaces:
//    - Version (mono digits)
//    - Terms of Service (external Link)
//    - Privacy Policy (external Link)
//    - Support (multi-option confirmationDialog → in-app Mail / default mail
//      app / copy email)
//    - Acknowledgments (NavigationLink to AcknowledgmentsView)
//
//  Self-contained: state + modifiers + helpers + MailComposerView all live
//  here; SettingsView.swift just calls `SettingsAboutSection(theme: theme)`.
//

import SwiftUI
import DesignKit
import MessageUI
import UIKit

struct SettingsAboutSection: View {
    let theme: Theme

    @State private var showingSupportOptions = false
    @State private var showingMailComposer = false
    @State private var mailUnavailableMessage: String?
    @State private var copiedConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.l) {
            settingsSectionHeader(theme: theme, String(localized: "ABOUT"))
            DKCard(theme: theme) {
                VStack(spacing: 0) {
                    versionRow
                    divider
                    Link(destination: AppInfo.termsURL) {
                        externalLinkRow(title: String(localized: "Terms of Service"))
                    }
                    .buttonStyle(.plain)
                    divider
                    Link(destination: AppInfo.privacyURL) {
                        externalLinkRow(title: String(localized: "Privacy Policy"))
                    }
                    .buttonStyle(.plain)
                    divider
                    supportRow
                    if copiedConfirmation {
                        Text(String(localized: "Email address copied."))
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colors.accentPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, theme.spacing.s)
                    }
                    divider
                    NavigationLink(destination: AcknowledgmentsView()) {
                        settingsNavRow(
                            theme: theme,
                            title: String(localized: "Acknowledgments")
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .confirmationDialog(
            String(localized: "Contact support"),
            isPresented: $showingSupportOptions,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Apple Mail")) { openInAppMail() }
            Button(String(localized: "Default mail app")) { openDefaultMail() }
            Button(String(localized: "Copy email address")) { copyEmail() }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text(AppInfo.supportEmail)
        }
        .sheet(isPresented: $showingMailComposer) {
            MailComposerView(
                recipient: AppInfo.supportEmail,
                subject: AppInfo.supportSubject,
                body: defaultMailBody()
            )
            .ignoresSafeArea()
        }
        .alert(
            String(localized: "Apple Mail isn't set up"),
            isPresented: Binding(
                get: { mailUnavailableMessage != nil },
                set: { if !$0 { mailUnavailableMessage = nil } }
            )
        ) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(mailUnavailableMessage ?? "")
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(theme.colors.border)
            .frame(height: 1)
    }

    @ViewBuilder
    private var versionRow: some View {
        HStack {
            Text(String(localized: "Version"))
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textPrimary)
            Spacer()
            Text(AppInfo.version)
                .font(theme.typography.monoNumber)
                .monospacedDigit()
                .foregroundStyle(theme.colors.textSecondary)
        }
        .frame(minHeight: 44)
    }

    @ViewBuilder
    private var supportRow: some View {
        Button {
            showingSupportOptions = true
        } label: {
            HStack {
                Text(String(localized: "Support"))
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.textPrimary)
                Spacer()
                Image(systemName: "envelope")
                    .font(.caption)
                    .foregroundStyle(theme.colors.textTertiary)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func externalLinkRow(title: String) -> some View {
        HStack {
            Text(title)
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textPrimary)
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.colors.textTertiary)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    // MARK: - Support actions

    private func openInAppMail() {
        guard MFMailComposeViewController.canSendMail() else {
            mailUnavailableMessage = String(localized: "Add a Mail account in iOS Settings to use the in-app composer, or pick another option.")
            return
        }
        showingMailComposer = true
    }

    private func openDefaultMail() {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = AppInfo.supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: AppInfo.supportSubject),
            URLQueryItem(name: "body", value: defaultMailBody())
        ]
        guard let url = components.url else { return }
        UIApplication.shared.open(url)
    }

    private func copyEmail() {
        UIPasteboard.general.string = AppInfo.supportEmail
        copiedConfirmation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copiedConfirmation = false
        }
    }

    private func defaultMailBody() -> String {
        """


        ---
        \(AppInfo.displayName)
        Version \(AppInfo.version)
        iOS \(UIDevice.current.systemVersion) · \(UIDevice.current.model)
        """
    }
}

// MARK: - MFMailComposeViewController bridge

private struct MailComposerView: UIViewControllerRepresentable {
    let recipient: String
    let subject: String
    let body: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients([recipient])
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            controller.dismiss(animated: true)
        }
    }
}
