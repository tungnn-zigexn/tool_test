# =========================
# 1. Builder
# =========================
FROM ruby:3.4.6-slim AS builder

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential \
      libyaml-dev \
      pkg-config \
      nodejs \
      npm \
      curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /rails

ENV RAILS_ENV=production \
    BUNDLE_WITHOUT="development:test" \
    BUNDLE_DEPLOYMENT=1

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY package.json package-lock.json ./
RUN npm ci

COPY . .
RUN bundle exec rake assets:precompile

# =========================
# 2. Runtime (NHẸ)
# =========================
FROM ruby:3.4.6-slim

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      libyaml-0-2 \
      libsqlite3-0 \
      curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /rails

ENV RAILS_ENV=production \
    BUNDLE_WITHOUT="development:test" \
    BUNDLE_DEPLOYMENT=1

# copy gems đã build
COPY --from=builder /usr/local/bundle /usr/local/bundle

# copy app + assets
COPY --from=builder /rails /rails

RUN mkdir -p tmp/pids tmp/sockets storage

EXPOSE 4000
CMD ["bundle", "exec", "thrust", "bin/rails", "server"]
