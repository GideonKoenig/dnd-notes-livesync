#!/bin/bash
set -e

init_couchdb() {
    hostname="http://127.0.0.1:5984"
    username="${COUCHDB_USER:-admin}"
    password="${COUCHDB_PASSWORD:-admin}"
    AUTH="${username}:${password}"

    echo "[init] Waiting for CouchDB to start..."
    until curl -sf "${hostname}/_up" --user "${AUTH}" > /dev/null 2>&1; do
        sleep 1
    done
    echo "[init] CouchDB is responding."

    cluster_state=$(curl -sf "${hostname}/_cluster_setup" --user "${AUTH}" 2>/dev/null || echo '{"state":"unknown"}')
    
    if echo "$cluster_state" | grep -q '"state":"cluster_finished"'; then
        echo "[init] CouchDB already initialized, skipping setup."
    else
        echo "[init] Initializing CouchDB single-node cluster..."
        
        curl -sf -X POST "${hostname}/_cluster_setup" \
            -H "Content-Type: application/json" \
            -d "{\"action\":\"enable_single_node\",\"username\":\"${username}\",\"password\":\"${password}\",\"bind_address\":\"0.0.0.0\",\"port\":5984,\"singlenode\":true}" \
            --user "${AUTH}" || true

        curl -sf -X POST "${hostname}/_cluster_setup" \
            -H "Content-Type: application/json" \
            -d '{"action":"finish_cluster"}' \
            --user "${AUTH}" || true

        echo "[init] Creating system databases..."
        curl -sf -X PUT "${hostname}/_users" --user "${AUTH}" || true
        curl -sf -X PUT "${hostname}/_replicator" --user "${AUTH}" || true
        curl -sf -X PUT "${hostname}/_global_changes" --user "${AUTH}" || true
    fi

    if ! curl -sf "${hostname}/obsidian-livesync" --user "${AUTH}" > /dev/null 2>&1; then
        echo "[init] Creating obsidian-livesync database with n=1, q=1..."
        curl -sf -X PUT "${hostname}/obsidian-livesync?n=1&q=1" --user "${AUTH}" || true
    else
        echo "[init] obsidian-livesync database already exists."
    fi

    echo "[init] CouchDB initialization complete."
    echo "[init] Databases: $(curl -sf "${hostname}/_all_dbs" --user "${AUTH}")"
}

init_couchdb &

exec /docker-entrypoint.sh "$@"
