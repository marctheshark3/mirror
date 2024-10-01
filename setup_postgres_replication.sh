#!/bin/bash

# Load environment variables
set -a
source .env
set +a

# Function to check if required environment variables are set
check_env_vars() {
    required_vars=("DB_NAME" "DB_USER" "DB_PASSWORD" "REPLICATION_USER" "REPLICATION_PASSWORD" "PRIMARY_IP" "SECONDARY_IP")
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            echo "Error: $var is not set in the .env file"
            exit 1
        fi
    done
}

# Step 1: Configure primary PostgreSQL server for replication
configure_primary() {
    sudo -u postgres psql -c "CREATE USER $REPLICATION_USER WITH REPLICATION ENCRYPTED PASSWORD '$REPLICATION_PASSWORD';" || true
    
    sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/*/main/postgresql.conf
    sudo sed -i "s/#wal_level = replica/wal_level = replica/" /etc/postgresql/*/main/postgresql.conf
    sudo sed -i "s/#max_wal_senders = 10/max_wal_senders = 10/" /etc/postgresql/*/main/postgresql.conf
    
    echo "host replication $REPLICATION_USER $SECONDARY_IP/32 md5" | sudo tee -a /etc/postgresql/*/main/pg_hba.conf
    echo "host all all 172.18.0.0/16 md5" | sudo tee -a /etc/postgresql/*/main/pg_hba.conf
    echo "host all all 0.0.0.0/0 md5" | sudo tee -a /etc/postgresql/*/main/pg_hba.conf
    
    sudo systemctl restart postgresql
}

# Step 2: Set up secondary PostgreSQL server
setup_secondary() {
    # Stop PostgreSQL service
    sudo systemctl stop postgresql

    # Recreate PostgreSQL cluster
    sudo pg_dropcluster --stop 12 main || true
    sudo pg_createcluster 12 main

    # Configure postgresql.conf
    sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/12/main/postgresql.conf
    sudo sed -i "s/#wal_level = replica/wal_level = replica/" /etc/postgresql/12/main/postgresql.conf
    sudo sed -i "s/#max_wal_senders = 10/max_wal_senders = 10/" /etc/postgresql/12/main/postgresql.conf
    sudo sed -i "s/#hot_standby = on/hot_standby = on/" /etc/postgresql/12/main/postgresql.conf

    # Configure pg_hba.conf
    echo "host replication $REPLICATION_USER $PRIMARY_IP/32 md5" | sudo tee -a /etc/postgresql/12/main/pg_hba.conf
    echo "host all all 172.18.0.0/16 md5" | sudo tee -a /etc/postgresql/12/main/pg_hba.conf
    echo "host all all 0.0.0.0/0 md5" | sudo tee -a /etc/postgresql/12/main/pg_hba.conf

    # Clear out main directory
    sudo rm -rf /var/lib/postgresql/12/main

    # Perform base backup
    sudo -u postgres pg_basebackup -h $PRIMARY_IP -D /var/lib/postgresql/12/main -U $REPLICATION_USER -v -P --wal-method=stream

    # Create standby.signal file
    sudo touch /var/lib/postgresql/12/main/standby.signal

    # Add primary connection info
    echo "primary_conninfo = 'host=$PRIMARY_IP port=5432 user=$REPLICATION_USER password=$REPLICATION_PASSWORD'" | sudo tee -a /var/lib/postgresql/12/main/postgresql.auto.conf

    # Set correct ownership
    sudo chown -R postgres:postgres /var/lib/postgresql/12/main

    # Start PostgreSQL
    sudo systemctl start postgresql
}

# Function to test replication
test_replication() {
    echo "Testing replication status..."
    sudo -u postgres psql -c "SELECT * FROM pg_stat_replication;"
    echo "If you see a row in the output above, replication is working."
}

# Main execution
check_env_vars

if [ "$1" = "primary" ]; then
    configure_primary
    echo "Primary PostgreSQL server configured for replication!"
    test_replication
elif [ "$1" = "secondary" ]; then
    setup_secondary
    echo "Secondary PostgreSQL server setup complete and replication started!"
    sleep 10  # Give replication some time to start
    test_replication
else
    echo "Usage: $0 [primary|secondary]"
    exit 1
fi
