# Omni

Aplicação Rails 8 (produto). Implementada **do zero** em Rails / Hotwire / ViewComponent,
respeitando os ADRs do projeto. Este é um **repositório próprio**; a governança (ADRs,
roadmap, decisões) vive no repositório de planejamento separado, e os diretórios
`_origem/` e `_mockup/` de lá são **apenas referência** — nada deles é copiado para cá.

## Stack

- Ruby 3.3 · Rails 8.1
- PostgreSQL 16
- Autenticação: Devise · Autorização: Pundit
- Jobs: Solid Queue · Rate limiting: Rack::Attack · CSRF nativo do Rails
- UI: Hotwire (Turbo + Stimulus) + ViewComponent

## Desenvolvimento via Docker

Ruby/Rails rodam em container (não exigem instalação no host). A imagem de dev fica em
`.devstack/` e só adiciona as dependências nativas da gem `pg`.

### 1. Imagem de dev

```bash
docker build -t omni-rails-dev .devstack
```

### 2. Infra (rede, volume de gems, Postgres)

```bash
docker network create omni_net
docker volume create omni_bundle
docker run -d --name omni_db --network omni_net \
  -e POSTGRES_USER=omni -e POSTGRES_PASSWORD=omni_dev -e POSTGRES_DB=omni_development \
  -p 5433:5432 postgres:16-alpine
```

### 3. Rodar comandos Rails

```bash
docker run --rm --network omni_net \
  -v "$PWD:/app" -v omni_bundle:/usr/local/bundle -w /app \
  omni-rails-dev bash -c "bundle install && bin/rails db:prepare && bin/rails test"
```

> No Git Bash (Windows), prefixe `docker run ...` com `MSYS_NO_PATHCONV=1` para evitar
> conversão dos caminhos `/app` e `/usr/local/bundle`.

## Banco de dados

Um banco por ambiente (Solid Queue no banco primário): `omni_development`, `omni_test`.
Conexão via container `omni_db` na rede `omni_net` (sobrescrevível por `DB_HOST` /
`DB_USERNAME` / `DB_PASSWORD`).

## Testes

```bash
docker run --rm --network omni_net -v "$PWD:/app" -v omni_bundle:/usr/local/bundle -w /app \
  omni-rails-dev bash -c "bin/rails test"
```

## CI

`.github/workflows/ci.yml` roda: brakeman + bundler-audit (`scan_ruby`),
importmap audit (`scan_js`), rubocop (`lint`) e a suíte de testes (`test`) com Postgres.
