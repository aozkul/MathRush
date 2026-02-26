//
//  GameView.swift
//  MathRush
//
//  Created by Ali Ozkul on 24.02.26.
//

import SwiftUI
import Combine
import UIKit

struct GameView: View {

    @ObservedObject var vm: GameViewModel
    
    @Environment(\.dismiss) private var dismiss

    private let multiplayer: MultiplayerCoordinator?
    init(vm: GameViewModel, multiplayer: MultiplayerCoordinator? = nil) {
        self.vm = vm
        self.multiplayer = multiplayer
    }

    // tick
    @State private var now = Date()
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    // premium anim states
    @State private var bgBreath = false
    @State private var cardPulse = false
    @State private var shakeWrong = false
    @State private var showFailVignette = false

    // points pop
    @State private var showPointsPop = false
    @State private var pointsText = ""

    // ⭐ BOSS FX (NEW)
    @State private var showBossBanner = false
    @State private var bossFlash = false
    @State private var bossPunch = false
    @State private var showLightning = false
    
    //Combo
    @State private var showComboExplosion = false
    @State private var comboTrigger = 0
    @State private var lastComboValue = 1
    
    // 🔥 Glass crack state (NEW)
    @State private var crackLevel: CGFloat = 0
    @State private var crackSeed: Int = 1
    @State private var crackPunch = false
    @State private var showCrackImpact = false
    @State private var crackImpactSeed = 1
    
    @State private var isShowingRewarded = false

    var body: some View {
        ZStack {
            PremiumArcadeBackground(breath: bgBreath)
            
            if showLightning {
                LightningStrike()
                    .transition(.opacity)
                    .ignoresSafeArea()
            }

            // Fail vignette
            if showFailVignette {
                RadialGradient(colors: [.red.opacity(0.0), .red.opacity(0.35)], center: .center, startRadius: 50, endRadius: 420)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

            // ⭐ Boss gold flash vignette (NEW)
            if bossFlash {
                RadialGradient(
                    colors: [.yellow.opacity(0.0), .yellow.opacity(0.30)],
                    center: .center,
                    startRadius: 60,
                    endRadius: 520
                )
                .ignoresSafeArea()
                .transition(.opacity)
            }

            VStack(spacing: 16) {
                topBar

                Spacer(minLength: 8)

                questionArea

                Spacer(minLength: 10)

                answerButtons

                bottomHint
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 14)

            // ⭐ Boss banner overlay (NEW)
            VStack {
                if showBossBanner {
                    BossBannerView()
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 10)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .allowsHitTesting(false)
            // ✅ Premium centered Game Over overlay
            if vm.isGameOver {
                gameOverOverlay
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(999)
            }
        }

        .onAppear {
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                bgBreath.toggle()
            }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                cardPulse.toggle()
            }

            // start mode
            if let mp = multiplayer {
                mp.bindToGameViewModel(vm)
                // startMultiplayer coordinator tarafından çağrılacak
            } else {
                // ⚠️ Rewarded reklamdan geri dönünce view tekrar onAppear alabiliyor.
                // Burada startSinglePlayer çağırmak skoru sıfırlar.
                // Oyunu sadece ilk kez (problem yoksa) başlat.
                if vm.problem == nil {
                    vm.startSinglePlayer()
                }
            }
        }
        .onReceive(timer) { t in
            now = t
            vm.tick(now: t)
        }
        .onChange(of: vm.lastPointsGained) { _, newValue in
            guard newValue > 0 else { return }
            pointsText = "+\(newValue)"
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                showPointsPop = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.easeOut(duration: 0.2)) {
                    showPointsPop = false
                }
            }
        }
        .onChange(of: vm.comboCount) { _, newCombo in
            // reset
            if newCombo <= 1 {
                crackLevel = 0
                lastComboValue = max(1, newCombo)
                return
            }

            guard newCombo > lastComboValue else { return }
            lastComboValue = newCombo

            // ✅ sadece milestone'larda tetikle (istersen %3 de yapabilirsin)
            let shouldCrack = (newCombo == 3 || newCombo == 6 || newCombo == 10 || newCombo == 15 || newCombo == 21)
            guard shouldCrack else { return }
            
            // 1) önce impact (sebep)
            crackImpactSeed &+= 1
            showCrackImpact = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                showCrackImpact = false
            }

            // 2) sonra çatlağı büyüt
            crackSeed &+= 1

            let comboFactor = min(1.0, CGFloat(newCombo - 2) / 20.0)
            let step = 0.10 + (0.40 * comboFactor)
            crackLevel = min(1.0, crackLevel + step)

            // 3) punch / shake
            withAnimation(.spring(response: 0.22, dampingFraction: 0.45)) {
                crackPunch = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                crackPunch = false
            }

            crackSeed = crackSeed &+ 1
        }
        .onChange(of: vm.feedback) { _, fb in
            guard let fb else { return }
            if fb == .wrong {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                withAnimation(.spring(response: 0.25, dampingFraction: 0.35)) {
                    shakeWrong.toggle()
                }
                withAnimation(.easeIn(duration: 0.12)) {
                    showFailVignette = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeOut(duration: 0.25)) {
                        showFailVignette = false
                    }
                }
            } else {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }

        // ⭐ Boss animation trigger (NEW)
        .onChange(of: vm.isBossQuestion) { _, isBoss in
            guard isBoss else { return }

            // banner
            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                showBossBanner = true
            }

            // flash
            withAnimation(.easeIn(duration: 0.10)) {
                bossFlash = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                withAnimation(.easeOut(duration: 0.25)) {
                    bossFlash = false
                }
            }
            
            //lightning
            withAnimation(.easeOut(duration: 0.15)) {
                showLightning = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                showLightning = false
            }

            // punch
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                bossPunch = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                bossPunch = false
            }

            // hide banner
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.90) {
                withAnimation(.easeOut(duration: 0.20)) {
                    showBossBanner = false
                }
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Top

    private var topBar: some View {
        HStack {
            backButton

            Spacer()

            centerBrand

            Spacer()

            scoreHUD
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 26)
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25), radius: 18, y: 10)
        )
        .padding(.horizontal, 12)
    }

    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
                .frame(width: 42, height: 42)
                .background(.white.opacity(0.08))
                .clipShape(Circle())
        }
    }
    
    private struct LightningStrike: View {

        @State private var flash = false

        var body: some View {
            ZStack {

                LinearGradient(
                    colors: [.white.opacity(flash ? 0.45 : 0.15), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Canvas { ctx, size in
                    var path = Path()

                    let startX = size.width * 0.5
                    var currentY: CGFloat = 0

                    path.move(to: CGPoint(x: startX, y: currentY))

                    while currentY < size.height {
                        let nextX = startX + CGFloat.random(in: -40...40)
                        currentY += CGFloat.random(in: 30...60)
                        path.addLine(to: CGPoint(x: nextX, y: currentY))
                    }

                    ctx.stroke(
                        path,
                        with: .color(.white.opacity(0.9)),
                        lineWidth: 3
                    )
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 0.12).repeatCount(2, autoreverses: true)) {
                    flash.toggle()
                }
            }
        }
    }

    private var scoreHUD: some View {
        HStack(spacing: 10) {

            Image(systemName: "bolt.fill")
                .foregroundColor(.yellow)
                .font(.system(size: 14))

            Text("\(vm.score)")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundColor(.white)

            Text(vm.comboLabel)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.white.opacity(0.12))
                .clipShape(Capsule())
        }
    }

    private var centerBrand: some View {
        VStack(spacing: 4) {

            HStack(spacing: 6) {

                Image(systemName: modeIcon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(modeColor)

                Text(modeTitle)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(modeColor.opacity(0.18))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(modeColor.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: modeColor.opacity(0.4), radius: 6) // ⭐ premium glow
        }
    }
    
    private var modeTitle: String {
        if vm.isBossQuestion { return "Boss Round" }
        if vm.isRushMode { return "Rush Mode" }
        return "Keep Going"
    }

    private var modeIcon: String {
        if vm.isBossQuestion { return "bolt.fill" }
        if vm.isRushMode { return "flame.fill" }
        return "brain.head.profile"
    }

    private var modeColor: Color {
        if vm.isBossQuestion { return .yellow }
        if vm.isRushMode { return .cyan }
        return .white.opacity(0.6)
    }
    
    private func comboValue(from label: String) -> Int {
        // Works for "x3", "×3", "3x", etc.
        let digits = label.filter { $0.isNumber }
        return Int(digits) ?? 1
    }

    // (Sende vardı — dokunmadım, kalsın)
    private var hudBar: some View {
        HStack(spacing: 12) {

            // Back
            Button {
                // dismiss
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.92))
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.10))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))
            }

            // Status pill (RUSH / BOSS / NORMAL)
            HStack(spacing: 8) {
                Circle()
                    .fill(vm.isBossQuestion ? .yellow : (vm.isRushMode ? .cyan : .white.opacity(0.35)))
                    .frame(width: 8, height: 8)

                Text(vm.isBossQuestion ? "BOSS" : (vm.isRushMode ? "RUSH" : "NORMAL"))
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundColor(.white.opacity(0.95))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(.white.opacity(0.08))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.14), lineWidth: 1))

            Spacer()

            // Brand center
            HStack(spacing: 10) {
                Image("app_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(.white.opacity(0.16), lineWidth: 1))

                VStack(alignment: .leading, spacing: 1) {
                    Text("Math Rush")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(.white)

                    Text("Fast • Fun • Focus")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            Spacer()

            // Score + Multiplier (tek blok)
            HStack(spacing: 10) {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.yellow.opacity(0.95))

                Text("\(vm.score)")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)

                Divider()
                    .frame(height: 16)
                    .overlay(.white.opacity(0.18))

                Text(vm.comboLabel)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundColor(.white.opacity(0.95))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.10))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(.white.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.14), lineWidth: 1))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.22), radius: 18, y: 12)
    }

    // (Sende vardı — dokunmadım, kalsın)
    private var multiplayerMiniBar: some View {
        HStack(spacing: 10) {
            Text("You \(vm.score)")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundColor(.white.opacity(0.9))

            GeometryReader { geo in
                let total = max(1, vm.score + vm.opponentScore)
                let your = CGFloat(vm.score) / CGFloat(total)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.white.opacity(0.10))
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.white.opacity(0.28))
                        .frame(width: geo.size.width * your)
                }
            }
            .frame(height: 12)

            Text("\(vm.opponentScore) Opp")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private var brandRow: some View {
        HStack(spacing: 5) {
            Image("app_logo")
                .resizable()
                .scaledToFit()
                .frame(width: 124, height: 124)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(.white.opacity(0.18), lineWidth: 1))
                .shadow(color: .black.opacity(0.25), radius: 10, y: 6)
        }
    }

    // MARK: - Middle

    private var questionArea: some View {
        VStack(spacing: 14) {
            // Timer ring
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.10), lineWidth: 10)
                    .frame(width: 90, height: 90)

                Circle()
                    .trim(from: 0, to: max(0, min(1, Double(vm.timeProgress(now: now)))))
                    .stroke(.white.opacity(0.85), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 90, height: 90)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: vm.isBossQuestion ? .yellow.opacity(0.5) : .white.opacity(0.12),
                            radius: vm.isBossQuestion ? 16 : 10)

                Text("\(Int(ceil(vm.remainingSeconds(now: now))))")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
            }
            .scaleEffect(vm.isRushMode ? (cardPulse ? 1.04 : 0.98) : 1.0)
            .animation(.easeInOut(duration: 0.7), value: cardPulse)

            // Question card
            ZStack {
                Image("app_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 400, height: 400)
                    .opacity(0.06)
                    .blur(radius: 0.5)
                    .allowsHitTesting(false)

                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.white.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(.white.opacity(0.16), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.35), radius: 30, y: 16)

                // subtle neon glow
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                vm.isBossQuestion ? .yellow.opacity(0.22) : .cyan.opacity(0.18),
                                vm.isBossQuestion ? .orange.opacity(0.16) : .purple.opacity(0.14),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.screen)
                    .opacity(bgBreath ? 0.95 : 0.55)
                    .animation(.easeInOut(duration: 1.8), value: bgBreath)

                VStack(spacing: 10) {
                    Text("Is this correct?")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))

                    Text(vm.problem?.question ?? "—")
                        .font(.system(size: 52, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)

                    Text("= \(vm.problem?.shownAnswer ?? 0)")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.92))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 18)
                
                if showCrackImpact {
                    CrackImpactOverlay(
                        cornerRadius: 28,
                        band: 22 + 18 * crackLevel
                    )
                    .transition(.opacity)
                    .zIndex(30)
                }
                
                // 🔥 Glass crack overlay (NEW)
                CrackOverlayView(
                    level: crackLevel,
                    seed: crackSeed,
                    cornerRadius: 28
                )
                .opacity(crackLevel > 0 ? 1 : 0)
                .transition(.opacity)
                
                if showComboExplosion {
                    ComboExplosionView()
                        .id(comboTrigger) // ⭐ her tetikte yeniden yarat
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: 520)
            // ⭐ punch (NEW)
            .scaleEffect(bossPunch ? 1.05 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: bossPunch)
            .scaleEffect(crackPunch ? 1.02 : 1.0)
            .animation(.spring(response: 0.20, dampingFraction: 0.5), value: crackPunch)
            .modifier(ShakeEffect(animatableData: CGFloat(shakeWrong ? 1 : 0)))
        }
    }
    
    private struct ComboExplosionView: View {

        @State private var animate = false

        var body: some View {
            ZStack {
                ForEach(0..<18) { i in
                    Circle()
                        .fill(particleColor(for: i))
                        .frame(width: 8, height: 8)
                        .offset(x: animate ? randomX(i) : 0,
                                y: animate ? randomY(i) : 0)
                        .opacity(animate ? 0 : 1)
                        .scaleEffect(animate ? 0.3 : 1.2)
                        .animation(.easeOut(duration: 0.6), value: animate)
                }
            }
            .onAppear {
                animate = false
                DispatchQueue.main.async {
                    animate = true
                }
            }
        }

        private func randomX(_ index: Int) -> CGFloat { CGFloat.random(in: -120...120) }
        private func randomY(_ index: Int) -> CGFloat { CGFloat.random(in: -120...120) }

        private func particleColor(for index: Int) -> Color {
            let colors: [Color] = [.yellow, .cyan, .orange, .pink, .white]
            return colors[index % colors.count]
        }
    }

    // MARK: - Bottom Buttons

    private var answerButtons: some View {
        HStack(spacing: 34) {
            PremiumRoundActionButton(
                title: "WRONG",
                systemIcon: "xmark",
                style: .danger,
                isEmphasized: vm.isBossQuestion
            ) {
                vm.choose(isCorrectSelected: false)
            }

            ZStack {
                if showPointsPop {
                    Text(pointsText)
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.12))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
                        .offset(y: -52)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(width: 1)

            PremiumRoundActionButton(
                title: "RIGHT",
                systemIcon: "checkmark",
                style: .success,
                isEmphasized: vm.isRushMode
            ) {
                vm.choose(isCorrectSelected: true)
            }
        }
        .padding(.top, 6)
    }

    
    
    private var gameOverOverlay: some View {
        ZStack {
            // dim + vignette
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .overlay(
                    RadialGradient(
                        gradient: Gradient(colors: [Color.black.opacity(0.0), Color.black.opacity(0.65)]),
                        center: .center,
                        startRadius: 40,
                        endRadius: 420
                    )
                    .ignoresSafeArea()
                )

            VStack(spacing: 14) {
                VStack(spacing: 6) {
                    Text("Game Over")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)

                    if vm.isMultiplayer {
                        Text(vm.score >= vm.opponentScore ? "You win 🎉" : "You lose 😅")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.75))
                    } else {
                        Text("Try again and beat your best!")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.75))
                    }
                }

                HStack(spacing: 10) {
                    statPill(title: "Score", value: "\(vm.score)")
                    if vm.isMultiplayer {
                        statPill(title: "Opponent", value: "\(vm.opponentScore)")
                    } else {
                        statPill(title: "Combo", value: "\(vm.comboLabel)")
                    }
                }

                VStack(spacing: 10) {

                    // ✅ CONTINUE (Rewarded) — single player only
                    if !vm.isMultiplayer && vm.canContinueWithAd {
                        Button {
                            guard !isShowingRewarded else { return }
                            isShowingRewarded = true

                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()

                            guard let vc = RootViewController.topMost else {
                                isShowingRewarded = false
                                return
                            }

                            AdManager.shared.showRewarded(from: vc) {
                                vm.continueAfterReward()
                                isShowingRewarded = false
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "play.rectangle.fill")
                                Text(isShowingRewarded ? "Loading..." : "Watch ad & continue")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.white)
                        .foregroundColor(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .disabled(isShowingRewarded)
                        .opacity(isShowingRewarded ? 0.7 : 1.0)
                    }

                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

                        if vm.isMultiplayer {
                            // ✅ Back to Lobby
                            dismiss()
                            return
                        }

                        // ✅ Single-player: always start a new game.
                        // Interstitial shows every 3 finished games.
                        guard let vc = RootViewController.topMost else {
                            vm.restart()
                            return
                        }

                        AdManager.shared.noteSinglePlayerGameFinishedAndMaybeShowInterstitial(from: vc) {
                            vm.restart()
                        }
                    } label: {
                        Text(vm.isMultiplayer ? "Back to Lobby" : "Play again")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(colors: [Color.white.opacity(0.22), Color.white.opacity(0.10)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        dismiss()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "house.fill")
                            Text("Home")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .disabled(isShowingRewarded)
                    .opacity(isShowingRewarded ? 0.55 : 1.0)
                }
            }
            .padding(18)
            .frame(maxWidth: 360)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.35), radius: 24, x: 0, y: 12)
            .padding(.horizontal, 20)
        }
    }

    private func statPill(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }

private var bottomHint: some View {
        Group {
            if vm.isGameOver {
                EmptyView().frame(height: 0)
            } else {
                Text("Tap fast • Stay focused • Build combo")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.55))
                    .padding(.top, 4)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: vm.isGameOver)
    }
}

// MARK: - Premium Arcade Background

private struct PremiumArcadeBackground: View {
    var breath: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.06, blue: 0.16),
                    Color(red: 0.02, green: 0.02, blue: 0.07)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // neon blobs
            Circle()
                .fill(Color.cyan.opacity(0.20))
                .frame(width: 340, height: 340)
                .blur(radius: 40)
                .offset(x: breath ? -140 : -110, y: breath ? -220 : -190)
                .animation(.easeInOut(duration: 3.0), value: breath)

            Circle()
                .fill(Color.purple.opacity(0.18))
                .frame(width: 420, height: 420)
                .blur(radius: 46)
                .offset(x: breath ? 160 : 130, y: breath ? 120 : 90)
                .animation(.easeInOut(duration: 3.0), value: breath)

            Circle()
                .fill(Color.yellow.opacity(0.10))
                .frame(width: 280, height: 280)
                .blur(radius: 44)
                .offset(x: breath ? 40 : 10, y: breath ? -40 : -10)
                .animation(.easeInOut(duration: 3.0), value: breath)

            // stars
            StarField()
                .opacity(0.55)
                .ignoresSafeArea()
        }
    }
}

private struct StarField: View {
    var body: some View {
        Canvas { ctx, size in
            let count = 120
            for i in 0..<count {
                var rng = SeededRandomGenerator(seed: UInt64(42 + i))
                let x = Double.random(in: 0...Double(size.width), using: &rng)
                let y = Double.random(in: 0...Double(size.height), using: &rng)
                let r = Double.random(in: 0.6...1.8, using: &rng)
                let alpha = Double.random(in: 0.25...0.9, using: &rng)

                let rect = CGRect(x: x, y: y, width: r, height: r)
                ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(alpha)))
            }
        }
    }
}

// MARK: - Premium Round Button

private enum PremiumButtonStyleKind {
    case success
    case danger

    var base: Color {
        switch self {
        case .success: return .green
        case .danger: return .red
        }
    }

    var glow: Color {
        switch self {
        case .success: return .cyan
        case .danger: return .pink
        }
    }
}

private struct PremiumRoundActionButton: View {
    let title: String
    let systemIcon: String
    let style: PremiumButtonStyleKind
    let isEmphasized: Bool
    let action: () -> Void

    @State private var pressed = false
    @State private var pulse = false

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: systemIcon)
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundColor(.white)

                Text(title)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .tracking(0.8)
            }
            .frame(width: 98, height: 98)
            .background(
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                style.base.opacity(0.95),
                                style.base.opacity(0.55)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: style.base.opacity(0.35), radius: 18, y: 10)
            )
            .overlay(
                Circle()
                    .stroke(.white.opacity(0.22), lineWidth: 2)
            )
            .overlay(
                Circle()
                    .fill(style.glow.opacity(isEmphasized ? (pulse ? 0.18 : 0.08) : 0.0))
                    .blur(radius: 18)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
            )
            .scaleEffect(pressed ? 0.92 : (isEmphasized ? (pulse ? 1.06 : 1.00) : 1.0))
            .animation(.spring(response: 0.22, dampingFraction: 0.65), value: pressed)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
        .onAppear { pulse = true }
        .accessibilityLabel(title)
    }
}

// MARK: - Boss Banner (NEW)

private struct BossBannerView: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "bolt.fill")
                .foregroundColor(.black)

            Text("BOSS ROUND!")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundColor(.black)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.yellow)
                .shadow(color: .yellow.opacity(0.6), radius: 18, y: 10)
        )
    }
}

// MARK: - Shake Effect (UNCOMMENTED)
//
//private struct ShakeEffect: GeometryEffect {
//    var animatableData: CGFloat
//
//    func effectValue(size: CGSize) -> ProjectionTransform {
//        let translation = 10 * sin(animatableData * .pi * 6)
//        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
//    }
//}
