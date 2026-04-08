#!/usr/bin/env python3
"""
Voyfy VPN User Management Script
Quick script to add test users to the VPN system.

Usage:
    python add_users.py <email> <password> [--admin]
    
Examples:
    python add_users.py user@example.com password123
    python add_users.py admin@voyfy.com adminpass123 --admin
"""

import argparse
import requests
import sys
from urllib.parse import urljoin

# Configuration
API_BASE_URL = "http://localhost:4000"


def create_user(email: str, password: str, admin: bool = False) -> dict:
    """Create a new user via the API."""
    
    url = urljoin(API_BASE_URL, "/api/auth/register")
    
    payload = {
        "email": email,
        "password": password,
        "name": email.split("@")[0]
    }
    
    try:
        response = requests.post(url, json=payload, timeout=10)
        
        if response.status_code == 201:
            data = response.json()
            user_data = data.get("data", {})
            
            print(f"✅ User created successfully!")
            print(f"   Email: {user_data.get('email')}")
            print(f"   UUID: {user_data.get('uuid')}")
            print(f"   Subscription URL: {user_data.get('subscriptionUrl')}")
            
            if admin:
                print(f"\n⚠️  To make this user an admin, run SQL:")
                print(f"   UPDATE users SET is_admin = true WHERE email = '{email}';")
            
            return user_data
            
        elif response.status_code == 409:
            print(f"❌ User already exists: {email}")
            return None
        else:
            print(f"❌ Failed to create user: {response.status_code}")
            print(f"   Response: {response.text}")
            return None
            
    except requests.exceptions.ConnectionError:
        print(f"❌ Cannot connect to API at {API_BASE_URL}")
        print(f"   Make sure the backend server is running")
        return None
    except requests.exceptions.Timeout:
        print(f"❌ Request timed out")
        return None
    except Exception as e:
        print(f"❌ Error: {e}")
        return None


def login_user(email: str, password: str) -> dict:
    """Login and get tokens."""
    
    url = urljoin(API_BASE_URL, "/api/auth/login")
    
    payload = {
        "email": email,
        "password": password
    }
    
    try:
        response = requests.post(url, json=payload, timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            user_data = data.get("data", {})
            
            print(f"\n✅ Login successful!")
            print(f"   Access Token: {user_data.get('tokens', {}).get('accessToken', '')[:30]}...")
            print(f"   Expires In: {user_data.get('tokens', {}).get('expiresIn')}")
            
            return user_data
        else:
            print(f"❌ Login failed: {response.status_code}")
            return None
            
    except Exception as e:
        print(f"❌ Error: {e}")
        return None


def check_api_health() -> bool:
    """Check if API is running."""
    
    url = urljoin(API_BASE_URL, "/api/health")
    
    try:
        response = requests.get(url, timeout=5)
        return response.status_code == 200
    except:
        return False


def main():
    parser = argparse.ArgumentParser(
        description="Voyfy VPN User Management Script"
    )
    parser.add_argument("email", help="User email address")
    parser.add_argument("password", help="User password")
    parser.add_argument(
        "--admin", 
        action="store_true", 
        help="Show SQL to make user admin"
    )
    parser.add_argument(
        "--login", 
        action="store_true", 
        help="Login after creation"
    )
    parser.add_argument(
        "--api-url",
        default=API_BASE_URL,
        help=f"API base URL (default: {API_BASE_URL})"
    )
    
    args = parser.parse_args()
    
    # Update API URL if provided
    global API_BASE_URL
    API_BASE_URL = args.api_url
    
    # Check API health
    print(f"🔍 Checking API at {API_BASE_URL}...")
    if not check_api_health():
        print(f"❌ API is not responding")
        print(f"   Make sure the backend is running:")
        print(f"   cd backend && npm run dev")
        sys.exit(1)
    
    print(f"✅ API is healthy\n")
    
    # Create user
    user = create_user(args.email, args.password, args.admin)
    
    if user and args.login:
        login_user(args.email, args.password)
    
    print()  # Empty line at end


if __name__ == "__main__":
    main()
