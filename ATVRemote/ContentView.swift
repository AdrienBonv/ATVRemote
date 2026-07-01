//
//  ContentView.swift
//  ATVRemote
//

import SwiftUI
import AndroidTVRemoteControl

struct ContentView: View {
    @StateObject private var tv = TVRemote()
    @State private var code: String = ""

    var body: some View {
        VStack(spacing: 22) {

            // Status header
            VStack(spacing: 4) {
                Text("Android TV Remote").font(.headline)
                Text(tv.status)
                    .font(.caption)
                    .foregroundStyle(tv.isConnected ? .green : .secondary)
            }

            if !tv.isConnected {
                connectSection
            }

            if tv.needsCode {
                codeSection
            }

            Spacer(minLength: 0)

            dpad
                .opacity(tv.isConnected ? 1 : 0.35)
                .disabled(!tv.isConnected)

            bottomRow
                .opacity(tv.isConnected ? 1 : 0.35)
                .disabled(!tv.isConnected)
                .padding(.bottom, 40)
        }
        .padding()
    }

    // MARK: Connect

    private var connectSection: some View {
        VStack(spacing: 12) {
            // Discovered devices
            HStack {
                Text(tv.isScanning ? "Searching for TVs…" : "TVs found")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button { tv.startDiscovery() } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }

            if tv.discovered.isEmpty {
                Text("No TV yet. Make sure it's on and on the same Wi-Fi.")
                    .font(.caption2).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(tv.discovered) { device in
                    Button { tv.select(device) } label: {
                        HStack {
                            Image(systemName: "tv")
                            Text(device.name).lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }

            Divider().padding(.vertical, 2)

            // Manual fallback
            HStack {
                TextField("Or type the IP manually", text: $tv.host)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numbersAndPunctuation)
                    .autocorrectionDisabled()
                Button("Connect") { tv.connect() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .onAppear { tv.startDiscovery() }
    }

    private var codeSection: some View {
        VStack(spacing: 8) {
            Text("Enter the 6-character code shown on your TV")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                TextField("e.g. A1B2C3", text: $code)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
                Button("Pair") { tv.sendCode(code); code = "" }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: D-pad

    private var dpad: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                // Home button top-left
                Button(action: { tv.press(.KEYCODE_HOME) }) {
                    Image(systemName: "house.fill")
                        .font(.title2)
                        .frame(width: 70, height: 70)
                }
                .buttonStyle(.bordered)
                .clipShape(Circle())
                
                padButton("chevron.up") { tv.press(.KEYCODE_DPAD_UP) }
                
                // Power button top-right
                Button(action: { tv.press(.KEYCODE_POWER) }) {
                    Image(systemName: "power")
                        .font(.title2)
                        .frame(width: 70, height: 70)
                }
                .buttonStyle(.bordered)
                .clipShape(Circle())
            }
            HStack(spacing: 14) {
                padButton("chevron.left") { tv.press(.KEYCODE_DPAD_LEFT) }
                Button(action: { tv.press(.KEYCODE_DPAD_CENTER) }) {
                    Text("OK").font(.title3.bold())
                        .frame(width: 78, height: 78)
                }
                .buttonStyle(.borderedProminent)
                .clipShape(Circle())
                padButton("chevron.right") { tv.press(.KEYCODE_DPAD_RIGHT) }
            }
            HStack(spacing: 14) {
                // Back button bottom-left
                Button(action: { tv.press(.KEYCODE_BACK) }) {
                    Image(systemName: "chevron.backward")
                        .font(.title2)
                        .frame(width: 70, height: 70)
                }
                .buttonStyle(.bordered)
                .clipShape(Circle())
                
                padButton("chevron.down") { tv.press(.KEYCODE_DPAD_DOWN) }
                
                // Menu button bottom-right
                Button(action: { tv.press(.KEYCODE_MENU) }) {
                    Image(systemName: "line.3.horizontal")
                        .font(.title2)
                        .frame(width: 70, height: 70)
                }
                .buttonStyle(.bordered)
                .clipShape(Circle())
            }
        }
    }

    private func padButton(_ system: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.title2)
                .frame(width: 70, height: 70)
        }
        .buttonStyle(.bordered)
        .clipShape(Circle())
    }

    // MARK: Bottom controls

    private var bottomRow: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                iconButton("speaker.slash.fill", "Mute") { tv.press(.KEYCODE_MUTE) }
                iconButton("speaker.wave.1.fill", "Vol −") { tv.press(.KEYCODE_VOLUME_DOWN) }
                iconButton("speaker.wave.3.fill", "Vol +") { tv.press(.KEYCODE_VOLUME_UP) }
            }
            iconButton("playpause.fill", "Play") { tv.press(.KEYCODE_MEDIA_PLAY_PAUSE) }
        }
    }

    private func iconButton(_ system: String, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: system).font(.title3)
                Text(label).font(.caption2)
            }
            .frame(width: 64, height: 56)
        }
        .buttonStyle(.bordered)
    }
}

#Preview {
    ContentView()
}
