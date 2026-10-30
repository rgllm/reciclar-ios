import Foundation

extension SortingCatalog {
    /// Placeholder catalog for previews and package checks. The app uses `production`.
    public static let development: SortingCatalog = {
        let reviewed = Calendar(identifier: .gregorian).date(
            from: DateComponents(timeZone: TimeZone(secondsFromGMT: 0), year: 2026, month: 9, day: 8))!
        let signage = GuidanceSource(
            id: "signage", title: "Sociedade Ponto Verde · Guia dos ecopontos",
            url: URL(string: "https://www.pontoverde.pt/wp-content/uploads/2025/09/SINALETICA_COMUNICACAO.pdf")!,
            geographicScope: "Portugal; orientação para embalagens e ecopontos", reviewedOn: reviewed)
        let packaging = GuidanceSource(
            id: "packaging", title: "LIPOR · Embalagens no ecoponto amarelo",
            url: URL(string: "https://www.lipor.pt/pt/perguntas-frequentes/reciclagem-2/faq-197/")!,
            geographicScope: "Municípios LIPOR; confirmar regras locais", reviewedOn: reviewed)
        let current = GuidanceSource(
            id: "current", title: "Sociedade Ponto Verde · Separação de resíduos",
            url: URL(string: "https://www.pontoverde.pt/a-reciclagem/separacao-de-residuos/")!,
            geographicScope: "Portugal; orientação para embalagens e ecopontos", reviewedOn: reviewed)
        return SortingCatalog(
            version: "2026.09.08",
            entries: [
                SortingEntry(
                    id: "glass-bottle", canonicalName: "garrafa de vidro", aliases: ["vinho", "azeite em vidro"],
                    destination: "Vidro · ecoponto verde", preparation: ["Esvazia a embalagem."],
                    exceptions: ["Não inclui frascos de medicamentos."], categoryIDs: [WasteCategory.sampleGlass.id],
                    isOutOfScope: false, sources: [signage]),
                SortingEntry(
                    id: "glass-jar", canonicalName: "frasco de vidro",
                    aliases: ["frasco de compota", "frasco de conserva"], destination: "Vidro · ecoponto verde",
                    preparation: ["Esvazia a embalagem."], exceptions: ["Não inclui frascos de medicamentos."],
                    categoryIDs: [WasteCategory.sampleGlass.id], isOutOfScope: false, sources: [signage]),
                SortingEntry(
                    id: "glass-pot", canonicalName: "boião de vidro", aliases: ["boião de iogurte"],
                    destination: "Vidro · ecoponto verde", preparation: ["Esvazia a embalagem."],
                    exceptions: ["Não inclui frascos de medicamentos."], categoryIDs: [WasteCategory.sampleGlass.id],
                    isOutOfScope: false, sources: [signage]),
                SortingEntry(
                    id: "perfume", canonicalName: "frasco de perfume de vidro", aliases: ["perfume"],
                    destination: "Vidro · ecoponto verde", preparation: ["Esvazia a embalagem."],
                    exceptions: ["Não inclui frascos de medicamentos."], categoryIDs: [WasteCategory.sampleGlass.id],
                    isOutOfScope: false, sources: [signage]),
                SortingEntry(
                    id: "paper-cardboard", canonicalName: "caixa de cartão",
                    aliases: ["cartão", "caixa de cereais", "caixa de sapatos"],
                    destination: "Papel e cartão · ecoponto azul",
                    preparation: ["Mantém o papel limpo e seco. Espalma as caixas."],
                    exceptions: ["Papel com gordura ou restos de comida não vai para o azul."],
                    categoryIDs: [WasteCategory.samplePaper.id], isOutOfScope: false, sources: [signage]),
                SortingEntry(
                    id: "newspaper", canonicalName: "jornal", aliases: ["jornais"],
                    destination: "Papel e cartão · ecoponto azul",
                    preparation: ["Mantém o papel limpo e seco. Espalma as caixas."],
                    exceptions: ["Papel com gordura ou restos de comida não vai para o azul."],
                    categoryIDs: [WasteCategory.samplePaper.id], isOutOfScope: false, sources: [signage]),
                SortingEntry(
                    id: "magazine", canonicalName: "revista", aliases: ["revistas"],
                    destination: "Papel e cartão · ecoponto azul",
                    preparation: ["Mantém o papel limpo e seco. Espalma as caixas."],
                    exceptions: ["Papel com gordura ou restos de comida não vai para o azul."],
                    categoryIDs: [WasteCategory.samplePaper.id], isOutOfScope: false, sources: [signage]),
                SortingEntry(
                    id: "writing-paper", canonicalName: "papel de escrita e impressão",
                    aliases: ["folhas", "fotocópias", "papel"], destination: "Papel e cartão · ecoponto azul",
                    preparation: ["Mantém o papel limpo e seco. Espalma as caixas."],
                    exceptions: ["Papel com gordura ou restos de comida não vai para o azul."],
                    categoryIDs: [WasteCategory.samplePaper.id], isOutOfScope: false, sources: [signage]),
                SortingEntry(
                    id: "paper-bag", canonicalName: "saco de papel", aliases: ["saco do pão"],
                    destination: "Papel e cartão · ecoponto azul",
                    preparation: ["Mantém o papel limpo e seco. Espalma as caixas."],
                    exceptions: ["Papel com gordura ou restos de comida não vai para o azul."],
                    categoryIDs: [WasteCategory.samplePaper.id], isOutOfScope: false, sources: [signage]),
                SortingEntry(
                    id: "notebook", canonicalName: "caderno de papel", aliases: ["cadernos"],
                    destination: "Papel e cartão · ecoponto azul",
                    preparation: ["Mantém o papel limpo e seco. Espalma as caixas."],
                    exceptions: ["Papel com gordura ou restos de comida não vai para o azul."],
                    categoryIDs: [WasteCategory.samplePaper.id], isOutOfScope: false, sources: [signage]),
                SortingEntry(
                    id: "pizza-box", canonicalName: "caixa de pizza", aliases: ["caixa pizza"],
                    destination: "Papel e cartão · ecoponto azul",
                    preparation: ["Separa a parte limpa para o papel e cartão."],
                    exceptions: ["A parte com gordura ou comida fica fora das recolhas deste guia."],
                    categoryIDs: [WasteCategory.samplePaper.id], isOutOfScope: false, sources: [signage]),
                SortingEntry(
                    id: "plastic-bottle", canonicalName: "garrafa de plástico sem símbolo volta",
                    aliases: ["garrafa de plástico", "garrafa de água"], destination: "Embalagens · ecoponto amarelo",
                    preparation: ["Escorre os restos. Não precisas de lavar."],
                    exceptions: ["Se tiver o símbolo volta, fica fora das recolhas deste guia."],
                    categoryIDs: [WasteCategory.samplePackaging.id], isOutOfScope: false, sources: [packaging, current]),
                SortingEntry(
                    id: "plastic-jug", canonicalName: "garrafão de plástico sem símbolo volta", aliases: ["garrafão"],
                    destination: "Embalagens · ecoponto amarelo",
                    preparation: ["Escorre os restos. Não precisas de lavar."],
                    exceptions: ["Se tiver o símbolo volta, fica fora das recolhas deste guia."],
                    categoryIDs: [WasteCategory.samplePackaging.id], isOutOfScope: false, sources: [packaging, current]),
                SortingEntry(
                    id: "yogurt", canonicalName: "embalagem de iogurte de plástico",
                    aliases: ["iogurte", "copinho de iogurte"], destination: "Embalagens · ecoponto amarelo",
                    preparation: ["Escorre os restos. Não precisas de lavar."], exceptions: [],
                    categoryIDs: [WasteCategory.samplePackaging.id], isOutOfScope: false, sources: [packaging]),
                SortingEntry(
                    id: "detergent", canonicalName: "embalagem de detergente", aliases: ["detergente", "amaciador"],
                    destination: "Embalagens · ecoponto amarelo",
                    preparation: ["Escorre os restos. Não precisas de lavar."], exceptions: [],
                    categoryIDs: [WasteCategory.samplePackaging.id], isOutOfScope: false, sources: [packaging]),
                SortingEntry(
                    id: "shampoo", canonicalName: "embalagem de champô",
                    aliases: ["champô", "shampoo", "gel de banho"], destination: "Embalagens · ecoponto amarelo",
                    preparation: ["Escorre os restos. Não precisas de lavar."], exceptions: [],
                    categoryIDs: [WasteCategory.samplePackaging.id], isOutOfScope: false, sources: [packaging]),
                SortingEntry(
                    id: "plastic-bag", canonicalName: "saco de plástico", aliases: ["sacos de compras"],
                    destination: "Embalagens · ecoponto amarelo",
                    preparation: ["Escorre os restos. Não precisas de lavar."], exceptions: [],
                    categoryIDs: [WasteCategory.samplePackaging.id], isOutOfScope: false, sources: [packaging]),
                SortingEntry(
                    id: "food-bag", canonicalName: "pacote de plástico de alimentos",
                    aliases: ["pacote de arroz", "massa", "bolachas"], destination: "Embalagens · ecoponto amarelo",
                    preparation: ["Escorre os restos. Não precisas de lavar."], exceptions: [],
                    categoryIDs: [WasteCategory.samplePackaging.id], isOutOfScope: false, sources: [packaging]),
                SortingEntry(
                    id: "butter", canonicalName: "embalagem de manteiga de plástico",
                    aliases: ["manteiga", "margarina"], destination: "Embalagens · ecoponto amarelo",
                    preparation: ["Escorre os restos. Não precisas de lavar."], exceptions: [],
                    categoryIDs: [WasteCategory.samplePackaging.id], isOutOfScope: false, sources: [packaging]),
                SortingEntry(
                    id: "can", canonicalName: "lata de conserva", aliases: ["lata de atum", "lata de feijão", "lata"],
                    destination: "Embalagens · ecoponto amarelo",
                    preparation: ["Escorre os restos. Não precisas de lavar."], exceptions: [],
                    categoryIDs: [WasteCategory.samplePackaging.id], isOutOfScope: false, sources: [packaging]),
                SortingEntry(
                    id: "drink-can", canonicalName: "lata de bebida sem símbolo volta",
                    aliases: ["lata de bebida", "refrigerante"], destination: "Embalagens · ecoponto amarelo",
                    preparation: ["Escorre os restos. Não precisas de lavar."],
                    exceptions: ["Se tiver o símbolo volta, fica fora das recolhas deste guia."],
                    categoryIDs: [WasteCategory.samplePackaging.id], isOutOfScope: false, sources: [packaging, current]),
                SortingEntry(
                    id: "milk", canonicalName: "pacote de leite", aliases: ["leite", "tetrapak"],
                    destination: "Embalagens · ecoponto amarelo",
                    preparation: ["Escorre os restos. Não precisas de lavar."], exceptions: [],
                    categoryIDs: [WasteCategory.samplePackaging.id], isOutOfScope: false, sources: [packaging]),
                SortingEntry(
                    id: "juice", canonicalName: "pacote de sumo", aliases: ["sumo"],
                    destination: "Embalagens · ecoponto amarelo",
                    preparation: ["Escorre os restos. Não precisas de lavar."], exceptions: [],
                    categoryIDs: [WasteCategory.samplePackaging.id], isOutOfScope: false, sources: [packaging]),
                SortingEntry(
                    id: "cream", canonicalName: "pacote de natas", aliases: ["natas"],
                    destination: "Embalagens · ecoponto amarelo",
                    preparation: ["Escorre os restos. Não precisas de lavar."], exceptions: [],
                    categoryIDs: [WasteCategory.samplePackaging.id], isOutOfScope: false, sources: [packaging]),
                SortingEntry(
                    id: "tomato", canonicalName: "pacote de polpa de tomate", aliases: ["polpa de tomate"],
                    destination: "Embalagens · ecoponto amarelo",
                    preparation: ["Escorre os restos. Não precisas de lavar."], exceptions: [],
                    categoryIDs: [WasteCategory.samplePackaging.id], isOutOfScope: false, sources: [packaging]),
                SortingEntry(
                    id: "oil-bottle", canonicalName: "garrafa de plástico de óleo vazia",
                    aliases: ["garrafa de óleo", "garrafa de azeite de plástico"],
                    destination: "Embalagens · ecoponto amarelo",
                    preparation: ["Escorre os restos. Não precisas de lavar."], exceptions: [],
                    categoryIDs: [WasteCategory.samplePackaging.id], isOutOfScope: false, sources: [packaging]),
                SortingEntry(
                    id: "aerosol", canonicalName: "aerossol vazio", aliases: ["desodorizante em spray"],
                    destination: "Embalagens · ecoponto amarelo", preparation: ["A embalagem deve estar vazia."],
                    exceptions: ["Se ainda tiver produto, não uses esta indicação."],
                    categoryIDs: [WasteCategory.samplePackaging.id], isOutOfScope: false, sources: [packaging]),
                SortingEntry(
                    id: "glass-tableware", canonicalName: "copo de vidro", aliases: ["copo partido"],
                    destination: "Fora das recolhas deste guia", preparation: [],
                    exceptions: [
                        "Este resíduo não tem um destino suportado neste guia. Não o coloques num ecoponto por aproximação ao material."
                    ], categoryIDs: [], isOutOfScope: true, sources: []),
                SortingEntry(
                    id: "ceramics", canonicalName: "loiça e cerâmica", aliases: ["prato", "chávena", "porcelana"],
                    destination: "Fora das recolhas deste guia", preparation: [],
                    exceptions: [
                        "Este resíduo não tem um destino suportado neste guia. Não o coloques num ecoponto por aproximação ao material."
                    ], categoryIDs: [], isOutOfScope: true, sources: []),
                SortingEntry(
                    id: "pyrex", canonicalName: "vidro de forno", aliases: ["pirex", "pyrex"],
                    destination: "Fora das recolhas deste guia", preparation: [],
                    exceptions: [
                        "Este resíduo não tem um destino suportado neste guia. Não o coloques num ecoponto por aproximação ao material."
                    ], categoryIDs: [], isOutOfScope: true, sources: []),
                SortingEntry(
                    id: "mirror", canonicalName: "espelho", aliases: ["espelhos"],
                    destination: "Fora das recolhas deste guia", preparation: [],
                    exceptions: [
                        "Este resíduo não tem um destino suportado neste guia. Não o coloques num ecoponto por aproximação ao material."
                    ], categoryIDs: [], isOutOfScope: true, sources: []),
                SortingEntry(
                    id: "window", canonicalName: "vidro de janela", aliases: ["vidro plano"],
                    destination: "Fora das recolhas deste guia", preparation: [],
                    exceptions: [
                        "Este resíduo não tem um destino suportado neste guia. Não o coloques num ecoponto por aproximação ao material."
                    ], categoryIDs: [], isOutOfScope: true, sources: []),
                SortingEntry(
                    id: "bulb", canonicalName: "lâmpada", aliases: ["LED", "fluorescente"],
                    destination: "Fora das recolhas deste guia", preparation: [],
                    exceptions: [
                        "Este resíduo não tem um destino suportado neste guia. Não o coloques num ecoponto por aproximação ao material."
                    ], categoryIDs: [], isOutOfScope: true, sources: []),
                SortingEntry(
                    id: "medicine-glass", canonicalName: "frasco de medicamentos", aliases: ["xarope"],
                    destination: "Fora das recolhas deste guia", preparation: [],
                    exceptions: [
                        "Este resíduo não tem um destino suportado neste guia. Não o coloques num ecoponto por aproximação ao material."
                    ], categoryIDs: [], isOutOfScope: true, sources: []),
                SortingEntry(
                    id: "dirty-paper", canonicalName: "papel sujo de gordura",
                    aliases: ["papel de cozinha", "guardanapo"], destination: "Fora das recolhas deste guia",
                    preparation: [],
                    exceptions: [
                        "Este resíduo não tem um destino suportado neste guia. Não o coloques num ecoponto por aproximação ao material."
                    ], categoryIDs: [], isOutOfScope: true, sources: []),
                SortingEntry(
                    id: "tracing-paper", canonicalName: "papel vegetal", aliases: ["papel de forno"],
                    destination: "Fora das recolhas deste guia", preparation: [],
                    exceptions: [
                        "Este resíduo não tem um destino suportado neste guia. Não o coloques num ecoponto por aproximação ao material."
                    ], categoryIDs: [], isOutOfScope: true, sources: []),
                SortingEntry(
                    id: "stickers", canonicalName: "autocolantes", aliases: ["etiqueta autocolante"],
                    destination: "Fora das recolhas deste guia", preparation: [],
                    exceptions: [
                        "Este resíduo não tem um destino suportado neste guia. Não o coloques num ecoponto por aproximação ao material."
                    ], categoryIDs: [], isOutOfScope: true, sources: []),
                SortingEntry(
                    id: "laminated-paper", canonicalName: "papel plastificado dos dois lados",
                    aliases: ["papel laminado"], destination: "Fora das recolhas deste guia", preparation: [],
                    exceptions: [
                        "Este resíduo não tem um destino suportado neste guia. Não o coloques num ecoponto por aproximação ao material."
                    ], categoryIDs: [], isOutOfScope: true, sources: []),
                SortingEntry(
                    id: "diapers", canonicalName: "fraldas", aliases: ["fralda"],
                    destination: "Fora das recolhas deste guia", preparation: [],
                    exceptions: [
                        "Este resíduo não tem um destino suportado neste guia. Não o coloques num ecoponto por aproximação ao material."
                    ], categoryIDs: [], isOutOfScope: true, sources: []),
                SortingEntry(
                    id: "batteries", canonicalName: "pilhas e baterias", aliases: ["pilha", "bateria"],
                    destination: "Fora das recolhas deste guia", preparation: [],
                    exceptions: [
                        "Este resíduo não tem um destino suportado neste guia. Não o coloques num ecoponto por aproximação ao material."
                    ], categoryIDs: [], isOutOfScope: true, sources: []),
                SortingEntry(
                    id: "electronics", canonicalName: "equipamento elétrico",
                    aliases: ["telemóvel", "carregador", "televisão", "computador", "frigorífico"],
                    destination: "Fora das recolhas deste guia", preparation: [],
                    exceptions: [
                        "Este resíduo não tem um destino suportado neste guia. Não o coloques num ecoponto por aproximação ao material."
                    ], categoryIDs: [], isOutOfScope: true, sources: []),
                SortingEntry(
                    id: "pans", canonicalName: "tachos e panelas", aliases: ["panela", "frigideira"],
                    destination: "Fora das recolhas deste guia", preparation: [],
                    exceptions: [
                        "Este resíduo não tem um destino suportado neste guia. Não o coloques num ecoponto por aproximação ao material."
                    ], categoryIDs: [], isOutOfScope: true, sources: []),
                SortingEntry(
                    id: "cutlery", canonicalName: "talheres", aliases: ["garfo", "faca", "colher"],
                    destination: "Fora das recolhas deste guia", preparation: [],
                    exceptions: [
                        "Este resíduo não tem um destino suportado neste guia. Não o coloques num ecoponto por aproximação ao material."
                    ], categoryIDs: [], isOutOfScope: true, sources: []),
                SortingEntry(
                    id: "tools", canonicalName: "ferramentas", aliases: ["martelo", "chave de fendas"],
                    destination: "Fora das recolhas deste guia", preparation: [],
                    exceptions: [
                        "Este resíduo não tem um destino suportado neste guia. Não o coloques num ecoponto por aproximação ao material."
                    ], categoryIDs: [], isOutOfScope: true, sources: []),
                SortingEntry(
                    id: "discs", canonicalName: "CD e DVD", aliases: ["cd", "dvd"],
                    destination: "Fora das recolhas deste guia", preparation: [],
                    exceptions: [
                        "Este resíduo não tem um destino suportado neste guia. Não o coloques num ecoponto por aproximação ao material."
                    ], categoryIDs: [], isOutOfScope: true, sources: []),
                SortingEntry(
                    id: "toys", canonicalName: "brinquedos de plástico", aliases: ["brinquedo"],
                    destination: "Fora das recolhas deste guia", preparation: [],
                    exceptions: [
                        "Este resíduo não tem um destino suportado neste guia. Não o coloques num ecoponto por aproximação ao material."
                    ], categoryIDs: [], isOutOfScope: true, sources: []),
                SortingEntry(
                    id: "oil", canonicalName: "óleo alimentar usado", aliases: ["óleo", "óleo usado"],
                    destination: "Fora das recolhas deste guia", preparation: [],
                    exceptions: [
                        "Este resíduo não tem um destino suportado neste guia. Não o coloques num ecoponto por aproximação ao material."
                    ], categoryIDs: [], isOutOfScope: true, sources: []),
                SortingEntry(
                    id: "medicine", canonicalName: "medicamentos", aliases: ["comprimidos"],
                    destination: "Fora das recolhas deste guia", preparation: [],
                    exceptions: [
                        "Este resíduo não tem um destino suportado neste guia. Não o coloques num ecoponto por aproximação ao material."
                    ], categoryIDs: [], isOutOfScope: true, sources: []),
                SortingEntry(
                    id: "bulky", canonicalName: "móveis e colchões", aliases: ["sofá", "colchão", "móvel", "cadeira"],
                    destination: "Fora das recolhas deste guia", preparation: [],
                    exceptions: [
                        "Este resíduo não tem um destino suportado neste guia. Não o coloques num ecoponto por aproximação ao material."
                    ], categoryIDs: [], isOutOfScope: true, sources: []),
                SortingEntry(
                    id: "textiles", canonicalName: "roupa e calçado", aliases: ["roupa", "sapatos", "têxteis"],
                    destination: "Fora das recolhas deste guia", preparation: [],
                    exceptions: [
                        "Este resíduo não tem um destino suportado neste guia. Não o coloques num ecoponto por aproximação ao material."
                    ], categoryIDs: [], isOutOfScope: true, sources: []),
                SortingEntry(
                    id: "food", canonicalName: "restos de alimentos", aliases: ["cascas", "comida", "biorresíduos"],
                    destination: "Fora das recolhas deste guia", preparation: [],
                    exceptions: [
                        "Este resíduo não tem um destino suportado neste guia. Não o coloques num ecoponto por aproximação ao material."
                    ], categoryIDs: [], isOutOfScope: true, sources: []),
                SortingEntry(
                    id: "garden", canonicalName: "resíduos de jardim", aliases: ["ramos", "folhas de árvore", "relva"],
                    destination: "Fora das recolhas deste guia", preparation: [],
                    exceptions: [
                        "Este resíduo não tem um destino suportado neste guia. Não o coloques num ecoponto por aproximação ao material."
                    ], categoryIDs: [], isOutOfScope: true, sources: []),
                SortingEntry(
                    id: "paint", canonicalName: "tintas e solventes", aliases: ["tinta", "verniz", "solvente"],
                    destination: "Fora das recolhas deste guia", preparation: [],
                    exceptions: [
                        "Este resíduo não tem um destino suportado neste guia. Não o coloques num ecoponto por aproximação ao material."
                    ], categoryIDs: [], isOutOfScope: true, sources: []),
                SortingEntry(
                    id: "rubble", canonicalName: "entulho", aliases: ["cimento", "tijolos"],
                    destination: "Fora das recolhas deste guia", preparation: [],
                    exceptions: [
                        "Este resíduo não tem um destino suportado neste guia. Não o coloques num ecoponto por aproximação ao material."
                    ], categoryIDs: [], isOutOfScope: true, sources: []),
                SortingEntry(
                    id: "sharps", canonicalName: "seringas e agulhas", aliases: ["seringa", "agulha"],
                    destination: "Fora das recolhas deste guia", preparation: [],
                    exceptions: [
                        "Este resíduo não tem um destino suportado neste guia. Não o coloques num ecoponto por aproximação ao material."
                    ], categoryIDs: [], isOutOfScope: true, sources: []),
                SortingEntry(
                    id: "cork", canonicalName: "rolhas de cortiça", aliases: ["cortiça"],
                    destination: "Fora das recolhas deste guia", preparation: [],
                    exceptions: [
                        "Este resíduo não tem um destino suportado neste guia. Não o coloques num ecoponto por aproximação ao material."
                    ], categoryIDs: [], isOutOfScope: true, sources: []),
                SortingEntry(
                    id: "coffee", canonicalName: "cápsulas de café", aliases: ["cápsula"],
                    destination: "Fora das recolhas deste guia", preparation: [],
                    exceptions: [
                        "Este resíduo não tem um destino suportado neste guia. Não o coloques num ecoponto por aproximação ao material."
                    ], categoryIDs: [], isOutOfScope: true, sources: []),
                SortingEntry(
                    id: "volta", canonicalName: "embalagem com símbolo volta",
                    aliases: ["volta", "garrafa com depósito", "lata com depósito"],
                    destination: "Fora das recolhas deste guia", preparation: [],
                    exceptions: [
                        "Este resíduo não tem um destino suportado neste guia. Não o coloques num ecoponto por aproximação ao material."
                    ], categoryIDs: [], isOutOfScope: true, sources: [current]),
            ], sources: [signage, packaging, current])
    }()
}
