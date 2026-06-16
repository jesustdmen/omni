# Dev image para a Fundação Rails (M1) — NÃO é o Dockerfile de deploy do app.
# Base Ruby + dependências nativas para a gem pg. Gems do app vivem em volume nomeado.
FROM ruby:3.3

RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends libpq-dev postgresql-client \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
