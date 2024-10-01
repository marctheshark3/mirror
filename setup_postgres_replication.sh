#!/bin/bash

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | xargs)
else
    echo ".env file not found"
    exit 1
fi

# Function to check if required environment variables are set
check_env_vars() {
    required_vars=("DB_USER" "DB_PASSWORD" "REPLICATION_USER" "REPLICATION_PASSWORD" "PRIMARY_IP" "SECONDARY_IP")
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            echo "Error: $var is not set in the .env file"
            exit 1
        fi
    done
}

# Step 1: Set up primary PostgreSQL server
setup_primary() {
    sudo apt-get update
    sudo apt-get install -y postgresql postgresql-contrib
    
    # Configure PostgreSQL for replication
    sudo -u postgres psql -c "CREATE USER $REPLICATION_USER WITH REPLICATION ENCRYPTED PASSWORD '$REPLICATION_PASSWORD';"
    
    # Edit postgresql.conf
    sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/*/main/postgresql.conf
    sudo sed -i "s/#wal_level = replica/wal_level = replica/" /etc/postgresql/*/main/postgresql.conf
    sudo sed -i "s/#max_wal_senders = 10/max_wal_senders = 10/" /etc/postgresql/*/main/postgresql.conf
    
    # Edit pg_hba.conf
    echo "host replication $REPLICATION_USER $SECONDARY_IP/32 md5" | sudo tee -a /etc/postgresql/*/main/pg_hba.conf
    
    # Restart PostgreSQL
    sudo systemctl restart postgresql
}

# Step 2: Create and populate sample database
create_sample_db() {
    sudo -u postgres psql -c "CREATE DATABASE sampledb;"
    sudo -u postgres psql -d sampledb -c "CREATE TABLE users (id SERIAL PRIMARY KEY, name VARCHAR(100), email VARCHAR(100));"
    sudo -u postgres psql -d sampledb -c "INSERT INTO users (name, email) VALUES ('John Doe', 'john@example.com'), ('Jane Smith', 'jane@example.com');"
}

# Step 3: Set up secondary PostgreSQL server
setup_secondary() {
    sudo apt-get update
    sudo apt-get install -y postgresql postgresql-contrib
    
    # Stop PostgreSQL service
    sudo systemctl stop postgresql
    
    # Clear existing data
    sudo rm -rf /var/lib/postgresql/*/main
    
    # Edit postgresql.conf
    sudo sed -i "s/#hot_standby = off/hot_standby = on/" /etc/postgresql/*/main/postgresql.conf
    
    # Edit pg_hba.conf
    echo "host replication $REPLICATION_USER $PRIMARY_IP/32 md5" | sudo tee -a /etc/postgresql/*/main/pg_hba.conf
}

# Step 4: Start replication
start_replication() {
    # Perform base backup
    sudo -u postgres pg_basebackup -h $PRIMARY_IP -D /var/lib/postgresql/*/main -U $REPLICATION_USER -v -P --wal-method=stream
    
    # Create or modify recovery.conf (for PostgreSQL 11 and earlier) or postgresql.auto.conf (for PostgreSQL 12+)
    if [ -f /var/lib/postgresql/*/main/postgresql.auto.conf ]; then
        # PostgreSQL 12+
        echo "primary_conninfo = 'host=$PRIMARY_IP port=5432 user=$REPLICATION_USER password=$REPLICATION_PASSWORD'" | sudo tee -a /var/lib/postgresql/*/main/postgresql.auto.conf
        sudo touch /var/lib/postgresql/*/main/standby.signal
    else
        # PostgreSQL 11 and earlier
        echo "standby_mode = 'on'" | sudo tee /var/lib/postgresql/*/main/recovery.conf
        echo "primary_conninfo = 'host=$PRIMARY_IP port=5432 user=$REPLICATION_USER password=$REPLICATION_PASSWORD'" | sudo tee -a /var/lib/postgresql/*/main/recovery.conf
    fi
    
    # Start PostgreSQL on secondary
    sudo systemctl start postgresql
}

# Main execution
check_env_vars

if [ "$1" = "primary" ]; then
    setup_primary
    create_sample_db
    echo "Primary PostgreSQL server setup complete!"
elif [ "$1" = "secondary" ]; then
    setup_secondary
    start_replication
    echo "Secondary PostgreSQL server setup complete!"
else
    echo "Usage: $0 [primary|secondary]"
    exit 1
fi
