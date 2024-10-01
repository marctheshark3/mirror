# PostgreSQL Replication Setup

This repository contains scripts and configuration files for setting up PostgreSQL replication between a primary and a secondary server. It also includes Docker configuration for connecting to the replicated database.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Installation](#installation)
4. [Usage](#usage)
6. [Troubleshooting](#troubleshooting)
7. [Maintenance](#maintenance)
8. [Contributing](#contributing)
9. [License](#license)

## Overview

This setup creates a PostgreSQL replication environment with the following features:

- Primary-Secondary replication
- Automatic failover (optional)
- Docker container configuration for easy application integration
- Scripts for initial setup and maintenance

## Prerequisites

- Two Ubuntu servers (20.04 LTS or later recommended)
- PostgreSQL 12 or later installed on both servers
- SSH access to both servers
- Superuser (root) access on both servers
- Docker and Docker Compose installed (for application integration)

## Installation

1. Clone this repository:
   ```
   git clone https://github.com/yourusername/postgresql-replication-setup.git
   cd postgresql-replication-setup
   ```

2. Copy the `.env.example` file to `.env` and fill in your specific details:
   ```
   cp .env.example .env
   nano .env
   ```

3. Run the setup script on the primary server:
   ```
   chmod +x setup_postgres_replication.sh
   sudo ./setup_postgres_replication.sh primary
   ```

4. Run the setup script on the secondary server:
   ```
   chmod +x setup_postgres_replication.sh
   sudo ./setup_postgres_replication.sh secondary
   ```

## Usage

After installation, your PostgreSQL replication should be up and running. To verify:

1. On the primary server:
   ```
   sudo -u postgres psql -c "SELECT * FROM pg_stat_replication;"
   ```

2. On the secondary server:
   ```
   sudo -u postgres psql -c "SELECT pg_is_in_recovery();"
   ```

This should return `t` (true), indicating that the server is in recovery mode (acting as a replica).

## Troubleshooting

If you encounter issues:

1. Check PostgreSQL logs:
   ```
   sudo tail -f /var/log/postgresql/postgresql-12-main.log
   ```

2. Verify replication status on primary:
   ```
   sudo -u postgres psql -c "SELECT * FROM pg_stat_replication;"
   ```

3. Check replication status on secondary:
   ```
   sudo -u postgres psql -c "SELECT pg_last_wal_receive_lsn(), pg_last_wal_replay_lsn(), pg_last_xact_replay_timestamp();"
   ```

4. Ensure the `pg_hba.conf` file on both servers allows connections from the appropriate IP addresses.

## Maintenance

Regular maintenance tasks:

1. Monitor replication lag:
   ```
   SELECT now() - pg_last_xact_replay_timestamp() AS replication_lag;
   ```

2. Backup your databases regularly.

3. Keep PostgreSQL updated on both servers.

4. Periodically check and update user permissions as needed.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.
