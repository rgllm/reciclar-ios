# Reciclar

Aplicação iOS gratuita para encontrar ecopontos em Portugal e saber onde colocar resíduos domésticos.

O mapa, os níveis de enchimento e as estatísticas vêm da Reciclar API (`https://ecopontos-api.rgllm.workers.dev`). A app não pede conta nem início de sessão. A cobertura não é de todo o país.

Repositório: [rgllm/reciclar-ios](https://github.com/rgllm/reciclar-ios)

## Separadores

- **Mapa** — ecopontos, filtros, favoritos e direções
- **Separação** — guia para vidro, papel e cartão, e mistura de embalagens
- **Estatísticas** — totais publicados pela API

## Desenvolvimento

Xcode 26, iOS 26, só iPhone. Identificador `com.rgllm.reciclar`.

```sh
xcodegen generate
open Reciclar.xcodeproj
```

Esquema: `Reciclar`.

```sh
swift build --package-path Packages/ReciclarCore
swift run --package-path Packages/ReciclarCore ReciclarCoreChecks
```

O contrato HTTP que a app usa está em [BACKEND.md](BACKEND.md).

## Medir o arranque num iPhone

A categoria `Launch` do subsistema `com.rgllm.reciclar` regista uma vez por processo
`App init to first frame: … ms`. Usa um relógio monotónico desde o início de
`ReciclarApp.init` até ao segundo callback de `CADisplayLink` da vista raiz.
É uma aproximação ao primeiro frame apresentado, não inclui o arranque do processo
anterior ao init, nem espera por mosaicos do mapa, rede ou cache. O display link
é invalidado logo após a medição.

No Xcode, instala uma build Release no iPhone. Termina a app, abre-a pelo ícone
sem debugger e consulta o registo na app Consola do Mac, com o iPhone ligado,
filtrando por `com.rgllm.reciclar` e `Launch`. Repete pelo menos cinco vezes,
mantendo o mesmo aparelho, cache, viewport e condições de rede. Compara as medianas.
Mede separadamente a instalação sem cache e o relançamento com cache preenchida.
Para uma comparação anterior/posterior, o commit que adiciona esta medição mantém
a ordem de arranque anterior; o commit seguinte adia a carga até ao primeiro frame.
O instrumento App Launch do Instruments permite também comparar o arranque completo.

## Licença

MIT. Ver [LICENSE](LICENSE).
