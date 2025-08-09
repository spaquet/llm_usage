# LLL Usage Dashboard

## Project Description

The **LLL Usage Dashboard** is a Ruby on Rails 8 application designed to monitor and manage API usage for multiple AI providers, including xAI, OpenAI, and Anthropic. It provides a user-friendly interface to track API plans, usage history, and rate-limiting status, with real-time updates powered by Hotwire (Turbo Stream and Stimulus). The application uses PostgreSQL as its database, Tailwind CSS 4.1 for styling, ViewComponent for reusable UI components, and Chart.js for visualizing usage data. Background jobs for syncing API usage data are handled by Rails 8's `solid_queue` with PostgreSQL as the backend.

Key features include:
- **Provider Management**: Add, edit, and delete API providers (xAI, OpenAI, Anthropic) with predefined `api_url` and `api_version`, requiring only a name, description, and API key.
- **API Usage Tracking**: Fetches and displays current plan details, usage history, and rate-limiting status for each provider.
- **Reactive UI**: Built with Hotwire (Turbo Stream and Stimulus) for seamless, real-time updates without full page reloads.
- **Secure Storage**: API keys and secrets are stored in the PostgreSQL database with Active Record Encryption.
- **Visualizations**: Usage trends are visualized using Chart.js line charts.
- **Docker Support**: Ready for production deployment with a Rails 8-provided Dockerfile, optimized for use with Kamal or standalone Docker.

The application is designed for developers and organizations needing to monitor API usage across multiple AI providers, with a focus on simplicity, security, and modern web development practices.

## Prerequisites

To run the LLL Usage Dashboard, ensure you have:
- **Docker** and **Docker Compose** installed for containerized deployment.
- **PostgreSQL** (version 14 or higher) for the database.
- **Bun** (version 1.2.19) for JavaScript package management (included in Docker setup).
- **Ruby 3.4.4** (as specified in the Dockerfile, for non-Docker setups).
- A valid `RAILS_MASTER_KEY` from `config/master.key` for decrypting credentials (contains Active Record Encryption keys).

## Setup and Installation (Docker)

The project includes a production-ready Dockerfile provided by Rails 8, modified to include Bun for JavaScript management. Follow these steps to run the application in a Docker container.

### 1. Clone the Repository

```bash
git clone https://github.com/your-organization/lll_usage_dashboard.git
cd lll_usage_dashboard
```

Replace `your-organization` with your GitHub organization or username.

### 2. Configure Environment

Copy the example environment file and update it with your PostgreSQL credentials and encryption keys:

```bash
cp .env.example .env
```

Edit `.env` to include:

```env
POSTGRES_HOST=postgres
POSTGRES_DB=lll_usage_dashboard_production
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your_secure_password
RAILS_MASTER_KEY=your_rails_master_key
```

Obtain `RAILS_MASTER_KEY` from `config/master.key`. If not present, generate credentials:

```bash
rails credentials:edit
```

Add Active Record Encryption keys (as described in the project setup):

```yaml
active_record_encryption:
  primary_key: your_32_character_key_here
  deterministic_key: your_32_character_key_here
  key_derivation_salt: your_32_character_key_here
```

### 3. Create a `docker-compose.yml`

Create `docker-compose.yml` in the project root to define the application and PostgreSQL services:

```yaml
version: '3.8'
services:
  postgres:
    image: postgres:14
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - app_network

  web:
    build:
      context: .
      dockerfile: Dockerfile
    environment:
      - RAILS_ENV=production
      - RAILS_MASTER_KEY=${RAILS_MASTER_KEY}
      - DATABASE_URL=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}
    ports:
      - "80:80"
    depends_on:
      - postgres
    networks:
      - app_network
    volumes:
      - .:/rails

volumes:
  postgres_data:

networks:
  app_network:
    driver: bridge
```

### 4. Build and Run the Docker Containers

Build the Docker image:

```bash
docker-compose build
```

Run the containers:

```bash
docker-compose up -d
```

### 5. Set Up the Database

Run migrations to create the database schema:

```bash
docker-compose exec web rails db:migrate
```

Optionally, seed initial providers:

```bash
docker-compose exec web rails db:seed
```

### 6. Access the Application

Open your browser to `http://localhost`. The dashboard will be available, allowing you to:
- View API usage for configured providers.
- Navigate to `/providers` to add, edit, or delete providers.

### 7. Stopping the Containers

```bash
docker-compose down
```

### Alternative: Run Without Docker Compose

Build the image:

```bash
docker build -t lll_usage_dashboard .
```

Run the container, passing the `RAILS_MASTER_KEY` and linking to a PostgreSQL instance:

```bash
docker run -d -p 80:80 -e RAILS_MASTER_KEY=your_rails_master_key -e DATABASE_URL=postgresql://postgres:your_secure_password@host.docker.internal:5432/lll_usage_dashboard_production --name lll_usage_dashboard lll_usage_dashboard
```

Replace `host.docker.internal:5432` with your PostgreSQL host if running externally.

## Usage

1. **Dashboard**: Access the root URL (`/`) to view API usage, plans, and rate limits for configured providers. Usage data is visualized with Chart.js line charts.
2. **Provider Management**:
   - Go to `/providers` to manage API providers.
   - **Add Provider**: Select a provider type (xAI, OpenAI, Anthropic), enter a name, description, and API key. The `api_url` and `api_version` are auto-filled.
   - **Edit Provider**: Update provider details, including status (active, inactive, suspended).
   - **Delete Provider**: Remove a provider with a confirmation prompt.
3. **Real-Time Updates**: Changes to providers are reflected instantly via Turbo Stream.
4. **Background Sync**: API usage data is synced periodically using `solid_queue`. Schedule syncs with a cron job (e.g., via `whenever`):

```bash
docker-compose exec web whenever --update-crontab
```

## Contributing

We welcome contributions to the LLL Usage Dashboard! Here’s how you can get involved:

### Getting Started

1. **Fork and Clone**:
   ```bash
   git clone https://github.com/your-organization/lll_usage_dashboard.git
   cd lll_usage_dashboard
   ```

2. **Install Dependencies**:
   - Ensure Ruby 3.4.4 and Bun 1.2.19 are installed:
     ```bash
     curl -fsSL https://bun.sh/install | bash -s -- bun-v1.2.19
     ```
   - Install Ruby gems:
     ```bash
     bundle install
     ```
   - Install JavaScript packages:
     ```bash
     bun install
     ```

3. **Set Up PostgreSQL**:
   - Install PostgreSQL locally or use Docker:
     ```bash
     docker run -d -p 5432:5432 -e POSTGRES_PASSWORD=your_secure_password postgres:14
     ```
   - Configure `config/database.yml`:
     ```yaml
     development:
       <<: *default
       database: lll_usage_dashboard_development
       host: localhost
       username: postgres
       password: your_secure_password
     ```

4. **Set Up Credentials**:
   - Generate or copy `config/master.key` and edit credentials:
     ```bash
     rails credentials:edit
     ```
   - Add encryption keys as described in the Setup section.

5. **Run Migrations**:
   ```bash
   rails db:create db:migrate
   ```

6. **Start the Development Server**:
   ```bash
   bin/dev
   ```
   This starts Rails, Tailwind CSS watcher, and `solid_queue` worker.

### Development Guidelines

- **Code Style**:
  - Follow Ruby and Rails conventions (use RuboCop if possible).
  - Use Tailwind CSS 4.1 classes for styling (avoid Tailwind 3.x syntax).
  - Write clean, modular ViewComponents for UI elements.
- **JavaScript with Bun**:
  - Manage JavaScript dependencies with Bun (`bun install`, `bun add package`).
  - Place Stimulus controllers in `app/javascript/controllers`.
  - Use Chart.js for visualizations.
- **Testing**:
  - Write RSpec tests in `spec/`.
  - Use Capybara with Cuprite for system tests.
  - Run tests:
    ```bash
    bundle exec rspec
    ```
- **Background Jobs**:
  - Use `solid_queue` for background processing (no Redis).
  - Test jobs locally:
    ```bash
    rails solid_queue:start
    ```

### Contribution Process

1. **Create an Issue**: Describe the feature, bug, or improvement.
2. **Fork and Branch**:
   - Create a feature branch: `git checkout -b feature/your-feature`.
3. **Commit Changes**:
   - Write clear commit messages: `git commit -m "Add feature X"`.
4. **Push and Create PR**:
   - Push to your fork: `git push origin feature/your-feature`.
   - Open a pull request against the `main` branch.
5. **Code Review**:
   - Ensure tests pass and code adheres to guidelines.
   - Address feedback promptly.

### Areas for Contribution

- Enhance API client implementations for xAI, OpenAI, and Anthropic (replace placeholder endpoints).
- Add authentication (e.g., Devise) for user management.
- Improve Chart.js visualizations (e.g., add more chart types or filters).
- Optimize `solid_queue` job performance.
- Add more tests for controllers, models, and system interactions.

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.

## Contact

For questions or support, open an issue on GitHub or contact the maintainers at [your-contact-email@example.com].
