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

## Licença

MIT. Ver [LICENSE](LICENSE).
