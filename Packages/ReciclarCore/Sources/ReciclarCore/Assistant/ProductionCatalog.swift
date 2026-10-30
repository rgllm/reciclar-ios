import Foundation

extension SortingCatalog {
    /// Curated Portugal sorting guide. Each entry states only what its cited source says.
    public static let production: SortingCatalog = {
        let reviewed = Calendar(identifier: .gregorian).date(
            from: DateComponents(timeZone: TimeZone(identifier: "Europe/Lisbon"), year: 2026, month: 10, day: 12)
        )!
        func source(_ id: String, _ title: String, _ url: String, _ scope: String) -> GuidanceSource {
            GuidanceSource(
                id: id,
                title: title,
                url: URL(string: url)!,
                geographicScope: scope,
                reviewedOn: reviewed
            )
        }

        let portugal = "Portugal. Orientação para embalagens e ecopontos."
        let lipor = "Municípios associados da LIPOR. Confirme a regra no seu município."
        let apa = "Portugal. Agência Portuguesa do Ambiente."
        let sdrScope = "Portugal. Sistema de depósito e reembolso."
        let pharmacy = "Portugal continental e ilhas. Farmácias e parafarmácias aderentes."
        let electrao = "Portugal. Rede de recolha Electrão."

        let spvPasso = source(
            "spv-passo",
            "Sociedade Ponto Verde · Passo a passo da reciclagem de embalagens",
            "https://www.pontoverde.pt/recicla/passo-a-passo-para-se-tornar-um-expert-na-reciclagem-de-embalagens/",
            portugal
        )
        let spvVai = source(
            "spv-vai",
            "Sociedade Ponto Verde · Vai ou não vai para o ecoponto?",
            "https://www.pontoverde.pt/recicla/vai-ou-nao-vai-para-o-ecoponto/",
            portugal
        )
        let spvDuvidas = source(
            "spv-duvidas",
            "Sociedade Ponto Verde · Dúvidas comuns na separação",
            "https://www.pontoverde.pt/recicla/duvidas-comuns-na-separacao-de-residuos/",
            portugal
        )
        let spvSeparacao = source(
            "spv-separacao",
            "Sociedade Ponto Verde · Separação de resíduos",
            "https://www.pontoverde.pt/a-reciclagem/separacao-de-residuos/",
            portugal
        )
        let spvPersistem = source(
            "spv-persistem",
            "Sociedade Ponto Verde · Dúvidas que persistem na reciclagem de embalagens",
            "https://www.pontoverde.pt/recicla/que-duvidas-persistem-no-que-toca-a-reciclagem-de-embalagens/",
            portugal
        )
        let spvCafe = source(
            "spv-cafe",
            "Sociedade Ponto Verde · Cápsulas de café",
            "https://www.pontoverde.pt/recicla/descubra-como-ser-mais-sustentavel-quando-bebe-cafe/",
            portugal
        )
        let liporAmarelo = source(
            "lipor-amarelo",
            "LIPOR · Ecoponto amarelo",
            "https://www.lipor.pt/pt/perguntas-frequentes/reciclagem-2/faq-197/",
            lipor
        )
        let liporAzul = source(
            "lipor-azul",
            "LIPOR · Ecoponto azul",
            "https://www.lipor.pt/pt/perguntas-frequentes/reciclagem-2/faq-198/",
            lipor
        )
        let liporVerde = source(
            "lipor-verde",
            "LIPOR · Ecoponto verde",
            "https://www.lipor.pt/pt/perguntas-frequentes/reciclagem-2/faq-200/",
            lipor
        )
        let liporVidro = source(
            "lipor-vidro",
            "LIPOR · O vidro não acaba aqui",
            "https://www.lipor.pt/pt/o-vidro-nao-acaba-aqui/",
            lipor
        )
        let liporPapel = source(
            "lipor-papel",
            "LIPOR · Polígrafo da reciclagem (papel)",
            "https://www.lipor.pt/pt/perguntas-frequentes/o-poligrafo-da-reciclagem/faq-159/",
            lipor
        )
        let liporPerfume = source(
            "lipor-perfume",
            "LIPOR · Frascos de perfume",
            "https://www.lipor.pt/pt/perguntas-frequentes/reciclagem-2/faq-10/",
            lipor
        )
        let liporMaquilhagem = source(
            "lipor-maquilhagem",
            "LIPOR · Boiões de creme e maquilhagem",
            "https://www.lipor.pt/pt/perguntas-frequentes/reciclagem-2/faq-11/",
            lipor
        )
        let liporCD = source(
            "lipor-cd",
            "LIPOR · CD e DVD",
            "https://www.lipor.pt/pt/perguntas-frequentes/reciclagem-2/faq-78/",
            lipor
        )
        let liporFilamento = source(
            "lipor-filamento",
            "LIPOR · Lâmpadas de filamento",
            "https://www.lipor.pt/pt/perguntas-frequentes/reciclagem-2/faq-65/",
            lipor
        )
        let liporFluorescente = source(
            "lipor-fluorescente",
            "LIPOR · Lâmpadas fluorescentes",
            "https://www.lipor.pt/pt/perguntas-frequentes/reciclagem-2/faq-58/",
            lipor
        )
        let liporMonstros = source(
            "lipor-monstros",
            "LIPOR · Monstros domésticos",
            "https://www.lipor.pt/pt/perguntas-frequentes/reciclagem-2/faq-151/",
            lipor
        )
        let liporRetoma = source(
            "lipor-retoma",
            "LIPOR · Retoma de aparelhos elétricos",
            "https://www.lipor.pt/pt/perguntas-frequentes/reciclagem-2/faq-152/",
            lipor
        )
        let liporCompostavel = source(
            "lipor-compostavel",
            "LIPOR · Sacos compostáveis",
            "https://www.lipor.pt/pt/perguntas-frequentes/reciclagem-2/faq-170/",
            lipor
        )
        let liporCopos = source(
            "lipor-copos",
            "LIPOR · Copos de papel",
            "https://www.lipor.pt/pt/perguntas-frequentes/reciclagem-2/faq-172/",
            lipor
        )
        let liporFraldas = source(
            "lipor-fraldas",
            "LIPOR · Fraldas",
            "https://www.lipor.pt/pt/perguntas-frequentes/o-poligrafo-da-reciclagem/faq-169/",
            lipor
        )
        let liporRoupa = source(
            "lipor-roupa",
            "LIPOR · Roupa usada",
            "https://www.lipor.pt/pt/perguntas-frequentes/o-poligrafo-da-reciclagem/faq-115/",
            lipor
        )
        let liporCastanho = source(
            "lipor-castanho",
            "LIPOR · Balde castanho",
            "https://www.lipor.pt/pt/perguntas-frequentes/tratamento-centralizado-recolha-seletiva-de-biorresiduos/faq-219/",
            lipor
        )
        let liporOleos = source(
            "lipor-oleos",
            "LIPOR · Óleos alimentares usados",
            "https://www.lipor.pt/pt/recicla-te/oleos-alimentares-usados/",
            lipor
        )
        let liporOleosFAQ = source(
            "lipor-oleos-faq",
            "LIPOR · Destino dos óleos alimentares usados",
            "https://www.lipor.pt/pt/perguntas-frequentes/reciclagem-2/faq-149/",
            lipor
        )
        let apaRU = source(
            "apa-ru",
            "APA · Resíduos urbanos",
            "https://apambiente.pt/residuos/residuos-urbanos",
            apa
        )
        let apaBiorresiduos = source(
            "apa-biorresiduos",
            "APA · Biorresíduos",
            "https://apambiente.pt/residuos/biorresiduos",
            apa
        )
        let apaTexteis = source(
            "apa-texteis",
            "APA · Perguntas frequentes sobre têxteis (dezembro de 2025)",
            "https://apambiente.pt/sites/default/files/_Residuos/FluxosEspecificosResiduos/Texteis/perguntas-frequentes_texteis.pdf",
            apa
        )
        let apaOleos = source(
            "apa-oleos",
            "APA · Óleos alimentares",
            "https://apambiente.pt/residuos/oleos-alimentares",
            apa
        )
        let apaPilhas = source(
            "apa-pilhas",
            "APA · Perguntas frequentes sobre pilhas e acumuladores",
            "https://apambiente.pt/sites/default/files/_Residuos/FluxosEspecificosResiduos/ERE/Perguntas%20Frequentes%20-%20Pilhas%20e%20Acumuladores.pdf",
            apa
        )
        let sdr = source(
            "sdr",
            "SDR Portugal · Perguntas frequentes da volta",
            "https://sdrportugal.pt/faqs/",
            sdrScope
        )
        let valormed = source(
            "valormed",
            "VALORMED · Cidadão e comunidade",
            "https://valormed.pt/como-participar/cidadao-e-comunidade/",
            pharmacy
        )
        let electraoPilhas = source(
            "electrao-pilhas",
            "Electrão · Pilhas e baterias",
            "https://electrao.pt/pilhas-baterias/",
            electrao
        )
        let electraoEquipment = source(
            "electrao-eee",
            "Electrão · Equipamentos elétricos",
            "https://electrao.pt/equipamentos-electricos/",
            electrao
        )
        let electraoLamps = source(
            "electrao-lampadas",
            "Electrão · Categorias de equipamentos elétricos",
            "https://electrao.pt/equipamentos-electricos/pt/equipamentos-electricos/sobre-equipamentos-electricos",
            electrao
        )
        let electraoRede = source(
            "electrao-rede",
            "Electrão · Entrega na rede",
            "https://electrao.pt/equipamentos-electricos/pt/rede-electrao/pedir-uma-recolha",
            electrao
        )

        let glass: Set<WasteCategory.ID> = [WasteCategory.sampleGlass.id]
        let paper: Set<WasteCategory.ID> = [WasteCategory.samplePaper.id]
        let packaging: Set<WasteCategory.ID> = [WasteCategory.samplePackaging.id]
        let verde = "Ecoponto verde"
        let azul = "Ecoponto azul"
        let amarelo = "Ecoponto amarelo"
        let indiferenciado = "Resíduos indiferenciados"
        let drain = "Escorra os restos, espalme e não lave."
        let voltaException = "Se tiver o símbolo volta, até 3 litros, e estiver vazia, intacta e com o código de barras legível, entregue num Ponto volta."
        let semContentor = "Sem contentor citado"
        let regraLipor = "Regra LIPOR (Grande Porto) — pode variar no teu município"
        let regrasVariam = "As regras variam: confirma com o teu município"

        func item(
            _ id: String,
            _ name: String,
            aliases: [String] = [],
            destination: String,
            preparation: [String] = [],
            exceptions: [String] = [],
            clarification: String? = nil,
            categories: Set<WasteCategory.ID> = [],
            outOfScope: Bool = false,
            sources: [GuidanceSource]
        ) -> SortingEntry {
            SortingEntry(
                id: id,
                canonicalName: name,
                aliases: aliases,
                destination: destination,
                preparation: preparation,
                exceptions: exceptions,
                clarification: clarification,
                categoryIDs: categories,
                isOutOfScope: outOfScope,
                sources: sources
            )
        }

        let sources = [
            spvPasso, spvVai, spvDuvidas, spvSeparacao, spvPersistem, spvCafe,
            liporAmarelo, liporAzul, liporVerde, liporVidro, liporPapel, liporPerfume, liporMaquilhagem,
            liporCD, liporFilamento, liporFluorescente, liporMonstros, liporRetoma, liporCompostavel,
            liporCopos, liporFraldas, liporRoupa, liporCastanho, liporOleos, liporOleosFAQ,
            apaRU, apaBiorresiduos, apaTexteis, apaOleos, apaPilhas, sdr, valormed,
            electraoPilhas, electraoEquipment, electraoLamps, electraoRede,
        ]
        return SortingCatalog(
            version: "2026.10.12.2",
            entries: [
                item(
                    "glass-bottle", "garrafa de vidro",
                    aliases: ["vinho", "cerveja", "azeite em vidro", "água em vidro"],
                    destination: verde,
                    clarification: "Na área da LIPOR, as tampas e caricas com menos de 5 cm podem ir com a garrafa; as maiores seguem para o ecoponto amarelo.",
                    categories: glass,
                    sources: [spvPasso, liporVerde, liporVidro]
                ),
                item(
                    "glass-jar", "frasco de vidro",
                    aliases: ["frasco de conserva", "frasco de molho"],
                    destination: verde,
                    exceptions: ["Ampolas de medicamentos não vão para o ecoponto verde."],
                    categories: glass,
                    sources: [spvPasso, liporVerde]
                ),
                item(
                    "glass-pot", "boião de vidro",
                    aliases: ["boião de compota", "boião de doce", "boião de iogurte de vidro"],
                    destination: verde,
                    clarification: "A LIPOR inclui boiões de doce e de iogurte quando são de vidro.",
                    categories: glass,
                    sources: [spvPasso, liporVerde]
                ),
                item(
                    "perfume", "frasco de perfume de vidro",
                    aliases: ["perfume"],
                    destination: verde,
                    preparation: ["De preferência sem restos. Não é preciso lavar."],
                    clarification: "A LIPOR aceita o frasco mesmo com algum resto, se não der para o esvaziar. Pode ir com o borrifador.",
                    categories: glass,
                    sources: [spvPasso, liporPerfume, liporVidro]
                ),
                item(
                    "varnish-jar", "frasco de verniz de vidro",
                    aliases: ["verniz em vidro"],
                    destination: verde,
                    preparation: ["Entregue o frasco o mais vazio possível."],
                    categories: glass,
                    sources: [spvPasso, spvDuvidas, liporVidro]
                ),
                item(
                    "deodorant-glass", "frasco de desodorizante de vidro",
                    aliases: ["desodorizante com roll-on de vidro"],
                    destination: verde,
                    clarification: "Aplica-se ao frasco de vidro, mesmo com a esfera de roll-on. A lata de spray vai para o ecoponto amarelo.",
                    categories: glass,
                    sources: [spvPasso]
                ),
                item(
                    "product-glass", "copo de vidro que acondiciona um produto",
                    aliases: ["copo de vela"],
                    destination: verde,
                    clarification: "A LIPOR aceita copos de vidro que acondicionam produtos, por exemplo velas. Copos de beber não vão para o verde.",
                    categories: glass,
                    sources: [liporVidro]
                ),
                item(
                    "cream-glass", "boião de creme de vidro",
                    aliases: ["creme em vidro"],
                    destination: verde,
                    preparation: ["Entregue o frasco o mais vazio possível."],
                    clarification: "Se for de porcelana ou cerâmica, a LIPOR indica os resíduos indiferenciados.",
                    categories: glass,
                    sources: [spvDuvidas, liporMaquilhagem, liporVidro]
                ),
                item(
                    "cardboard", "caixa de cartão",
                    aliases: ["cartão", "caixa de cereais", "caixa de sapatos"],
                    destination: azul,
                    categories: paper,
                    sources: [spvPasso, liporAzul]
                ),
                item(
                    "newspaper", "jornal",
                    aliases: ["jornais", "revista", "revistas"],
                    destination: azul,
                    categories: paper,
                    sources: [spvPasso, liporAzul]
                ),
                item(
                    "writing-paper", "papel de escrita e impressão",
                    aliases: ["folhas", "fotocópias", "envelopes", "papel de embrulho"],
                    destination: azul,
                    categories: paper,
                    sources: [spvPasso, spvVai, liporAzul]
                ),
                item(
                    "notebook", "caderno de papel",
                    aliases: ["cadernos", "dossiers"],
                    destination: azul,
                    categories: paper,
                    sources: [spvPasso, liporAzul]
                ),
                item(
                    "paper-bag", "saco de papel",
                    aliases: ["saco do pão", "saco de papel das compras"],
                    destination: azul,
                    exceptions: ["Se o saco do pão tiver uma janela de plástico, separe: o papel vai para o azul e o plástico para o amarelo."],
                    categories: paper,
                    sources: [spvPasso, spvVai, liporAzul]
                ),
                item(
                    "pizza-box", "caixa de pizza",
                    aliases: ["caixa de pastelaria", "saco de comida para levar"],
                    destination: azul,
                    preparation: ["Pode ir suja se não tiver restos de comida agarrados."],
                    exceptions: ["Na área da LIPOR, o papel com gordura ou muita humidade não vai para o azul: segue para os resíduos indiferenciados."],
                    categories: paper,
                    sources: [spvPasso, liporAzul, liporPapel]
                ),
                item(
                    "tobacco-card", "cartão do maço de tabaco",
                    aliases: ["caixa do maço"],
                    destination: azul,
                    clarification: "Separe o plástico, que vai para o amarelo, e o papel do interior, que vai para os resíduos indiferenciados.",
                    categories: paper,
                    sources: [spvDuvidas, spvVai, liporAzul]
                ),
                item(
                    "egg-box", "caixa de ovos de papel",
                    aliases: ["caixa de ovos"],
                    destination: azul,
                    clarification: regraLipor,
                    categories: paper,
                    sources: [liporPapel]
                ),
                item(
                    "roll-core", "tubo de cartão do rolo de papel",
                    aliases: ["rolo de papel higiénico", "rolo de cozinha"],
                    destination: azul,
                    clarification: "A LIPOR aceita o tubo de cartão. O papel higiénico e o papel de cozinha, limpos ou sujos, não vão para o azul.",
                    categories: paper,
                    sources: [liporAzul]
                ),
                item(
                    "leaflet", "folheto",
                    aliases: ["panfleto"],
                    destination: azul,
                    clarification: "Indicação da LIPOR para a sua área.",
                    categories: paper,
                    sources: [liporAzul, liporPapel]
                ),
                item(
                    "thermal-receipt", "talão térmico",
                    aliases: ["talão multibanco", "recibo térmico"],
                    destination: azul,
                    clarification: regraLipor,
                    categories: paper,
                    sources: [liporPapel]
                ),
                item(
                    "paper-cup", "copo de papel",
                    aliases: ["copo de café de papel", "copo de cartão"],
                    destination: regrasVariam,
                    sources: [liporCopos, liporPapel]
                ),
                item(
                    "pet-food-bag", "saco de comida de animais em papel",
                    aliases: ["saco de ração em papel"],
                    destination: azul,
                    clarification: "Indicação da LIPOR para a sua área.",
                    categories: paper,
                    sources: [liporPapel]
                ),
                item(
                    "phone-book", "lista telefónica",
                    aliases: ["lista telefónica de papel"],
                    destination: azul,
                    clarification: "Indicação da LIPOR para a sua área.",
                    categories: paper,
                    sources: [liporPapel]
                ),
                item(
                    "plastic-bottle", "garrafa de plástico sem símbolo volta",
                    aliases: ["garrafa de água sem símbolo volta", "garrafa de refrigerante sem símbolo volta"],
                    destination: amarelo,
                    preparation: [drain],
                    exceptions: [voltaException],
                    categories: packaging,
                    sources: [spvVai, spvSeparacao, sdr, liporAmarelo]
                ),
                item(
                    "plastic-jug", "garrafão de plástico",
                    aliases: ["garrafão"],
                    destination: amarelo,
                    preparation: [drain],
                    exceptions: [voltaException],
                    clarification: "A volta abrange garrafas e latas de bebidas até 3 litros.",
                    categories: packaging,
                    sources: [liporAmarelo, spvSeparacao, sdr]
                ),
                item(
                    "yogurt", "embalagem de iogurte",
                    aliases: ["copo de iogurte", "iogurte"],
                    destination: amarelo,
                    preparation: [drain],
                    clarification: "A LIPOR lista as embalagens de iogurte no amarelo. Se o boião for de vidro, vai para o verde.",
                    categories: packaging,
                    sources: [liporAmarelo, spvVai]
                ),
                item(
                    "detergent", "embalagem de detergente",
                    aliases: ["detergente", "amaciador"],
                    destination: amarelo,
                    preparation: [drain],
                    categories: packaging,
                    sources: [liporAmarelo, spvVai]
                ),
                item(
                    "shampoo", "embalagem de champô",
                    aliases: ["champô", "shampoo", "gel de banho"],
                    destination: amarelo,
                    preparation: [drain],
                    clarification: "A LIPOR inclui embalagens de produtos de higiene e beleza no amarelo.",
                    categories: packaging,
                    sources: [liporAmarelo, spvVai]
                ),
                item(
                    "plastic-bag", "saco de plástico",
                    aliases: ["saco de compras"],
                    destination: amarelo,
                    preparation: [drain],
                    categories: packaging,
                    sources: [liporAmarelo, spvVai]
                ),
                item(
                    "food-bag", "pacote de plástico de alimentos",
                    aliases: ["pacote de arroz", "pacote de massa", "pacote de bolachas"],
                    destination: amarelo,
                    preparation: [drain],
                    clarification: "A LIPOR lista pacotes de arroz, massa, manteiga e bolachas no amarelo.",
                    categories: packaging,
                    sources: [liporAmarelo, spvVai]
                ),
                item(
                    "butter", "embalagem de manteiga",
                    aliases: ["manteiga", "margarina"],
                    destination: amarelo,
                    preparation: [drain],
                    clarification: "A LIPOR lista a embalagem de manteiga entre os pacotes de plástico do amarelo.",
                    categories: packaging,
                    sources: [liporAmarelo]
                ),
                item(
                    "can", "lata de conserva",
                    aliases: ["lata de atum", "lata de feijão"],
                    destination: amarelo,
                    preparation: ["Pode ir com gordura. Escorra e espalme. Não é preciso lavar nem tirar o rótulo."],
                    categories: packaging,
                    sources: [spvPasso, liporAmarelo]
                ),
                item(
                    "drink-can", "lata de bebida sem símbolo volta",
                    aliases: ["lata de refrigerante sem símbolo volta"],
                    destination: amarelo,
                    preparation: [drain],
                    exceptions: [voltaException],
                    categories: packaging,
                    sources: [spvSeparacao, sdr, liporAmarelo]
                ),
                item(
                    "drink-carton", "pacote de cartão para alimentos líquidos",
                    aliases: ["pacote de leite", "pacote de sumo", "pacote de natas", "pacote de polpa de tomate", "pacote de vinho"],
                    destination: amarelo,
                    preparation: [drain],
                    clarification: "Por fora parecem cartão, mas são revestidos, por isso não vão para o azul. A Sociedade Ponto Verde dá como exemplos leite, sumos, natas e polpa de tomate. A LIPOR inclui também o pacote de vinho.",
                    categories: packaging,
                    sources: [spvPasso, liporAmarelo, liporAzul]
                ),
                item(
                    "oil-bottle", "garrafa de plástico de óleo vazia",
                    aliases: ["garrafa de azeite de plástico vazia"],
                    destination: amarelo,
                    preparation: ["Escorra e espalme. Não é preciso lavar nem tirar o rótulo."],
                    exceptions: ["Se ainda tiver óleo alimentar usado, entregue a garrafa no oleão ou na recolha municipal, não no amarelo."],
                    categories: packaging,
                    sources: [liporAmarelo, liporOleos]
                ),
                item(
                    "aerosol", "aerossol",
                    aliases: ["lata de desodorizante", "spray", "espuma de barbear"],
                    destination: amarelo,
                    categories: packaging,
                    sources: [spvPasso, spvDuvidas, liporAmarelo]
                ),
                item(
                    "toothpaste", "pasta de dentes",
                    aliases: ["bisnaga de pasta de dentes"],
                    destination: amarelo,
                    preparation: ["Coloque a tampa."],
                    categories: packaging,
                    sources: [spvVai, spvDuvidas]
                ),
                item(
                    "styrofoam", "embalagem de esferovite",
                    aliases: ["cuvete de esferovite", "esferovite de proteção"],
                    destination: amarelo,
                    clarification: "Inclui cuvetes e pedaços usados para proteger produtos, e embalagens de fruta, carne ou peixe, sujas ou limpas.",
                    categories: packaging,
                    sources: [spvPasso, spvDuvidas]
                ),
                item(
                    "aluminum-tray", "bandeja de alumínio",
                    aliases: ["tabuleiro de takeaway", "alumínio de embalagem"],
                    destination: amarelo,
                    categories: packaging,
                    sources: [spvPasso]
                ),
                item(
                    "aluminum-foil", "papel de alumínio",
                    aliases: ["folha de alumínio", "alumínio de cozinha"],
                    destination: amarelo,
                    clarification: "A Sociedade Ponto Verde inclui o papel de alumínio usado como embalagem, por exemplo para embrulhar alimentos.",
                    categories: packaging,
                    sources: [spvPersistem]
                ),
                item(
                    "aluminum-cream", "boião de creme em lata",
                    aliases: ["lata de creme"],
                    destination: amarelo,
                    categories: packaging,
                    sources: [spvPasso]
                ),
                item(
                    "makeup", "maquilhagem",
                    aliases: ["rímel", "batom", "paleta de sombras", "blush"],
                    destination: amarelo,
                    categories: packaging,
                    sources: [spvDuvidas]
                ),
                item(
                    "potato-net", "rede de batatas ou cebolas",
                    aliases: ["rede de batatas", "rede de cebolas"],
                    destination: amarelo,
                    categories: packaging,
                    sources: [spvVai]
                ),
                item(
                    "hanger", "cabide que veio com a roupa",
                    aliases: ["cabide de plástico", "cabide de metal"],
                    destination: amarelo,
                    clarification: "A Sociedade Ponto Verde refere os cabides de plástico e de metal que vêm com roupa nova.",
                    categories: packaging,
                    sources: [spvVai]
                ),
                item(
                    "paint-tin", "lata pequena de tinta",
                    aliases: ["lata de tinta"],
                    destination: amarelo,
                    clarification: "A Sociedade Ponto Verde inclui as pequenas latas de tinta no amarelo. O texto não diz o que fazer ao resto de tinta.",
                    categories: packaging,
                    sources: [spvPasso]
                ),
                item(
                    "tobacco-plastic", "plástico do maço de tabaco",
                    aliases: ["invólucro do maço"],
                    destination: amarelo,
                    categories: packaging,
                    sources: [spvDuvidas, spvVai]
                ),
                item(
                    "volta", "embalagem com símbolo volta",
                    aliases: ["garrafa com símbolo volta", "lata com símbolo volta", "volta"],
                    destination: "Ponto volta",
                    preparation: ["Tem de estar vazia, intacta e com o código de barras legível."],
                    exceptions: ["Se estiver danificada, deformada ou não estiver completamente vazia, ou se o código de barras ou o símbolo não estiverem visíveis, coloque no ecoponto do material. Nesse caso o depósito perde-se."],
                    clarification: "A volta abrange garrafas e latas de plástico, alumínio e aço até 3 litros. O sistema entrou em funcionamento a 10 de abril de 2026.",
                    sources: [sdr, spvSeparacao]
                ),
                item(
                    "cigarette-butt", "beata",
                    aliases: ["beatas"],
                    destination: indiferenciado,
                    clarification: "A Sociedade Ponto Verde indica o lixo comum.",
                    sources: [spvDuvidas]
                ),
                item(
                    "napkin", "guardanapo de papel",
                    aliases: ["lenço de papel", "papel higiénico", "papel de cozinha", "toalhitas"],
                    destination: indiferenciado,
                    exceptions: ["Não vão para o ecoponto azul, limpos ou sujos."],
                    clarification: "A Sociedade Ponto Verde indica o lixo indiferenciado como destino habitual, ou a recolha de biorresíduos quando as regras locais o permitirem.",
                    sources: [spvPasso, spvPersistem, liporAzul, liporPapel]
                ),
                item(
                    "greasy-paper", "papel sujo de gordura",
                    aliases: ["papel com gordura", "papel húmido"],
                    destination: indiferenciado,
                    exceptions: ["Não vai para o ecoponto azul."],
                    clarification: "Indicação da LIPOR. Uma caixa de pizza sem restos de comida agarrados pode ir para o azul.",
                    sources: [liporPapel, spvPasso]
                ),
                item(
                    "blender-cup", "copo de varinha partido",
                    aliases: ["balde de plástico partido", "copo da varinha mágica"],
                    destination: indiferenciado,
                    exceptions: ["Não vai para o ecoponto amarelo."],
                    sources: [spvVai]
                ),
                item(
                    "tobacco-inner", "papel interior do maço de tabaco",
                    aliases: ["papel do interior do maço"],
                    destination: indiferenciado,
                    sources: [spvVai]
                ),
                item(
                    "ceramic-cream", "boião de creme de porcelana ou cerâmica",
                    aliases: ["boião de porcelana"],
                    destination: indiferenciado,
                    exceptions: ["Não vai para o ecoponto verde."],
                    clarification: "Indicação da LIPOR.",
                    sources: [liporMaquilhagem]
                ),
                item(
                    "filament-lamp", "lâmpada de filamento",
                    aliases: ["lâmpada normal"],
                    destination: indiferenciado,
                    exceptions: ["Não a coloque no ecoponto verde."],
                    clarification: "Indicação da LIPOR para lâmpadas normais ou de filamento. Não cobre lâmpadas fluorescentes nem economizadoras.",
                    sources: [liporFilamento, spvPasso, liporVidro]
                ),
                item(
                    "compostable-bag", "saco compostável",
                    aliases: ["saco biodegradável"],
                    destination: indiferenciado,
                    exceptions: ["Na área da LIPOR, não o coloque no contentor castanho dos resíduos alimentares."],
                    clarification: "A LIPOR indica o compostor caseiro, se fizer compostagem, ou o lixo comum. A APA refere que a recolha seletiva de biorresíduos está em implementação.",
                    sources: [liporCompostavel, apaRU]
                ),
                item(
                    "coffee-capsule", "cápsula de café",
                    aliases: ["cápsulas de café"],
                    destination: "Retoma da marca",
                    exceptions: ["Não vão para o ecoponto amarelo."],
                    clarification: "A Sociedade Ponto Verde indica a retoma por algumas marcas, como a Nespresso, a Dolce Gusto e a Delta. Se a marca não recolher, esta página não indica outro contentor.",
                    sources: [spvCafe]
                ),
                item(
                    "food-scraps", "restos de comida",
                    aliases: ["restos alimentares", "sobras de comida", "cascas de fruta", "borras de café"],
                    destination: "Compostagem doméstica ou recolha seletiva municipal",
                    clarification: "A APA indica a compostagem doméstica ou comunitária, ou a recolha seletiva municipal. Na área da LIPOR, o balde castanho recebe sobras cozinhadas, fruta, legumes, carne, peixe, pão, ovos, queijo, chá e borras de café. \(regraLipor)",
                    sources: [apaBiorresiduos, liporCastanho]
                ),
                item(
                    "textiles", "roupa e têxteis usados",
                    aliases: ["roupa usada", "têxteis", "sapatos usados", "calçado usado"],
                    destination: "Contentor de têxteis",
                    exceptions: ["Não vão para o ecoponto."],
                    clarification: "A APA indica contentores específicos para têxteis: contentores de roupa usada, lojas ou associações de solidariedade, e alguns ecocentros. A LIPOR confirma que a roupa não se entrega no ecoponto.",
                    sources: [apaTexteis, liporRoupa]
                ),
                item(
                    "cooking-oil", "óleo alimentar usado",
                    aliases: ["óleo usado", "azeite usado", "óleo de girassol usado"],
                    destination: "Oleão ou recolha municipal",
                    preparation: ["Deixe arrefecer. Feche numa garrafa ou garrafão de plástico."],
                    exceptions: ["A LIPOR apresenta o oleão como alternativa a despejar pelo esgoto. Se não houver oleão, a LIPOR indica guardar o óleo numa garrafa ou absorvê-lo com guardanapos usados e colocar nos resíduos indiferenciados."],
                    clarification: "\(regraLipor). Na área da LIPOR, entregue no oleão, o contentor laranja. A APA indica que o óleo alimentar de casa se entrega ao município.",
                    sources: [liporOleos, liporOleosFAQ, apaOleos]
                ),
                item(
                    "batteries", "pilhas",
                    aliases: ["pilha", "acumulador portátil", "pilha-botão"],
                    destination: "Recipiente de pilhas",
                    exceptions: ["Não as coloque no ecoponto amarelo."],
                    clarification: "A APA indica o comerciante, outros pontos de recolha e o recipiente próprio para pilhas instalado nalguns ecopontos. Não é o contentor das embalagens. A Electrão recolhe pilhas na sua rede.",
                    sources: [apaPilhas, liporAmarelo, electraoPilhas]
                ),
                item(
                    "car-battery", "bateria de automóvel",
                    aliases: ["bateria de carro"],
                    destination: "Comerciante ou ecocentro",
                    clarification: "A APA indica, para um particular, a retoma gratuita no comerciante — no caso de veículos particulares não comerciais, mesmo sem comprar outra bateria — ou o depósito gratuito no ecocentro.",
                    sources: [apaPilhas]
                ),
                item(
                    "medicine", "medicamentos fora de uso",
                    aliases: ["comprimidos", "xarope", "embalagem de medicamento", "ampola de medicamento", "seringa doseadora"],
                    destination: "Farmácia ou parafarmácia",
                    preparation: ["Pode entregar embalagens com restos, cartonagens, blisters, frascos, ampolas, seringas doseadoras e acessórios como colheres ou copos de medida."],
                    exceptions: ["Não entregue agulhas, seringas com agulha, termómetros de mercúrio, aparelhos elétricos, pensos, produtos químicos, detergentes, fraldas nem radiografias no contentor VALORMED. Ampolas de medicamentos não vão para o ecoponto verde."],
                    clarification: "Entregue nas farmácias e parafarmácias aderentes, no continente e nas ilhas. Não deite no lixo doméstico nem no esgoto.",
                    sources: [valormed, spvPasso]
                ),
                item(
                    "electronics", "equipamento elétrico",
                    aliases: ["telemóvel", "carregador", "televisão", "computador", "micro-ondas", "frigorífico"],
                    destination: "Ponto de recolha de equipamentos elétricos",
                    exceptions: ["Não o coloque no ecoponto amarelo."],
                    clarification: "A Electrão indica um local da Rede Electrão. Na área da LIPOR, ao comprar um aparelho equivalente pode entregar o antigo na loja, pedir a recolha à câmara ou levar ao ecocentro.",
                    sources: [electraoEquipment, liporAmarelo, liporRetoma]
                ),
                item(
                    "led-lamp", "lâmpada LED",
                    aliases: ["led", "lâmpadas led"],
                    destination: "Ponto de recolha de lâmpadas",
                    exceptions: ["Não a coloque num ecoponto."],
                    clarification: "A Electrão inclui as LED na categoria das lâmpadas. Um particular entrega num ponto da rede Electrão. A Sociedade Ponto Verde indica que as lâmpadas não vão para os três ecopontos.",
                    sources: [electraoLamps, electraoRede, spvPersistem]
                ),
                item(
                    "fluorescent-lamp", "lâmpada fluorescente",
                    aliases: ["lâmpada economizadora"],
                    destination: "Ponto de recolha de lâmpadas",
                    exceptions: ["Não a coloque nos resíduos indiferenciados nem no ecoponto verde."],
                    clarification: "A LIPOR indica a entrega na loja ao comprar uma nova, num centro de recolha de equipamentos elétricos ou num ecocentro que as aceite. As economizadoras seguem o mesmo destino. A Electrão inclui lâmpadas nos locais de entrega.",
                    sources: [liporFluorescente, liporVidro, electraoEquipment]
                ),
                item(
                    "bulky", "móveis e monos",
                    aliases: ["sofá", "colchão", "móvel"],
                    destination: "Recolha de monos ou ecocentro",
                    exceptions: ["Não os coloque no contentor dos resíduos indiferenciados."],
                    clarification: "Indicação da LIPOR: se ainda servirem, pode doá-los; caso contrário, combine a recolha com a câmara ou a junta, ou leve ao ecocentro. A APA refere que a recolha seletiva de mobiliário e volumosos está em implementação.",
                    sources: [liporMonstros, apaRU]
                ),
                item(
                    "drinking-glass", "copo de beber",
                    aliases: ["copo de vidro", "copo partido"],
                    destination: "Ecocentro",
                    exceptions: ["Não vai para o ecoponto verde."],
                    clarification: "A LIPOR pede para confirmar se o ecocentro aceita este vidro. A Sociedade Ponto Verde exclui copos partidos do ecoponto verde.",
                    sources: [liporVidro, spvPasso]
                ),
                item(
                    "ceramics", "loiça e cerâmica",
                    aliases: ["prato", "chávena", "porcelana"],
                    destination: "Ecocentro",
                    exceptions: ["Não vai para o ecoponto verde."],
                    clarification: "A LIPOR pede para confirmar se o ecocentro aceita o material.",
                    sources: [liporVidro, spvPasso]
                ),
                item(
                    "pyrex", "vidro de forno",
                    aliases: ["pirex", "pyrex"],
                    destination: "Ecocentro",
                    exceptions: ["Não vai para o ecoponto verde."],
                    clarification: "A LIPOR inclui o pirex entre os vidros que não são embalagem e aponta o ecocentro, mediante confirmação.",
                    sources: [liporVidro, spvPasso, liporVerde]
                ),
                item(
                    "mirror", "espelho",
                    aliases: ["espelho partido"],
                    destination: "Ecocentro",
                    exceptions: ["Não vai para o ecoponto verde."],
                    clarification: "A LIPOR pede para confirmar se o ecocentro aceita espelhos.",
                    sources: [liporVidro, spvPasso]
                ),
                item(
                    "window", "vidro de janela",
                    aliases: ["vidro plano", "aquário", "vidro de chuveiro"],
                    destination: "Ecocentro",
                    exceptions: ["Não vai para o ecoponto verde."],
                    clarification: "A LIPOR inclui janelas, molduras, aquários e vidro de chuveiro, e pede para confirmar a aceitação no ecocentro.",
                    sources: [liporVidro, liporVerde, spvPasso]
                ),
                item(
                    "pans", "tachos e panelas",
                    aliases: ["panela", "frigideira", "talheres", "garfo", "faca", "colher"],
                    destination: "Ecocentro",
                    exceptions: ["Não vão para o ecoponto amarelo."],
                    sources: [spvDuvidas, liporAmarelo]
                ),
                item(
                    "cutting-board", "tábua de cozinha",
                    aliases: ["tábua de madeira", "tábua de plástico"],
                    destination: "Ecocentro",
                    exceptions: ["Não vai para o ecoponto azul nem para o amarelo."],
                    sources: [spvDuvidas]
                ),
                item(
                    "cds", "CD e DVD",
                    aliases: ["cd", "dvd"],
                    destination: "Ecocentro",
                    exceptions: ["Não vão para o ecoponto amarelo."],
                    clarification: "Na área da LIPOR também podem ir para o ecocentro móvel.",
                    sources: [liporCD, liporAmarelo]
                ),
                item(
                    "cork", "rolha de cortiça",
                    aliases: ["cortiça", "rolha"],
                    destination: "Recolha de cortiça",
                    clarification: "A Sociedade Ponto Verde indica um projeto da Quercus em alguns supermercados. Não é um ecoponto.",
                    sources: [spvDuvidas]
                ),
                item(
                    "wood-box", "caixa de madeira",
                    aliases: ["embalagem de madeira"],
                    destination: "Lixo comum ou ecocentro",
                    exceptions: ["Não vai para o ecoponto azul."],
                    sources: [spvDuvidas]
                ),
                item(
                    "sharps", "agulhas e seringas",
                    aliases: ["agulha", "seringa", "corto-perfurante"],
                    destination: semContentor,
                    exceptions: ["A VALORMED não aceita agulhas, seringas nem outro material corto-perfurante no contentor da farmácia."],
                    clarification: "Não há, neste catálogo, um destino doméstico citado para este material.",
                    outOfScope: true,
                    sources: [valormed]
                ),
                item(
                    "lighter", "isqueiro",
                    aliases: ["isqueiro partido"],
                    destination: semContentor,
                    exceptions: ["Apesar de ter plástico e metal, a Sociedade Ponto Verde indica que não vai para o ecoponto amarelo."],
                    clarification: "O artigo não indica o contentor de substituição.",
                    outOfScope: true,
                    sources: [spvDuvidas]
                ),
                item(
                    "hose", "mangueira de jardim",
                    aliases: ["mangueira"],
                    destination: semContentor,
                    exceptions: ["A Sociedade Ponto Verde indica que nem o tubo nem os encaixes vão para o ecoponto."],
                    clarification: "O artigo não indica o contentor de substituição.",
                    outOfScope: true,
                    sources: [spvVai]
                ),
                item(
                    "diapers", "fraldas",
                    aliases: ["fralda"],
                    destination: indiferenciado,
                    exceptions: ["Não vão para o ecoponto."],
                    clarification: "\(regraLipor). A LIPOR indica o lixo comum, porque não existe reciclagem deste material em Portugal.",
                    sources: [liporFraldas]
                ),
                item(
                    "tools", "ferramentas",
                    aliases: ["martelo", "chave de fendas"],
                    destination: semContentor,
                    exceptions: ["A LIPOR indica que as ferramentas não se entregam no ecoponto amarelo."],
                    clarification: "O texto não indica o contentor de substituição.",
                    outOfScope: true,
                    sources: [liporAmarelo]
                ),
                item(
                    "tracing-paper", "papel vegetal",
                    destination: indiferenciado,
                    exceptions: ["Não vai para o ecoponto azul."],
                    clarification: "A Sociedade Ponto Verde indica o lixo indiferenciado, por ser geralmente revestido e ficar em contacto com gordura e alimentos.",
                    sources: [spvPersistem, liporAzul]
                ),
                item(
                    "rejected-paper", "papel plastificado ou autocolante",
                    aliases: ["papel laminado", "autocolante", "papel de lustro"],
                    destination: semContentor,
                    exceptions: ["A LIPOR indica que não se entregam no ecoponto azul."],
                    clarification: "A frase da LIPOR que aponta o indiferenciado refere-se a lenços, guardanapos, papel com gordura e copos revestidos, não a esta lista. Não há aqui um contentor de substituição citado.",
                    outOfScope: true,
                    sources: [liporPapel]
                ),
                item(
                    "chemical-packaging", "embalagem de produto químico",
                    aliases: ["produto químico"],
                    destination: semContentor,
                    exceptions: ["A LIPOR indica que não se entrega no ecoponto azul."],
                    clarification: "O texto não indica o contentor de substituição.",
                    outOfScope: true,
                    sources: [liporPapel]
                ),
            ],
            sources: sources
        )
    }()
}
