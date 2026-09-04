import Foundation

/// Português do Brasil.
///
/// Written to carry the English voice rather than to mirror its grammar. Three
/// rules shaped it:
///
/// - **"Sua pessoa" stays.** It is the whole register of the app — warmer and
///   less administrative than "seu parceiro" — and it has the same happy
///   property in Portuguese: it names someone without gendering them.
/// - **Nothing gendered about the partner.** The app never learns whether the
///   other person is a man or a woman, so no adjective or participle in this
///   file agrees with them. Where English leaned on "they", the Portuguese
///   leans on rewriting the sentence.
/// - **"Couple OS" and "Couple World" are names**, not words, so they are not
///   translated. Everything around them is.
extension Strings {
    static let portugueseBrazil = Strings(
        language: .portugueseBrazil,
        brand: portugueseBrand,
        common: portugueseCommon,
        languageMenu: portugueseLanguageMenu,
        welcome: portugueseWelcome,
        invite: portugueseInvite,
        auth: portugueseAuth,
        session: portugueseSession,
        identity: portugueseIdentity,
        couple: portugueseCouple,
        home: portugueseHome,
        world: portugueseWorld,
        today: portugueseToday,
        market: portugueseMarket,
        chores: portugueseChores,
        decisions: portugueseDecisions,
        errors: portugueseErrors
    )
}

/// Unlike English, the stand-in is only capitalised where a sentence starts.
private let person: @Sendable (String?) -> String = { $0 ?? "Sua pessoa" }
private let personInline: @Sendable (String?) -> String = { $0 ?? "sua pessoa" }

private let portugueseBrand = Strings.Brand(
    wordmark: "COUPLE OS",
    accessibleName: "Couple OS"
)

private let portugueseCommon = Strings.Common(
    tryAgain: "Tentar de novo",
    continueAction: "Continuar",
    back: "Voltar",
    close: "Fechar",
    remove: "Remover",
    clear: "Limpar",
    working: "Carregando",
    signOut: "Sair",
    errorPrefix: "Erro",
    successPrefix: "Tudo certo",
    or: "OU",
    person: person,
    personInline: personInline
)

private let portugueseLanguageMenu = Strings.LanguageMenu(
    title: "Idioma",
    automatic: { "Automático · \($0.endonym)" },
    accessibilityLabel: { "Idioma, atualmente \($0.endonym)" }
)

private let portugueseWelcome = Strings.Welcome(
    openingYourWorld: "Abrindo o mundo de vocês…",
    heroTitle: "O mundo de vocês.\nSó vocês dois.",
    heroSubtitle: "Um espaço privado para ficar perto, dividir a vida e construir algo que é só de vocês.",
    createWorld: "Criar nosso mundo",
    haveAccount: "Já tenho uma conta",
    haveInvite: "Tenho um convite"
)

private let portugueseInvite = Strings.Invite(
    manualTitle: "Entre no mundo de vocês.",
    manualSubtitle: "Use o convite privado que sua pessoa compartilhou com você.",
    linkLabel: "LINK DO CONVITE",
    linkPlaceholder: "Cole seu link privado",
    manualPrivacy: "O link não revela nada privado antes de você entrar.",
    invitationTitle: "Você recebeu um convite para o mundo de alguém.",
    invitationSubtitle: "Um espaço privado no Couple OS está esperando por vocês dois.",
    joinTheirWorld: "Entrar nesse mundo",
    invitationPrivacy: "Você só vai saber quem te convidou depois que sua conta for verificada.",
    choiceTitle: "Como você quer entrar?",
    choiceSubtitle: "Seu convite continua com você durante a entrada.",
    createAccount: "Criar conta",
    signIn: "Entrar"
)

private let portugueseAuth = Strings.Auth(
    loginTitle: "Que bom te ver de novo",
    loginSubtitle: "O mundo de vocês estava esperando.",
    emailLabel: "E-MAIL",
    emailPlaceholder: "voce@exemplo.com",
    passwordLabel: "SENHA",
    passwordPlaceholder: "Sua senha",
    showPassword: "Mostrar senha",
    hidePassword: "Ocultar senha",
    forgotPassword: "Esqueceu a senha?",
    resetLinkSent: "Veja na sua caixa de entrada o link para redefinir.",
    signUpTitle: "Crie sua conta",
    signUpSubtitle: "Uma chave silenciosa para o mundo que vocês estão prestes a criar.",
    createAccount: "Criar conta",
    signUpPrivacy: "Sua conta é sua. O mundo compartilhado pertence aos dois.",
    invalidEmail: "Digite um e-mail válido.",
    shortPassword: { "A senha precisa ter pelo menos \($0) caracteres." },
    missingName: "Diga como devemos te chamar."
)

private let portugueseSession = Strings.Session(
    openingYourWorld: "Abrindo o mundo de vocês…",
    worldStillHere: "O mundo de vocês continua aqui.",
    finishingYourSpace: "Terminando o seu espaço…",
    accountSafe: "Sua conta está segura."
)

private let portugueseIdentity = Strings.Identity(
    title: "Vamos começar por você.",
    subtitle: "Uma pessoa começa. O mundo passa a ser de vocês quando a outra chega.",
    nameLabel: "SEU NOME",
    namePlaceholder: "Como devemos te chamar?",
    privacy: "Privado por natureza. Nada aqui é público.",
    recoveryTitle: "Vamos terminar o seu espaço.",
    recoverySubtitle: "Sua conta está segura. Só falta o nome que vive dentro do mundo de vocês.",
    recoveryPrivacy: "Encontramos sua conta e vamos continuar exatamente de onde você parou."
)

private let portugueseCouple = Strings.Couple(
    preparingTitle: "Preparando o mundo de vocês…",
    preparingSubtitle: "Um espaço privado está tomando forma.",
    waitingTitle: "Esperando sua pessoa.",
    waitingSubtitle: "O mundo de vocês muda quando ela chegar.",
    shareInvite: "Compartilhar convite",
    shareSubject: "Um convite privado do Couple OS",
    shareMessage: "Vem para o nosso Couple World.",
    copyLink: "Copiar link",
    linkCopied: "Link copiado",
    sharedTitle: "O mundo de vocês agora é dos dois.",
    sharedSubtitle: "Duas presenças. Um lugar só de vocês.",
    worldStillHere: "O mundo de vocês continua aqui.",
    joiningTitle: "Entrando no mundo de vocês…",
    joiningSubtitle: "Conectando vocês dois com segurança.",
    joinedSubtitle: "Este lugar privado pertence aos dois.",
    couldNotJoinTitle: "Não conseguimos entrar neste mundo."
)

private let portugueseHome = Strings.Home(
    privateSpace: "Espaço só de vocês",
    signOut: "Sair",
    partnerLoading: "Carregando o perfil da sua pessoa",
    retryPartner: "Tentar carregar o perfil de novo",
    welcomeBack: { "Que bom te ver, \($0)." },
    openingSharedWorld: "Abrindo o mundo de vocês…",
    worldStillHere: "O mundo de vocês continua aqui.",
    bothNames: { "\($0) e \($1)" },
    nowSection: "AGORA",
    ourWorldSection: "NOSSO MUNDO",
    quiet: "Nada precisa de vocês agora.",
    signalAccessibility: { "\($0). \($1). \($2)." },
    areaAccessibility: { "\($0). \($1)." },
    urgencyEyebrow: { urgency in
        switch urgency {
        case .live: "NESTE MOMENTO"
        case .needsYou: "PRECISA DE VOCÊ"
        case .needsBoth: "PRECISA DOS DOIS"
        case .waiting: "ESPERANDO"
        case .settled: "AGORA MESMO"
        }
    },
    moduleTitle: { module in
        switch module {
        case .market: "Mercado"
        case .chores: "Casa"
        case .decisions: "Decisões"
        case .today: "Hoje"
        }
    }
)

private let portugueseWorld = Strings.World(
    soloDescription: "Uma presença esperando sua pessoa",
    description: { activity in
        switch activity {
        case .calm: "Duas presenças conectadas dentro do mundo privado delas"
        case .needsBoth: "O mundo de vocês tem algo esperando os dois"
        case .needsYou: "Sua pessoa deixou algo esperando por você no mundo de vocês"
        case .waiting: "Sua presença espera em silêncio por sua pessoa"
        case .sharedMoment: "As duas presenças completaram um momento juntas"
        case .live: "Um de vocês está lá fora agora"
        }
    },
    urgencyCaption: { urgency in
        switch urgency {
        case .live: "Algo está acontecendo agora."
        case .needsYou: "Sua pessoa deixou algo aqui para você."
        case .needsBoth: "Um pequeno momento espera vocês dois."
        case .waiting: "Sua parte está feita. Nada mais é preciso."
        case .settled: "Algo acabou de se tornar de vocês."
        }
    },
    bothHere: "Vivo porque vocês dois estão aqui."
)

private let portugueseToday = Strings.Today(
    eyebrow: "HOJE",
    saving: "Salvando…",
    leaveThisHere: "Deixar isso aqui",
    reconnect: "Reconectar",
    backToOurWorld: "Voltar para o nosso mundo",
    waitingTitle: "Sua resposta está aqui.",
    waitingDetail: "Ela fica privada até sua pessoa deixar a dela. Enquanto isso, o mundo de vocês continua seu.",
    revealTitle: "Vocês dois deixaram uma marca aqui.",
    you: "Você",
    yourPerson: "Sua pessoa",
    statusReconnect: "Toque para reconectar",
    statusOpenForBoth: "Aberto para os dois",
    statusWaitingForYou: "Esperando você",
    statusWaitingForPartner: { "Esperando \(personInline($0))" },
    statusRevealed: "Revelado",
    statusOpening: "Abrindo…",
    detailAvailable: "Uma pequena escolha para cada um",
    detailWaitingForMe: { "\(person($0)) deixou algo aqui" },
    detailWaitingForPartner: { "Sua resposta está aí — esperando \(personInline($0))" },
    detailRevealAvailable: "Vocês dois responderam — veja o que significa",
    promptEveryday: "O que hoje teria mais a cara de vocês?",
    optionsEveryday: [
        "Ficar em casa e deixar aconchegante",
        "Ir a algum lugar novo",
        "Ver alguma coisa juntos",
        "Só conversar um pouco",
        "Deixar a outra pessoa escolher",
    ]
)

private let portugueseMarket = Strings.Market(
    title: "Mercado",
    openingList: "Abrindo sua lista",
    listStillHere: "Sua lista continua aqui.",
    runEyebrowIdle: "IDA AO MERCADO",
    runEyebrowMine: "VOCÊ ESTÁ LÁ",
    runEyebrowTheirs: "SUA PESSOA ESTÁ LÁ",
    runHeadlineIdle: { "Vai ao mercado? Avise \(personInline($0)) — ainda dá tempo de pedir algo." },
    runHeadlineAllGathered: "Está tudo na cesta.",
    runHeadlineRemaining: { $0 == 1 ? "Falta 1 item." : "Faltam \($0) itens." },
    runHeadlineTheirs: { "\(person($0)) está no mercado agora." },
    finishRun: "Terminei",
    startRun: "Estou no mercado",
    composerPlaceholderIdle: "Adicionar à lista",
    composerPlaceholderShopping: "Rápido — peça alguma coisa",
    addToList: "Adicionar à lista",
    askDirectly: { "Pedir isso direto para \(personInline($0))" },
    toBringSection: "PARA TRAZER",
    basketSection: "NA CESTA",
    clearBasket: "Limpar",
    dismissMessageHint: "Dispensa esta mensagem",
    emptyTitle: "Nada na lista.",
    emptyDetail: "Adicione o que a casa precisa. Quem chegar primeiro vai ver.",
    waitingAMonthOrMore: "Esperando há um mês ou mais",
    waitingDays: { $0 == 1 ? "Esperando há 1 dia" : "Esperando há \($0) dias" },
    youAskedForThis: "Você pediu isso",
    personAskedForThis: { "\(person($0)) pediu isso" },
    addedByPerson: { "Adicionado por \(personInline($0))" },
    stillToBring: "ainda para trazer",
    inTheBasket: "na cesta",
    signalPartnerRunTitle: { "\(person($0)) está no mercado" },
    signalRunDetailEmpty: "Nada na lista ainda — peça alguma coisa",
    signalRunDetailPending: { "\($0) \($0 == 1 ? "item" : "itens") para trazer · quer pedir algo?" },
    captionPartnerRun: { "\(person($0)) está lá fora. Agora é o momento." },
    signalMyRunTitle: "Você está no mercado",
    signalMyRunDetailEmpty: "Está tudo na cesta",
    signalMyRunDetailPending: { $0 == 1 ? "Falta 1" : "Faltam \($0)" },
    captionMyRun: { "Você está lá fora. \(person($0)) ainda pode te alcançar." },
    signalAsksTitle: { "\(person($0)) pediu \($1) coisas" },
    signalAsksDetailMany: { "\($0) e mais \($1)" },
    signalAsksDetailOne: { "\(person($0)) pediu para você trazer isso" },
    captionAsks: { "\(person($0)) está contando com você para algo pequeno." },
    statusReconnect: "Toque para reconectar",
    statusPartnerThere: { "\(person($0)) está lá agora" },
    statusYouThere: "Você está lá agora",
    statusNothingToBring: "Nada para trazer",
    statusNothingCurrent: "Nada recente",
    statusToBring: { "\($0) para trazer" }
)

private let portugueseChores = Strings.Chores(
    title: "Casa",
    openingChores: "Abrindo as tarefas de casa",
    listStillHere: "Sua lista continua aqui.",
    composerPlaceholder: "Adicione algo que a casa precisa",
    addChore: "Adicionar esta tarefa",
    yourTurnSection: "SUA VEZ",
    withPartnerSection: { $0.map { "COM \($0.uppercased())" } ?? "COM SUA PESSOA" },
    comingUpSection: "EM BREVE",
    startsWithYou: "Começa com você",
    startsWithPartner: { "Começa com \(personInline($0))" },
    emptyTitle: "Nada configurado ainda.",
    emptyDetail: "Adicione as coisas que sempre voltam. De quem é a vez se resolve sozinho.",
    markDoneHint: "Marca como feita",
    cadenceOnce: "Uma vez",
    cadenceDaily: "Todo dia",
    cadenceWeekly: "Toda semana",
    cadenceEveryTwoWeeks: "A cada 2 semanas",
    cadenceMonthly: "Todo mês",
    cadenceEveryDays: { "A cada \($0) dias" },
    rotationAlternates: "Revezar",
    rotationFixed: "Sempre a mesma pessoa",
    rotationAnyone: "Quem chegar primeiro",
    turnEither: "Qualquer um de vocês",
    turnYours: "Sua vez",
    turnPartner: { "Vez de \(personInline($0))" },
    standingLate: { $0 == 1 ? "1 dia de atraso" : "\($0) dias de atraso" },
    standingToday: "hoje",
    standingUpcoming: { $0 == 1 ? "em 1 dia" : "em \($0) dias" },
    standingDone: "Feita",
    rowSubtitle: { "\($0) · \($1)" },
    signalMineTitleMany: { "\($0) coisas na casa" },
    detailLate: { $0 == 1 ? "Atrasada" : "\($0) delas atrasadas" },
    detailOthersToday: { "\($0) e mais \($1) hoje" },
    detailYourTurnToday: "Sua vez hoje",
    captionOverdue: "A casa está esperando por você.",
    signalTheirsTitleMany: { "\($0) coisas com \(personInline($1))" },
    signalTheirsDetail: { "Vez de \(personInline($0))" },
    signalSettledDetail: { "\(person($0)) cuidou disso" },
    statusReconnect: "Toque para reconectar",
    statusForYou: { "\($0) para você" },
    statusWithPartner: { "\($0) com \(personInline($1))" },
    statusNothingSetUp: "Nada configurado",
    statusAllCaughtUp: "Tudo em dia"
)

private let portugueseDecisions = Strings.Decisions(
    title: "Decisões",
    newDecision: "Nova decisão",
    newDecisionHint: "Cria algo para sua pessoa escolher",
    needsYouSection: "PRECISA DE VOCÊ",
    waitingSection: "ESPERANDO",
    recentSection: "RECENTES",
    needsYouDetail: { "\(person($0)) precisa da sua escolha" },
    waitingRowDetail: { "Esperando em silêncio \(personInline($0)) escolher" },
    recentDetail: { $0.map { "Vocês decidiram juntos · \($0)" } ?? "Decidido pelos dois" },
    reconnect: "Reconectar decisões",
    rowHint: "Abre esta decisão",
    createEyebrow: "NOVA DECISÃO",
    createTitle: "O que você quer que sua pessoa escolha?",
    createSubtitle: "Mantenha simples. Uma pergunta, algumas opções de verdade.",
    decisionLabel: "A DECISÃO",
    decisionPlaceholder: "O que vamos decidir?",
    choicesLabel: "OPÇÕES",
    choicePlaceholder: "Adicione uma opção",
    addChoice: "Adicionar outra opção",
    removeChoice: { "Remover opção \($0)" },
    submit: "Enviar para escolha",
    missingTitle: "Escreva o que você quer decidir.",
    titleTooLong: { "Deixe a pergunta com menos de \($0) caracteres." },
    emptyChoice: "Dê um nome para cada opção.",
    choiceTooLong: { "Deixe cada opção com menos de \($0) caracteres." },
    duplicateChoices: "Faça cada opção diferente.",
    eyebrowNeedsYou: "PRECISA DE VOCÊ",
    eyebrowWaiting: "ESPERANDO",
    eyebrowDecided: "DECIDIDO",
    eyebrowDecision: "DECISÃO",
    chooseThis: "Escolher esta",
    leftWithPartnerTitle: "Você deixou isso com sua pessoa.",
    leftWithPartnerDetail: "Vai se resolver aqui quando a escolha chegar.",
    unavailableTitle: "Esta decisão não está disponível.",
    unavailableDetail: "Ela pode ter mudado enquanto o mundo de vocês atualizava.",
    decidedTogether: "Decidido pelos dois",
    resolvedNote: "Uma pequena coisa resolvida dentro do mundo de vocês.",
    signalNeedsDetail: { "\(person($0)) está esperando sua escolha" },
    signalWaitingTitleMany: { "\($0) decisões com \(personInline($1))" },
    signalWaitingDetailOne: { "Esperando \(personInline($0))" },
    signalWaitingDetailMany: "Esperando em silêncio",
    signalSettledDetail: "Vocês resolveram isso juntos",
    statusReconnect: "Toque para reconectar",
    statusForYou: { "\($0) para você" },
    statusWithPartner: { "\($0) com \(personInline($1))" },
    statusNothingOpen: "Nada em aberto",
    statusAllSettled: "Tudo resolvido"
)

private let portugueseErrors = Strings.Errors(
    authentication: { error in
        switch error {
        case .invalidCredentials: "Esse e-mail ou senha não parece certo."
        case .invalidEmail: "Digite um e-mail válido."
        case .emailAlreadyInUse: "Já existe uma conta com este e-mail."
        case .weakPassword: "Escolha uma senha com pelo menos 6 caracteres."
        case .networkUnavailable: "Você está offline. Verifique sua conexão e tente de novo."
        case .cancelled: "A entrada foi cancelada."
        case .unavailable: "Não dá para entrar agora."
        case .unknown: "Algo deu errado. Tente de novo."
        }
    },
    user: { error in
        switch error {
        case .documentNotFound: "Não encontramos o seu perfil."
        case .invalidData: "Seu perfil precisa de atenção antes de abrirmos o mundo de vocês."
        case .networkUnavailable: "Você está offline. Sua conta está segura — tente de novo quando se conectar."
        case .permissionDenied: "Não conseguimos acessar seu perfil. Entre de novo, por favor."
        case .unavailable: "Seu perfil está temporariamente indisponível. Tente de novo."
        case .unknown: "Não conseguimos terminar de preparar seu perfil. Tente de novo."
        }
    },
    couple: { error in
        switch error {
        case .profileRequired: "Termine seu perfil antes de criar o mundo de vocês."
        case .alreadyInCouple: "Esta conta já pertence a um Couple World."
        case .coupleNotFound: "Não encontramos este Couple World."
        case .coupleAlreadyFull: "Este Couple World já é compartilhado."
        case .networkUnavailable: "Você está offline. Reconecte e tente de novo."
        case .permissionDenied: "Você não tem acesso a este Couple World."
        case .invalidData: "Este Couple World precisa de atenção antes de abrir."
        case .unknown: "Não conseguimos preparar o mundo de vocês. Tente de novo."
        }
    },
    invite: { error in
        switch error {
        case .inviteInvalid: "Este convite não é válido. Peça um link novo para sua pessoa."
        case .inviteExpired: "Este convite expirou. Peça para sua pessoa compartilhar outro."
        case .inviteAlreadyUsed: "Este convite já foi usado ou substituído."
        case .cannotAcceptOwnInvite: "Este convite é para sua pessoa — não para a conta que criou ele."
        case .alreadyInCouple: "Esta conta já pertence a um Couple World."
        case .coupleNotFound: "O Couple World deste convite não existe mais."
        case .coupleAlreadyFull: "Este Couple World já é compartilhado por duas pessoas."
        case .configurationMissing: "Links de convite não estão configurados nesta versão."
        case .networkUnavailable: "Você está offline. Reconecte e tente de novo."
        case .permissionDenied: "Não conseguimos verificar este convite para a sua conta."
        case .unknown: "Não conseguimos aceitar este convite. Tente de novo."
        }
    },
    dailyExperience: { error in
        switch error {
        case .notFound: "O Hoje não está disponível agora."
        case .alreadyAnswered: "Sua resposta já faz parte deste momento."
        case .notAMember, .permissionDenied: "Este momento pertence ao Couple World de vocês."
        case .unavailable: "O Hoje está temporariamente indisponível."
        case .networkUnavailable: "Você está offline. Sua resposta está segura — tente de novo daqui a pouco."
        case .invalidData, .unknown: "Não conseguimos abrir o momento de hoje. Tente de novo."
        }
    },
    decision: { error in
        switch error {
        case .invalidInput: "Confira a pergunta e as opções."
        case .notFound: "Esta decisão não está mais disponível."
        case .notResponder: "Esta decisão está esperando sua pessoa."
        case .alreadyResolved: "Esta decisão já foi tomada."
        case .networkUnavailable: "Você está offline. Tente de novo quando a conexão voltar."
        case .permissionDenied: "Esta decisão pertence a outro Couple World."
        case .unavailable: "As decisões estão temporariamente indisponíveis."
        case .invalidData, .unknown: "Não conseguimos abrir esta decisão. Tente de novo."
        }
    },
    market: { error in
        switch error {
        case .invalidInput: "Confira o que você está adicionando."
        case .itemNotFound: "Este item não está mais na lista."
        case .runNotFound: "Esta ida ao mercado já terminou."
        case .notShopper: "Só quem está no mercado pode encerrar esta ida."
        case .runAlreadyFinished: "Esta ida ao mercado já foi encerrada."
        case .listFull: "Sua lista está cheia. Tire algumas coisas primeiro."
        case .networkUnavailable: "Você está offline. Sua lista está segura — tente de novo quando voltar."
        // Não nomeia uma causa que não pode conhecer: uma recusa aqui quase
        // nunca é a pessoa estar no Couple World errado.
        case .permissionDenied: "Não conseguimos abrir sua lista. Se continuar acontecendo, saia e entre de novo."
        case .unavailable: "Sua lista está temporariamente indisponível."
        case .invalidData, .unknown: "Não conseguimos abrir sua lista. Tente de novo."
        }
    },
    chore: { error in
        switch error {
        case .invalidInput: "Confira a tarefa e com que frequência ela volta."
        case .notFound: "Esta tarefa não está mais na sua lista."
        case .notYourTurn: "Esta é a vez da sua pessoa."
        case .alreadyDone: "Esta já foi resolvida."
        case .listFull: "Sua lista está cheia. Termine ou remova algumas primeiro."
        case .networkUnavailable: "Você está offline. Tente de novo quando a conexão voltar."
        case .permissionDenied, .unavailable, .invalidData, .unknown:
            "Não conseguimos abrir as tarefas de casa. Se continuar acontecendo, saia e entre de novo."
        }
    }
)
