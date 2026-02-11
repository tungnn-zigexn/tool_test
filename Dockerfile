# Dockerfile for Production
FROM ruby:3.4.6-slim AS base

# Install dependencies
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    build-essential libyaml-dev pkg-config\
    libsqlite3-0 \
    nodejs \
    npm \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /rails

# Set production environment
ENV RAILS_ENV="production" \
    BUNDLE_WITHOUT="development:test" \
    BUNDLE_DEPLOYMENT="1"

# Install application gems
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

# Install node packages
COPY package.json package-lock.json ./
RUN npm ci --production=false

# Copy application code
COPY . .

# Precompile assets
RUN bundle exec rake assets:precompile

# Create storage directories
RUN mkdir -p storage tmp/pids tmp/sockets

# Expose port
EXPOSE 4000

# Start the server with thruster
CMD ["bundle", "exec", "thrust", "bin/rails", "server"]


