#!/usr/bin/env python3
"""
Railway Service Cleanup
Remove base services from FARM-7 and FARM-8 to free slots for Wave 8.
Usage: python3 tools/railway_cleanup.py
"""

import subprocess
import json
import sys
import os

# Read tokens from .env
env_vars = {}
try:
    with open('.env') as f:
        for line in f:
            line = line.strip()
            if '=' in line and not line.startswith('#'):
                key, val = line.split('=', 1)
                env_vars[key.strip()] = val.strip()
except:
    print("❌ Cannot read .env file")
    sys.exit(1)

tokens = {
    'FARM-7': env_vars.get('RAILWAY_API_TOKEN_7'),
    'FARM-8': env_vars.get('RAILWAY_API_TOKEN_8'),
}

base_services = ['trinity', 'ssh-bridge', 'trinity-arena', 'agents']

def run_query(token, query):
    """Run GraphQL query and return result."""
    result = subprocess.run([
        'curl', '-s', '-X', 'POST',
        '-H', 'Authorization: Bearer ' + token,
        '-H', 'Content-Type: application/json',
        '-d', query,
        'https://railway.com/graphql/v2'
    ], capture_output=True, text=True)

    if result.stderr:
        print(f"⚠️  stderr: {result.stderr[:200]}")

    try:
        return json.loads(result.stdout)
    except:
        print(f"❌ JSON parse error: {result.stdout[:200]}")
        return None

def find_project_id(token):
    """Find project ID for a token."""
    # First, get user info
    query = '{"query":"{me{id}"}'
    result = run_query(token, query)
    if not result or 'data' not in result:
        return None

    user_id = result['data']['me']['id']

    # Get workspaces
    query = f'{{"query":"{{me{{teams{{id projects{{id name}}}}}}}}}}'
    result = run_query(token, query)
    if not result:
        return None

    projects = []
    try:
        teams = result['data']['me']['teams'] or []
        for team in teams:
            for project in team.get('projects', []):
                projects.append((project['id'], project['name']))
    except:
        pass

    # Return first project found
    if projects:
        return projects[0][0]
    return None

def list_services(token, project_id):
    """List all services in a project."""
    query = f'{{"query":"{{project(id:"{project_id}"){{services{{edges{{node{{id name}}}}}}}}}}}}'
    result = run_query(token, query)
    if not result:
        return []

    try:
        edges = result['data']['project']['services']['edges']
        return [(edge['node']['id'], edge['node']['name']) for edge in edges]
    except:
        return []

def delete_service(token, service_id):
    """Delete a service by ID."""
    query = f'{{"query":"mutation($id: ID!) {{ serviceDelete(id: $id) {{ id }} }}","variables":{{"id":"{service_id}"}}}}'
    result = run_query(token, query)

    if result and 'errors' not in result:
        return True
    return False

def cleanup_account(account_name, token, services_to_delete):
    """Cleanup base services from an account."""
    print(f"\n🔧 [{account_name}] Finding project...")

    project_id = find_project_id(token)
    if not project_id:
        print(f"❌ [{account_name}] No project found")
        return 0

    print(f"✅ [{account_name}] Project ID: {project_id}")

    print(f"🔍 [{account_name}] Listing services...")
    services = list_services(token, project_id)

    to_delete = []
    for svc_id, svc_name in services:
        if svc_name in services_to_delete:
            to_delete.append((svc_id, svc_name))

    if not to_delete:
        print(f"⏭️  [{account_name}] No base services to delete")
        return 0

    print(f"🗑️  [{account_name}] Deleting {len(to_delete)} services...")

    deleted = 0
    for svc_id, svc_name in to_delete:
        if delete_service(token, svc_id):
            print(f"   ✅ {svc_name}")
            deleted += 1
        else:
            print(f"   ❌ {svc_name} (failed)")

    print(f"✅ [{account_name}] Deleted {deleted} services → {deleted} slots freed")
    return deleted

def main():
    print("🧹 Railway Service Cleanup — Wave 8 Preparation")
    print("=" * 50)

    total_deleted = 0

    for account_name, token in tokens.items():
        if not token:
            print(f"⚠️  [{account_name}] No token found")
            continue

        deleted = cleanup_account(account_name, token, base_services)
        total_deleted += deleted

    print(f"\n🎯 TOTAL: {total_deleted} services deleted → {total_deleted} Wave 8 slots freed")
    print("\nNext: tri farm fill --account=FARM-7 --count=12")
    print("       tri farm fill --account=FARM-8 --count=12")

if __name__ == '__main__':
    main()
