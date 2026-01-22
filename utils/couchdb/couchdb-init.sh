#!/bin/bash
set -e

hostname="${hostname:-http://localhost:5984}"
username="${COUCHDB_USER:-$username}"
password="${COUCHDB_PASSWORD:-$password}"

if [[ -z "$username" ]]; then
    echo "ERROR: Username missing (set COUCHDB_USER or username)"
    exit 1
fi

if [[ -z "$password" ]]; then
    echo "ERROR: Password missing (set COUCHDB_PASSWORD or password)"
    exit 1
fi

AUTH="${username}:${password}"

wait_for_couchdb() {
    echo "Waiting for CouchDB to be ready..."
    until curl -sf "${hostname}/_up" --user "${AUTH}" > /dev/null 2>&1; do
        sleep 2
    done
    echo "CouchDB is ready."
}

echo "-- Configuring CouchDB for single-node operation -->"

wait_for_couchdb

echo "Enabling single-node mode..."
curl -sf -X POST "${hostname}/_cluster_setup" \
    -H "Content-Type: application/json" \
    -d "{\"action\":\"enable_single_node\",\"username\":\"${username}\",\"password\":\"${password}\",\"bind_address\":\"0.0.0.0\",\"port\":5984,\"singlenode\":true}" \
    --user "${AUTH}" || true

echo "Finishing cluster setup..."
curl -sf -X POST "${hostname}/_cluster_setup" \
    -H "Content-Type: application/json" \
    -d '{"action":"finish_cluster"}' \
    --user "${AUTH}" || true

echo "Creating system databases..."
curl -sf -X PUT "${hostname}/_users" --user "${AUTH}" || true
curl -sf -X PUT "${hostname}/_replicator" --user "${AUTH}" || true
curl -sf -X PUT "${hostname}/_global_changes" --user "${AUTH}" || true

echo "Configuring CouchDB settings..."
curl -sf -X PUT "${hostname}/_node/nonode@nohost/_config/chttpd/require_valid_user" \
    -H "Content-Type: application/json" -d '"true"' --user "${AUTH}"
curl -sf -X PUT "${hostname}/_node/nonode@nohost/_config/chttpd_auth/require_valid_user" \
    -H "Content-Type: application/json" -d '"true"' --user "${AUTH}"
curl -sf -X PUT "${hostname}/_node/nonode@nohost/_config/httpd/WWW-Authenticate" \
    -H "Content-Type: application/json" -d '"Basic realm=\"couchdb\""' --user "${AUTH}"
curl -sf -X PUT "${hostname}/_node/nonode@nohost/_config/httpd/enable_cors" \
    -H "Content-Type: application/json" -d '"true"' --user "${AUTH}"
curl -sf -X PUT "${hostname}/_node/nonode@nohost/_config/chttpd/enable_cors" \
    -H "Content-Type: application/json" -d '"true"' --user "${AUTH}"
curl -sf -X PUT "${hostname}/_node/nonode@nohost/_config/chttpd/max_http_request_size" \
    -H "Content-Type: application/json" -d '"4294967296"' --user "${AUTH}"
curl -sf -X PUT "${hostname}/_node/nonode@nohost/_config/couchdb/max_document_size" \
    -H "Content-Type: application/json" -d '"50000000"' --user "${AUTH}"
curl -sf -X PUT "${hostname}/_node/nonode@nohost/_config/cors/credentials" \
    -H "Content-Type: application/json" -d '"true"' --user "${AUTH}"
curl -sf -X PUT "${hostname}/_node/nonode@nohost/_config/cors/origins" \
    -H "Content-Type: application/json" -d '"app://obsidian.md,capacitor://localhost,http://localhost"' --user "${AUTH}"

echo "Creating obsidian-livesync database with n=1, q=1..."
curl -sf -X PUT "${hostname}/obsidian-livesync?n=1&q=1" --user "${AUTH}" || true

echo "<-- CouchDB single-node initialization complete!"
echo ""
echo "Verifying setup..."
echo "System databases:"
curl -sf "${hostname}/_all_dbs" --user "${AUTH}"
echo ""
echo "Cluster status:"
curl -sf "${hostname}/_cluster_setup" --user "${AUTH}"
echo ""