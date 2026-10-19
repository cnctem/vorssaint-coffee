// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Combine
import Foundation

/// The way a language agrees a noun with the number in front of it.
enum CountAgreement {
    /// One form for exactly one, another for every other count.
    case oneAndMany
    /// Russian and Ukrainian: the number's last digits decide. 21 takes the
    /// first form and 22 the middle one, while 11 through 14 fall back to the last.
    case byLastDigits
    /// Slovak: the whole number decides. Only one itself takes the first form
    /// and only two through four the middle one, so 21 and 22 read
    /// "21 súborov" and "22 súborov" the same way 25 does.
    case byWholeNumber
}

/// Languages the interface can use. The first launch defaults to the system
/// language; the onboarding and Settings let the user override it at any time.
enum AppLanguage: String, CaseIterable, Identifiable {
    case enUS = "en-US"
    case ptBR = "pt-BR"
    case tr = "tr"
    case ru = "ru"
    case es = "es"
    case sk = "sk"
    case de = "de"
    case fr = "fr"
    case it = "it"
    case ja = "ja"
    case ko = "ko"
    case uk = "uk"
    case zhHans = "zh-Hans"
    case zhTW = "zh-TW"
    case zhHK = "zh-HK"

    var id: String { rawValue }

    /// How this language agrees a counted noun with the number in front of
    /// it. Three of the fifteen put a distinct form between one and many, and
    /// they disagree on which numbers take it, so the count itself is not
    /// enough to pick a form without knowing the language's rule.
    var countAgreement: CountAgreement {
        switch self {
        case .ru, .uk: return .byLastDigits
        case .sk: return .byWholeNumber
        default: return .oneAndMany
        }
    }

    /// The language's own name, shown in its own script, the way macOS lists them.
    var displayName: String {
        switch self {
        case .enUS: return "English (US)"
        case .ptBR: return "Português (Brasil)"
        case .tr: return "Türkçe"
        case .ru: return "Русский"
        case .es: return "Español"
        case .sk: return "Slovenčina"
        case .de: return "Deutsch"
        case .fr: return "Français"
        case .it: return "Italiano"
        case .ja: return "日本語"
        case .ko: return "한국어"
        case .zhHans: return "简体中文"
        case .zhHK: return "繁體中文（香港）"
        case .zhTW: return "繁體中文（台灣）"
        case .uk: return "Українська"
        }
    }

    /// Dates and times in this language, arranged the way System Settings
    /// asks: region, 12- or 24-hour clock and first day of the week. A locale
    /// made from the language alone would bring that language's own clock.
    func formattingLocale(system: Locale = .autoupdatingCurrent) -> Locale {
        var components = Locale.Components(identifier: rawValue)
        components.region = system.region
        components.hourCycle = system.hourCycle
        components.firstDayOfWeek = system.firstDayOfWeek
        return Locale(components: components)
    }

    static var systemDefault: AppLanguage {
        let preferred = Locale.preferredLanguages.first ?? "en"
        let p = preferred.lowercased()

        if p.hasPrefix("zh-hk") || p.hasPrefix("zh-hant-hk") {
            return .zhHK
        }

        if p.hasPrefix("zh-tw") || p.hasPrefix("zh-hant-tw") || p.hasPrefix("zh-hant") {
            return .zhTW
        }

        let matches: [(String, AppLanguage)] = [
            ("pt", .ptBR), ("tr", .tr), ("ru", .ru), ("es", .es), ("sk", .sk), ("de", .de),
            ("fr", .fr), ("it", .it), ("ja", .ja), ("ko", .ko), ("uk", .uk), ("zh", .zhHans),
        ]
        for (prefix, language) in matches where preferred.hasPrefix(prefix) { return language }
        return .enUS
    }
}

/// Source of every user-facing string. Views observe this object so the whole
/// interface re-renders immediately when the language changes.
final class L10n: ObservableObject {
    static let shared = L10n()

    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: DefaultsKey.language) }
    }

    var s: Strings { Strings.localized(language) }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: DefaultsKey.language),
           let saved = AppLanguage(rawValue: raw) {
            language = saved
        } else {
            language = .systemDefault
        }
    }
}

extension Strings {
    /// The catalog for a language other than the current one, as the
    /// feature string tables offer theirs.
    static func localized(_ language: AppLanguage) -> Strings {
        switch language {
        case .enUS: return .enUS
        case .ptBR: return .ptBR
        case .tr: return .tr
        case .ru: return .ru
        case .es: return .es
        case .sk: return .sk
        case .de: return .de
        case .fr: return .fr
        case .it: return .it
        case .ja: return .ja
        case .ko: return .ko
        case .zhHans: return .zhHans
        case .zhHK: return .zhHK
        case .zhTW: return .zhTW
        case .uk: return .uk
        }
    }
}

/// Flat, compiler-checked catalog of UI strings. Adding a field here forces
/// both translations to be provided.
struct Strings {
    let statusIdleTooltip: String
    let statusActiveUntil: String      // + time
    let statusActiveIndefinite: String
    let menuEnableAwake: String
    let menuDisableAwake: String
    let menuActivateFor: String
    let menuSettings: String
    let menuAbout: String
    let menuQuit: String
    let menuHide: String
    let menuHideOthers: String
    let menuShowAll: String
    let menuEdit: String
    let menuUndo: String
    let menuRedo: String
    let actionClear: String
    let actionRemove: String
    let actionBack: String
    let actionSearch: String
    let menuCut: String
    let menuCopy: String
    let menuPaste: String
    let menuSelectAll: String
    let menuWindow: String
    let menuMinimize: String
    let menuZoom: String
    let menuClose: String
    let minutes15: String
    let minutes30: String
    let hour1: String
    let hours2: String
    let hours4: String
    let hours8: String
    let indefinitely: String
    let indefinite: String
    let panelSettings: String
    let panelQuit: String
    let panelHotkeyHint: String
    let keepAwakeTitle: String
    let keepAwakeEndsIn: String        // + remaining
    let keepAwakeUntilDisabled: String
    let keepAwakeNormalRules: String
    let keepAwakeUntilLabel: String
    let keepAwakeUntilStart: String
    let keepAwakeOptions: String
    let keepAwakeMouseJiggle: String
    let keepAwakeMouseJiggleCaption: String
    let keepAwakeMouseJiggleInterval: String
    let keepAwakeActiveIconLabel: String
    let keepAwakeActiveIconDot: String
    let keepAwakeActiveIconCoffee: String
    let keepAwakeActiveIconEye: String
    let keepAwakeActiveIconMoon: String
    let keepAwakeActiveIconLight: String
    let keepAwakeIconTintLabel: String
    let keepAwakeIconTintOrange: String
    let keepAwakeIconTintGreen: String
    let keepAwakeIconTintBlue: String
    let keepAwakeIconTintPurple: String
    let keepAwakeIconTintPink: String
    let keepAwakeIconTintNone: String
    let durationLabel: String
    let clamshellTitle: String
    let clamshellOnCaption: String
    let clamshellNeedsSession: String
    let clamshellReady: String
    let clamshellNeedsPassword: String
    let notifySessionEndedTitle: String
    let notifySessionEndedBody: String
    let notifyBatteryTitle: String
    let notifyBatteryBody: String
    let adminPromptClamshellOn: String
    let adminPromptClamshellOff: String
    let adminPromptRecover: String
    let adminPromptSudoersInstall: String
    let adminPromptSudoersRemove: String
    let settingsTitle: String
    let tabGeneral: String
    let tabEnergy: String
    let tabAbout: String
    let launchAtLogin: String
    let languageLabel: String
    let menuBarSection: String
    let showCountdown: String
    let globalHotkeySection: String
    let hotkeyToggle: String
    let hotkeyCaption: String
    let sessionSection: String
    let defaultDurationLabel: String
    let keepAwakeAutoStart: String
    let keepAwakeAutoStartCaption: String
    let batteryProtectionSection: String
    let batteryDisableBelow: String
    let batteryNever: String
    let batteryProtectionCaption: String
    let clamshellSection: String
    let configuring: String
    let sudoersFailed: String
    let clamshellExplanation: String
    let dimScreenOnLidCloseTitle: String
    let dimScreenOnLidCloseCaption: String
    let permissionRequired: String
    let permissionAccessibility: String
    let permissionGranted: String
    let permissionMissing: String
    let permissionOpenSettings: String
    let permissionRequest: String
    let aboutDescription: String
    let versionPrefix: String
    let viewOnGitHub: String
    let showMenuBarIcon: String
    let shortcutRecording: String
    let shortcutReset: String
    let shortcutNone: String
    let shortcutClear: String
    let shortcutInvalid: String
    let shortcutPressKeys: String
    let shortcutEscapeHint: String
    let shortcutDeleteHint: String
    let shortcutNotCaptured: String
    let shortcutConflictFormat: String
    let shortcutUnavailable: String
    let launchAtLoginNeedsApplications: String
    let launchAtLoginNeedsApproval: String
    let keepAwakeRightClickToggle: String
    let keepAwakeRightClickToggleCaption: String
}

// MARK: - Português (Brasil)

extension Strings {
    static let ptBR = Strings(
        statusIdleTooltip: "Vorssaint Coffee: suspensão normal",
        statusActiveUntil: "Vorssaint Coffee: ativo até",
        statusActiveIndefinite: "Vorssaint Coffee: ativo indefinidamente",
        menuEnableAwake: "Ativar manter acordado",
        menuDisableAwake: "Desativar manter acordado",
        menuActivateFor: "Ativar por…",
        menuSettings: "Ajustes…",
        menuAbout: "Sobre o Vorssaint Coffee",
        menuQuit: "Sair do Vorssaint Coffee",
        menuHide: "Ocultar o Vorssaint Coffee",
        menuHideOthers: "Ocultar Outros",
        menuShowAll: "Mostrar Tudo",
        menuEdit: "Editar",
        menuUndo: "Desfazer",
        menuRedo: "Refazer",
        actionClear: "Limpar",
        actionRemove: "Remover",
        actionBack: "Voltar",
        actionSearch: "Buscar",
        menuCut: "Recortar",
        menuCopy: "Copiar",
        menuPaste: "Colar",
        menuSelectAll: "Selecionar Tudo",
        menuWindow: "Janela",
        menuMinimize: "Minimizar",
        menuZoom: "Zoom",
        menuClose: "Fechar",
        minutes15: "15 minutos",
        minutes30: "30 minutos",
        hour1: "1 hora",
        hours2: "2 horas",
        hours4: "4 horas",
        hours8: "8 horas",
        indefinitely: "Indefinidamente",
        indefinite: "Indefinida",
        panelSettings: "Ajustes",
        panelQuit: "Sair",
        panelHotkeyHint: "Atalho alterna",
        keepAwakeTitle: "Manter acordado",
        keepAwakeEndsIn: "Termina em",
        keepAwakeUntilDisabled: "Ativo até você desativar",
        keepAwakeNormalRules: "O Mac segue as regras normais de energia",
        keepAwakeUntilLabel: "Até",
        keepAwakeUntilStart: "Iniciar",
        keepAwakeOptions: "Opções",
        keepAwakeMouseJiggle: "Mover cursor levemente",
        keepAwakeMouseJiggleCaption: "Durante uma sessão, move o cursor um pouco no intervalo escolhido.",
        keepAwakeMouseJiggleInterval: "Intervalo",
        keepAwakeActiveIconLabel: "Ícone ativo",
        keepAwakeActiveIconDot: "Ponto",
        keepAwakeActiveIconCoffee: "Café",
        keepAwakeActiveIconEye: "Olho",
        keepAwakeActiveIconMoon: "Lua",
        keepAwakeActiveIconLight: "Lâmpada",
        keepAwakeIconTintLabel: "Cor do ícone ativo",
        keepAwakeIconTintOrange: "Laranja",
        keepAwakeIconTintGreen: "Verde",
        keepAwakeIconTintBlue: "Azul",
        keepAwakeIconTintPurple: "Roxo",
        keepAwakeIconTintPink: "Rosa",
        keepAwakeIconTintNone: "Sem cor",
        durationLabel: "Duração",
        clamshellTitle: "Continuar com a tampa fechada",
        clamshellOnCaption: "Suspensão totalmente desativada. Atenção à energia",
        clamshellNeedsSession: "Será aplicada sempre que “Manter acordado” estiver ativo",
        clamshellReady: "Pronto. Liga e desliga sem senha",
        clamshellNeedsPassword: "Pedirá a senha de administrador uma vez",
        notifySessionEndedTitle: "Sessão encerrada",
        notifySessionEndedBody: "O tempo acabou. O Mac voltará a suspender normalmente.",
        notifyBatteryTitle: "Vorssaint Coffee desativado",
        notifyBatteryBody: "Bateria baixa. A suspensão normal foi restaurada para proteger a carga.",
        adminPromptClamshellOn: "O Vorssaint Coffee precisa da sua senha para manter o Mac ativo com a tampa fechada.",
        adminPromptClamshellOff: "O Vorssaint Coffee precisa da sua senha para reativar a suspensão normal do Mac.",
        adminPromptRecover: "O Vorssaint Coffee foi encerrado com a suspensão do Mac desativada. Digite a senha para restaurar a suspensão normal.",
        adminPromptSudoersInstall: "O Vorssaint Coffee vai criar uma regra restrita (somente pmset disablesleep) para alternar a tampa fechada sem pedir senha. Esta é a única vez que a senha será necessária.",
        adminPromptSudoersRemove: "O Vorssaint Coffee vai remover a regra de tampa fechada sem senha.",
        settingsTitle: "Ajustes do Vorssaint Coffee",
        tabGeneral: "Geral",
        tabEnergy: "Energia",
        tabAbout: "Sobre",
        launchAtLogin: "Iniciar junto com o Mac",
        languageLabel: "Idioma",
        menuBarSection: "Barra de menus",
        showCountdown: "Mostrar tempo restante ao lado do ícone",
        globalHotkeySection: "Atalho global",
        hotkeyToggle: "Ativar atalho para “Manter acordado”",
        hotkeyCaption: "Funciona em qualquer app, sem permissões extras.",
        sessionSection: "Sessão",
        defaultDurationLabel: "Duração padrão",
        keepAwakeAutoStart: "Manter acordado ao abrir o Vorssaint Coffee",
        keepAwakeAutoStartCaption: "Inicia uma sessão com a duração padrão.",
        batteryProtectionSection: "Proteção de bateria",
        batteryDisableBelow: "Desativar com bateria abaixo de",
        batteryNever: "Nunca",
        batteryProtectionCaption: "Evita que uma sessão esquecida drene a bateria do MacBook.",
        clamshellSection: "Tampa fechada",
        configuring: "Configurando…",
        sudoersFailed: "Não foi possível ativar a tampa fechada. Tente de novo.",
        clamshellExplanation: "“Continuar com a tampa fechada” desativa completamente a suspensão enquanto “Manter acordado” estiver ativo e é revertido automaticamente quando a sessão termina ou o app é encerrado. Prefira usá-lo conectado à energia.",
        dimScreenOnLidCloseTitle: "Escurecer a tela completamente",
        dimScreenOnLidCloseCaption: "Escurece a tela quando a tampa fecha e restaura o brilho quando ela abre.",
        permissionRequired: "Permissão necessária",
        permissionAccessibility: "Acessibilidade",
        permissionGranted: "Concedida",
        permissionMissing: "Não concedida",
        permissionOpenSettings: "Abrir Ajustes do Sistema…",
        permissionRequest: "Conceder acesso",
        aboutDescription: "Mantém o Mac acordado pelo tempo que você escolher.\nUm ícone na barra de menus, e nada mais.",
        versionPrefix: "Versão",
        viewOnGitHub: "Ver no GitHub",
        showMenuBarIcon: "Mostrar ícone na barra de menus",
        shortcutRecording: "Pressione o novo atalho",
        shortcutReset: "Redefinir",
        shortcutNone: "Nenhum",
        shortcutClear: "Remover atalho",
        shortcutInvalid: "Use pelo menos Control, Option ou Command junto com uma tecla.",
        shortcutPressKeys: "Pressione",
        shortcutEscapeHint: "Esc cancela.",
        shortcutDeleteHint: "Delete remove.",
        shortcutNotCaptured: "Nada foi capturado. O macOS ou outro app já usa essa combinação. Tente outra.",
        shortcutConflictFormat: "Este atalho já está em uso por %@.",
        shortcutUnavailable: "O macOS recusou este atalho. Escolha outro.",
        launchAtLoginNeedsApplications: "O app está rodando de um lugar que não permite abrir no login. Arraste o Vorssaint Coffee para a pasta Aplicativos, abra de lá e ligue de novo.",
        launchAtLoginNeedsApproval: "O item de login está registrado, mas o macOS ainda precisa da sua aprovação. Nos Ajustes do Sistema, permita que o Vorssaint Coffee abra no login e funcione em segundo plano.",
        keepAwakeRightClickToggle: "Clique com o botão direito no ícone da barra de menus para alternar “Manter acordado”",
        keepAwakeRightClickToggleCaption: "Substitui o menu de contexto do clique com o botão direito."
    )
}

// MARK: - English (US)

extension Strings {
    static let enUS = Strings(
        statusIdleTooltip: "Vorssaint Coffee: normal sleep",
        statusActiveUntil: "Vorssaint Coffee: awake until",
        statusActiveIndefinite: "Vorssaint Coffee: awake indefinitely",
        menuEnableAwake: "Enable keep awake",
        menuDisableAwake: "Disable keep awake",
        menuActivateFor: "Activate for…",
        menuSettings: "Settings…",
        menuAbout: "About Vorssaint Coffee",
        menuQuit: "Quit Vorssaint Coffee",
        menuHide: "Hide Vorssaint Coffee",
        menuHideOthers: "Hide Others",
        menuShowAll: "Show All",
        menuEdit: "Edit",
        menuUndo: "Undo",
        menuRedo: "Redo",
        actionClear: "Clear",
        actionRemove: "Remove",
        actionBack: "Back",
        actionSearch: "Search",
        menuCut: "Cut",
        menuCopy: "Copy",
        menuPaste: "Paste",
        menuSelectAll: "Select All",
        menuWindow: "Window",
        menuMinimize: "Minimize",
        menuZoom: "Zoom",
        menuClose: "Close",
        minutes15: "15 minutes",
        minutes30: "30 minutes",
        hour1: "1 hour",
        hours2: "2 hours",
        hours4: "4 hours",
        hours8: "8 hours",
        indefinitely: "Indefinitely",
        indefinite: "Indefinite",
        panelSettings: "Settings",
        panelQuit: "Quit",
        panelHotkeyHint: "Shortcut toggles",
        keepAwakeTitle: "Keep awake",
        keepAwakeEndsIn: "Ends in",
        keepAwakeUntilDisabled: "Active until you turn it off",
        keepAwakeNormalRules: "The Mac follows its normal energy rules",
        keepAwakeUntilLabel: "Until",
        keepAwakeUntilStart: "Start",
        keepAwakeOptions: "Options",
        keepAwakeMouseJiggle: "Move pointer slightly",
        keepAwakeMouseJiggleCaption: "During a session, moves the pointer a little at the chosen interval.",
        keepAwakeMouseJiggleInterval: "Interval",
        keepAwakeActiveIconLabel: "Active icon",
        keepAwakeActiveIconDot: "Dot",
        keepAwakeActiveIconCoffee: "Coffee",
        keepAwakeActiveIconEye: "Eye",
        keepAwakeActiveIconMoon: "Moon",
        keepAwakeActiveIconLight: "Lightbulb",
        keepAwakeIconTintLabel: "Active icon color",
        keepAwakeIconTintOrange: "Orange",
        keepAwakeIconTintGreen: "Green",
        keepAwakeIconTintBlue: "Blue",
        keepAwakeIconTintPurple: "Purple",
        keepAwakeIconTintPink: "Pink",
        keepAwakeIconTintNone: "No color",
        durationLabel: "Duration",
        clamshellTitle: "Keep going with the lid closed",
        clamshellOnCaption: "Sleep fully disabled. Mind the power",
        clamshellNeedsSession: "Applied whenever “Keep awake” is active",
        clamshellReady: "Ready. Toggles without a password",
        clamshellNeedsPassword: "Will ask for the administrator password once",
        notifySessionEndedTitle: "Session ended",
        notifySessionEndedBody: "Time is up. The Mac will sleep normally again.",
        notifyBatteryTitle: "Vorssaint Coffee disabled",
        notifyBatteryBody: "Low battery. Normal sleep was restored to protect the charge.",
        adminPromptClamshellOn: "Vorssaint Coffee needs your password to keep the Mac going with the lid closed.",
        adminPromptClamshellOff: "Vorssaint Coffee needs your password to restore the Mac’s normal sleep.",
        adminPromptRecover: "Vorssaint Coffee quit while the Mac’s sleep was disabled. Enter the password to restore normal sleep.",
        adminPromptSudoersInstall: "Vorssaint Coffee will create a restricted rule (pmset disablesleep only) to toggle closed-lid mode without asking for a password. This is the only time the password is needed.",
        adminPromptSudoersRemove: "Vorssaint Coffee will remove the password-free closed-lid rule.",
        settingsTitle: "Vorssaint Coffee Settings",
        tabGeneral: "General",
        tabEnergy: "Energy",
        tabAbout: "About",
        launchAtLogin: "Launch at login",
        languageLabel: "Language",
        menuBarSection: "Menu bar",
        showCountdown: "Show remaining time next to the icon",
        globalHotkeySection: "Global shortcut",
        hotkeyToggle: "Enable shortcut for “Keep awake”",
        hotkeyCaption: "Works in any app, no extra permissions.",
        sessionSection: "Session",
        defaultDurationLabel: "Default duration",
        keepAwakeAutoStart: "Keep Awake when Vorssaint Coffee opens",
        keepAwakeAutoStartCaption: "Starts a session with the default duration.",
        batteryProtectionSection: "Battery protection",
        batteryDisableBelow: "Disable when battery drops below",
        batteryNever: "Never",
        batteryProtectionCaption: "Keeps a forgotten session from draining the MacBook battery.",
        clamshellSection: "Closed lid",
        configuring: "Configuring…",
        sudoersFailed: "Couldn’t turn on closed-lid mode. Try again.",
        clamshellExplanation: "“Keep going with the lid closed” fully disables sleep while “Keep awake” is active and is reverted automatically when the session ends or the app quits. Prefer using it plugged in.",
        dimScreenOnLidCloseTitle: "Dim the display to zero",
        dimScreenOnLidCloseCaption: "Dims the display when the lid closes and brings the brightness back when it opens.",
        permissionRequired: "Permission required",
        permissionAccessibility: "Accessibility",
        permissionGranted: "Granted",
        permissionMissing: "Not granted",
        permissionOpenSettings: "Open System Settings…",
        permissionRequest: "Grant access",
        aboutDescription: "Keeps your Mac awake for the time you choose.\nOne menu bar icon, and nothing else.",
        versionPrefix: "Version",
        viewOnGitHub: "View on GitHub",
        showMenuBarIcon: "Show menu bar icon",
        shortcutRecording: "Press the new shortcut",
        shortcutReset: "Reset",
        shortcutNone: "None",
        shortcutClear: "Remove shortcut",
        shortcutInvalid: "Use at least Control, Option or Command with a key.",
        shortcutPressKeys: "Press keys",
        shortcutEscapeHint: "Escape cancels.",
        shortcutDeleteHint: "Delete clears.",
        shortcutNotCaptured: "Nothing was captured. macOS or another app already uses that combination. Try another one.",
        shortcutConflictFormat: "This shortcut is already used by %@.",
        shortcutUnavailable: "macOS rejected this shortcut. Choose another one.",
        launchAtLoginNeedsApplications: "The app is running from a place that cannot open at login. Drag Vorssaint Coffee to the Applications folder, open it from there and turn this on again.",
        launchAtLoginNeedsApproval: "The login item is registered, but macOS still needs your approval. In System Settings, allow Vorssaint Coffee to open at login and to run in the background.",
        keepAwakeRightClickToggle: "Right-click the menu bar icon to toggle Keep Awake",
        keepAwakeRightClickToggleCaption: "Replaces the right-click context menu."
    )
}
